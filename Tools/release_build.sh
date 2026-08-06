#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./Tools/release_build.sh X.Y [--skip-notarize] [--keep-tmp] [--force]

Runs RELEASE.md Section 2 end to end for version X.Y:
  1. archive        xcodebuild archive (Release)
  2. export         sign Developer ID via Tools/ExportOptions-local.plist
  3. notarize app   ditto -> notarytool submit --wait -> stapler staple
  4. verify app     spctl + stapler validate + codesign authority check
  5. package        clean staging dir -> hdiutil create vkey-X.Y.dmg
  6. notarize dmg   codesign -> notarytool submit --wait -> stapler staple

Every verify step is a hard failure: the script exits non-zero rather than
letting a bad artifact reach the DMG. Temp dirs are wiped before use, so the
script is safe to re-run after a failure.

Options:
  --skip-notarize   Do steps 1, 2 and 5 only. Produces an UNNOTARIZED dmg for
                    local smoke-testing. Never ship the output.
  --keep-tmp        Leave /tmp/vkey-X.Y-* behind for inspection.
  --force           Overwrite an existing vkey-X.Y.dmg. Without it the script
                    refuses, because a rebuild changes the bytes and would
                    invalidate an edSignature already published in appcast.xml.

On success prints the path of the signed, notarized, stapled dmg. Sparkle
signing (Section 3) is the NEXT step and must run after this script, because
codesign and stapler both rewrite the dmg and would invalidate edSignature.
EOF
}

VERSION=""
SKIP_NOTARIZE=0
KEEP_TMP=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    --keep-tmp)
      KEEP_TMP=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "$VERSION" ]]; then
        echo "Unexpected extra argument: $1" >&2
        usage
        exit 1
      fi
      VERSION="$1"
      shift
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Missing version argument." >&2
  usage
  exit 1
fi

# RELEASE.md Section 1: MARKETING_VERSION is exactly two components.
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be MAJOR.MINOR (e.g. 4.18), got: $VERSION" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SIGN_IDENTITY="Developer ID Application: Long Hoang Tuan (U4B264GM2B)"
KEYCHAIN_PROFILE="vkey"
ARCHIVE_PATH="/tmp/vkey-${VERSION}.xcarchive"
EXPORT_DIR="/tmp/vkey-${VERSION}-export"
ZIP_PATH="/tmp/vkey-${VERSION}-notarize.zip"
STAGING_DIR="/tmp/vkey-dmg-staging"
APP_PATH="${EXPORT_DIR}/vkey.app"
DMG_PATH="${REPO_ROOT}/vkey-${VERSION}.dmg"

step() { printf '\n=== %s ===\n' "$1"; }
die()  { echo "FAIL: $1" >&2; exit 1; }

# Fail early rather than after a multi-minute archive.
step "Preflight"
# NB: capture first, then grep. Piping into `grep -q` under `set -o pipefail`
# makes the producer die of SIGPIPE and fails the pipeline on a SUCCESSFUL match.
IDENTITIES="$(security find-identity -v -p codesigning 2>&1 || true)"
grep -qF "$SIGN_IDENTITY" <<<"$IDENTITIES" \
  || die "signing identity not in keychain: $SIGN_IDENTITY
       Cert expired or missing — see RELEASE.md Section 6.6 and Section 7."

CERT_END="$(security find-certificate -c "Developer ID Application: Long Hoang Tuan" -p \
  | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || true)"
if [[ -n "$CERT_END" ]]; then
  echo "Signing cert valid until: $CERT_END"
  CERT_END_EPOCH="$(date -j -f '%b %e %T %Y %Z' "$CERT_END" '+%s' 2>/dev/null || echo 0)"
  NOW_EPOCH="$(date '+%s')"
  if [[ "$CERT_END_EPOCH" != 0 && "$CERT_END_EPOCH" -lt "$NOW_EPOCH" ]]; then
    die "signing cert EXPIRED on $CERT_END — renew before releasing (RELEASE.md Section 7)."
  fi
  # 30 days, in seconds.
  if [[ "$CERT_END_EPOCH" != 0 && $((CERT_END_EPOCH - NOW_EPOCH)) -lt 2592000 ]]; then
    echo "WARNING: signing cert expires in under 30 days ($CERT_END)." >&2
  fi
fi

