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

resolve_sign_tool() {
  if [[ -n "$SIGN_TOOL_PATH" && -x "$SIGN_TOOL_PATH" ]]; then
    echo "$SIGN_TOOL_PATH"
    return 0
  fi

  local candidates=(
    "$HOME/Library/Developer/Xcode/DerivedData"
    "/Applications/Xcode.app/Contents/Developer"
  )

  local found=""
  for root in "${candidates[@]}"; do
    if [[ -d "$root" ]]; then
      found="$(find "$root" -type f -name sign_update 2>/dev/null | head -n 1 || true)"
      if [[ -n "$found" && -x "$found" ]]; then
        echo "$found"
        return 0
      fi
    fi
  done

  return 1
}

SIGN_TOOL_PATH="$(resolve_sign_tool || true)"
if [[ -z "$SIGN_TOOL_PATH" ]]; then
  cat >&2 <<'EOF'
Could not find Sparkle sign_update tool.
Set SIGN_UPDATE_BIN or pass --sign-tool with explicit path.
EOF
  exit 1
fi

SIGN_OUTPUT="$("$SIGN_TOOL_PATH" --ed-key-file "$PRIVATE_KEY_PATH" "$ARCHIVE_PATH")"

SIGNATURE="$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' | head -n 1)"
LENGTH="$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p' | head -n 1)"

if [[ -z "$SIGNATURE" || -z "$LENGTH" ]]; then
  echo "Failed to parse sign_update output:" >&2
  echo "$SIGN_OUTPUT" >&2
  exit 1
fi

echo "sparkle:edSignature=\"$SIGNATURE\" length=\"$LENGTH\""
