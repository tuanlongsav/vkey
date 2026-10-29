#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./Tools/sparkle_sign_update.sh --archive /path/to/update.dmg --private-key /path/to/private.key

Options:
  --archive       Path to update archive (.dmg/.zip/.tar.*)
  --private-key   Path to Sparkle private EdDSA key file
  --sign-tool     Optional explicit path to Sparkle sign_update binary

Output:
  Prints Sparkle enclosure fragment to stdout:
    sparkle:edSignature="..." length="..."
EOF
}

ARCHIVE_PATH=""
PRIVATE_KEY_PATH=""
SIGN_TOOL_PATH="${SIGN_UPDATE_BIN:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive)
      ARCHIVE_PATH="${2:-}"
      shift 2
      ;;
    --private-key)
      PRIVATE_KEY_PATH="${2:-}"
      shift 2
      ;;
    --sign-tool)
      SIGN_TOOL_PATH="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ARCHIVE_PATH" || -z "$PRIVATE_KEY_PATH" ]]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

if [[ ! -f "$PRIVATE_KEY_PATH" ]]; then
  echo "Private key file not found: $PRIVATE_KEY_PATH" >&2
  exit 1
fi

# Resolving this binary is a security decision, not a convenience one: whatever
# we pick is handed the path to the EdDSA private key that signs every Sparkle
# update. The old implementation ran
#
#     find "$HOME/Library/Developer/Xcode/DerivedData" -name sign_update | head -1
#
# which is wrong twice over. DerivedData holds build products for every project
# on the machine and is writable by any build phase or SPM plugin any of them
# runs, so "first match" is an untrusted binary. And `find` returns filesystem
# order, so which of the (currently nine) matches wins is not deterministic —
# six of them are `old_dsa_scripts/sign_update`, the Sparkle 1.x DSA tool that
# doesn't even take --ed-key-file.
#
# So: an explicit path is authoritative and never silently replaced, and the
# fallback only looks at the exact artifact path SPM checks Sparkle out to, for
# this project, and refuses to guess when that is ambiguous.
if [[ -n "$SIGN_TOOL_PATH" ]]; then
  [[ -x "$SIGN_TOOL_PATH" ]] || {
    echo "sign_update path is not executable: $SIGN_TOOL_PATH" >&2
    echo "(refusing to fall back to a search — this binary receives the private key)" >&2
    exit 1
  }
else
  DERIVED_ROOT="$HOME/Library/Developer/Xcode/DerivedData"
  CANDIDATES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && CANDIDATES+=("$line")
  done < <(
    find "$DERIVED_ROOT" \
      -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update' \
      -type f -perm -u+x 2>/dev/null | sort
  )

  # Check for "none" BEFORE hashing: `shasum` with no file arguments reads
  # stdin, so an empty array would leave it waiting on the terminal forever.
  if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    cat >&2 <<EOF
Could not find Sparkle's sign_update under $DERIVED_ROOT.
Build the project once so SPM checks Sparkle out, or pass the path explicitly:
    SIGN_UPDATE_BIN=/path/to/sign_update $0 ...
    $0 --sign-tool /path/to/sign_update ...
EOF
    exit 1
  fi

  # Several DerivedData dirs for the same project are normal (Xcode rehashes the
  # path). Identical bytes across them is the expected case and is not ambiguous.
  UNIQUE_HASHES="$(shasum -a 256 "${CANDIDATES[@]}" 2>/dev/null | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"

  if [[ "$UNIQUE_HASHES" != 1 ]]; then
    echo "Found ${#CANDIDATES[@]} DIFFERENT sign_update binaries — refusing to guess:" >&2
    printf '  %s\n' "${CANDIDATES[@]}" >&2
    echo "Pass the right one with --sign-tool (or set SIGN_UPDATE_BIN)." >&2
    exit 1
  fi

  SIGN_TOOL_PATH="${CANDIDATES[0]}"
fi

# Print it: the reader of a release log should be able to see which binary held
# the key, without re-deriving the search.
echo "sign_update: $SIGN_TOOL_PATH" >&2

SIGN_OUTPUT="$("$SIGN_TOOL_PATH" --ed-key-file "$PRIVATE_KEY_PATH" "$ARCHIVE_PATH")"

SIGNATURE="$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' | head -n 1)"
LENGTH="$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p' | head -n 1)"

if [[ -z "$SIGNATURE" || -z "$LENGTH" ]]; then
  echo "Failed to parse sign_update output:" >&2
  echo "$SIGN_OUTPUT" >&2
  exit 1
fi

echo "sparkle:edSignature=\"$SIGNATURE\" length=\"$LENGTH\""