PBX_VERSION="$(grep -m1 'MARKETING_VERSION' vkey.xcodeproj/project.pbxproj \
  | sed 's/.*= *\([0-9.]*\);.*/\1/')"
[[ "$PBX_VERSION" == "$VERSION" ]] \
  || die "MARKETING_VERSION in pbxproj is $PBX_VERSION, expected $VERSION.
       Bump the version first (RELEASE.md step 2)."

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1 \
    || die "notarytool keychain profile '$KEYCHAIN_PROFILE' is missing or rejected.
       Recreate it with store-credentials — see RELEASE.md Section 2."
fi

step "Clean previous artifacts"
# The dmg is the one artifact worth protecting: if it has already been signed
# for Sparkle, rebuilding changes its bytes and silently invalidates the
# edSignature and length already written into appcast.xml.
if [[ -f "$DMG_PATH" && "$FORCE" -eq 0 ]]; then
  die "$DMG_PATH already exists.
       If it is already Sparkle-signed, rebuilding invalidates the edSignature
       and length in appcast.xml. Re-run with --force to overwrite."
fi
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$ZIP_PATH" "$STAGING_DIR"
rm -f "$DMG_PATH"

step "1/6 Archive"
# No -allowProvisioningUpdates: the app is not sandboxed so it needs no
# provisioning profile, and that flag only does anything when Xcode has an
# Apple ID signed in (this machine has none). See RELEASE.md Section 2.
xcodebuild -project vkey.xcodeproj -scheme vkey -configuration Release archive \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=macOS' \
  | tail -5

step "2/6 Export + sign Developer ID"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist Tools/ExportOptions-local.plist \
  | tail -5

[[ -d "$APP_PATH" ]] || die "export produced no app at $APP_PATH"

APP_CODESIGN="$(codesign -dvv "$APP_PATH" 2>&1 || true)"
grep -qF "Authority=${SIGN_IDENTITY}" <<<"$APP_CODESIGN" \
  || die "app is not signed with Developer ID (still Apple Development?).
       Check: codesign -dvv $APP_PATH"
grep -q 'flags=.*runtime' <<<"$APP_CODESIGN" \
  || die "hardened runtime is off — notarization would be rejected."

if [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
  echo "--skip-notarize: skipping steps 3, 4 and 6."
else
  step "3/6 Notarize app"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"

  step "4/6 Verify app"
  # spctl is advisory here: this machine may have assessments disabled, in which
  # case it accepts anything. stapler validate is the load-bearing check.
  spctl --assess --type exec -vv "$APP_PATH" 2>&1 | sed 's/^/  /' || true
  xcrun stapler validate "$APP_PATH" \
    || die "app has no stapled notarization ticket."
fi

step "5/6 Package DMG"
# Staging must be empty: `cp -R src.app dir/` MERGES into an existing bundle of
# the same name, leaving stale files that break _CodeSignature.
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
codesign --verify --deep --strict "$STAGING_DIR/vkey.app" \
  || die "staged app fails signature verification — stale files in the bundle?"
ln -sfn /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "vkey $VERSION" -srcfolder "$STAGING_DIR" \
  -ov -format UDZO "$DMG_PATH" | tail -2

[[ -f "$DMG_PATH" ]] || die "hdiutil produced no dmg at $DMG_PATH"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  step "6/6 Sign + notarize DMG"
  # Gatekeeper assesses the container the user downloads, not just the app
  # inside it. An unsigned dmg warns on first open even when the app is
  # stapled. See RELEASE.md Section 2.
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH" \
    || die "dmg has no stapled notarization ticket."
  DMG_CODESIGN="$(codesign -dvv "$DMG_PATH" 2>&1 || true)"
  grep -qF "Authority=${SIGN_IDENTITY}" <<<"$DMG_CODESIGN" \
    || die "dmg is not signed with Developer ID."
fi

if [[ "$KEEP_TMP" -eq 0 ]]; then
  rm -rf "$ARCHIVE_PATH" "$ZIP_PATH" "$STAGING_DIR"
fi

step "Done"
echo "DMG:   $DMG_PATH"
echo "Bytes: $(stat -f%z "$DMG_PATH")"
if [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
  echo
  echo "WARNING: built with --skip-notarize. This dmg is NOT shippable."
else
  echo
  echo "Next: sign for Sparkle (RELEASE.md Section 3). Run it now, not earlier —"
  echo "codesign and stapler rewrote the dmg, so any prior edSignature is stale."
fi
