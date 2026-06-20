#!/usr/bin/env bash
# Xuất ảnh marketing vkey (SwiftUI render) + tuỳ chọn quay clip trên Ehomewei.
#
# Ảnh PNG: không cần quyền Ghi màn hình — render trực tiếp từ app.
# Video: cần bật Ghi màn hình cho Terminal trong System Settings.
#
# Usage:
#   Tools/capture_marketing.sh           # chỉ PNG → images/
#   Tools/capture_marketing.sh --video   # PNG + clip 12s trên màn phụ

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="$ROOT/images"
VID="$ROOT/marketing/videos"
DERIVED="/tmp/vkey-marketing-dd"
APP="$DERIVED/Build/Products/Debug/vkey.app"
WANT_VIDEO=false

for arg in "$@"; do
  case "$arg" in
    --video) WANT_VIDEO=true ;;
  esac
done

mkdir -p "$IMG" "$VID"

log() { printf '▸ %s\n' "$*"; }

log "Build Debug…"
xcodebuild -project "$ROOT/vkey.xcodeproj" -scheme vkey -configuration Debug \
  -derivedDataPath "$DERIVED" build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -5

EXPORT_ARGS=(--export-marketing="$IMG")
if $WANT_VIDEO; then
  EXPORT_ARGS+=(--export-marketing-carousel)
fi

log "Xuất PNG → $IMG"
"$APP/Contents/MacOS/vkey" "${EXPORT_ARGS[@]}" &
VPID=$!

if $WANT_VIDEO; then
  sleep 2
  # Ehomewei: màn phụ bên trái (X âm). screencapture -D 2 = màn thứ hai.
  log "Quay clip 12s trên màn phụ (cần quyền Ghi màn hình)…"
  if screencapture -v -V 12 -D 2 -x "$VID/vkey-demo-12s.mov" 2>/dev/null; then
    log "Video: $VID/vkey-demo-12s.mov"
  else
    log "Không quay được video — bật Ghi màn hình cho Terminal rồi chạy lại với --video"
  fi
fi

wait "$VPID" 2>/dev/null || true

log "Hoàn tất."
log "Ảnh: $IMG"
ls -la "$IMG"/*.png 2>/dev/null | awk '{print "  ", $NF, $5"B"}'
