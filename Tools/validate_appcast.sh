#!/usr/bin/env bash
#
# Tools/validate_appcast.sh
#
# Validate `appcast.xml` qua `xmllint --noout`. Chạy trước mọi commit
# touching appcast.xml để tránh bug như 1.5.9 — bare `&` trong title
# làm XMLParser của Updater crash, user 1.5.x báo nhầm "đã là phiên bản
# mới nhất".
#
# Usage:
#
#     ./Tools/validate_appcast.sh
#
# Exit 0 nếu XML hợp lệ, exit 1 + show error nếu invalid.
#

set -euo pipefail

APPCAST="appcast.xml"

if [[ ! -f "$APPCAST" ]]; then
  echo "❌ Không tìm thấy $APPCAST trong working dir."
  echo "   Chạy script từ root repo."
  exit 1
fi

if ! command -v xmllint >/dev/null 2>&1; then
  echo "❌ xmllint chưa cài. Cài qua: brew install libxml2"
  exit 1
fi

echo "→ Validate $APPCAST..."
if xmllint --noout "$APPCAST" 2>&1; then
  echo "✅ $APPCAST hợp lệ XML."

  # Bonus: đọc version của item đầu. Đây là thông tin phụ, KHÔNG phải phán
  # quyết về tính hợp lệ — nên nó không được quyền làm hỏng kết luận ở trên.
  # Trước đây `VERSION=$(python3 ...)` chạy trần dưới `set -e`: item đầu thiếu
  # `sparkle:shortVersionString` → `.text` trên None → traceback → script exit 1
  # NGAY SAU khi vừa in "hợp lệ". Đúng kiểu nhầm lẫn mà script này sinh ra để
  # ngăn: bạn tưởng appcast hỏng trong khi nó hoàn toàn ổn.
  if command -v python3 >/dev/null 2>&1; then
    VERSION="$(python3 - "$APPCAST" <<'PY' || true
import sys, xml.etree.ElementTree as ET
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
try:
    item = ET.parse(sys.argv[1]).find(".//item")
    if item is None:
        sys.exit(0)
    node = item.find("sparkle:shortVersionString", ns)
    if node is None or not (node.text or "").strip():
        sys.exit(0)
    print(node.text.strip())
except ET.ParseError:
    sys.exit(0)
PY
)"
    if [[ -n "$VERSION" ]]; then
      echo "   Top item version: v$VERSION"
    else
      echo "   ⚠️  Item đầu không có sparkle:shortVersionString — Sparkle sẽ bỏ qua item này."
    fi
  fi
  exit 0
else
  echo "❌ $APPCAST INVALID. Fix lỗi XML trước khi commit."
  echo "   Tip: thường là bare \`&\` trong title cần escape thành \`&amp;\`."
  exit 1
fi
