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

  # Bonus: extract top item version
  if command -v python3 >/dev/null 2>&1; then
    VERSION=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$APPCAST')
ns = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
first = tree.find('.//item')
v = first.find('sparkle:shortVersionString', ns).text
print(v)
")
    echo "   Top item version: v$VERSION"
  fi
  exit 0
else
  echo "❌ $APPCAST INVALID. Fix lỗi XML trước khi commit."
  echo "   Tip: thường là bare \`&\` trong title cần escape thành \`&amp;\`."
  exit 1
fi
