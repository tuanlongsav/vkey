// kcsweep — công cụ ĐO: mã phím ảo nào chuyển được event CHỈ mang chuỗi Unicode
// tới app. KHÔNG phải mã sản phẩm.
//
// Vì sao cần: vkey gõ lại chữ bằng event mang chuỗi Unicode (`keyboardSetUnicodeString`),
// và mã phím trên event đó là một hằng số duy nhất (`EventSimulator.KeyCode.unicodeOnly`)
// mà CẢ 5 đường gửi phụ thuộc. v4.32 đổi nó sang 0xFF theo suy diễn "mã này không
// sinh ký tự" — app bỏ im lặng cả event, nên mọi chữ vkey gửi biến mất trong khi
// backspace vẫn xoá: dấu không ra, mất chữ, mất cả cụm, ở MỌI app. Đổi hằng số đó
// mà không chạy công cụ này là tái diễn đúng lỗi ấy.
//
// Dùng `.privateState` để event đi ĐÚNG đường vkey tự phát: bộ lọc self-event của
// vkey bỏ qua mọi event có stateID != 1, nên phép đo không bị vkey xử lý lại.
//
// Kết quả đo 09/10/2026 (macOS 27, TextEdit):
//   tới được:   0, 10, 90, 110
//   mất trắng:  64 (F17), 79 (F18), 80 (F19), 106 (F16), 126 (Up) — AppKit dịch
//               thành phím chức năng, `NSEvent.characters` rỗng
//   mất trắng:  255 (0xFF) — ngoài dải 7 bit của virtual keycode
//
// Build:  swiftc -O Tools/probe/kcsweep.swift -o /tmp/kcsweep
// Chạy:   mở một tài liệu TextEdit TRỐNG rồi `/tmp/kcsweep`
//         đọc lại: osascript -e 'tell application "TextEdit" to get text of document 1'
//         thứ tự nhãn: 0=a 10=b 64=c 79=d 80=e 90=f 106=g 110=h 126=i 255=j
// Đo trên Blink (Chrome, Electron): dùng `kcpost.swift` + `cdp.mjs`, xem README.

import AppKit
import Foundation

let candidates: [(CGKeyCode, String)] = [
  (0, "a"), (10, "b"), (64, "c"), (79, "d"), (80, "e"),
  (90, "f"), (106, "g"), (110, "h"), (126, "i"), (255, "j"),
]

guard let te = NSWorkspace.shared.runningApplications.first(where: {
  $0.bundleIdentifier == "com.apple.TextEdit"
}) else { print("TextEdit chưa chạy"); exit(1) }
te.activate()

var waited = 0.0
while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != "com.apple.TextEdit",
      waited < 5.0 {
  usleep(100_000); waited += 0.1
}
guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" else {
  print("TỪ CHỐI: frontmost = \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?")")
  exit(1)
}
usleep(600_000)

guard let src = CGEventSource(stateID: .privateState) else { print("no source"); exit(1) }
for (kc, label) in candidates {
  let units = Array(label.utf16).map { UniChar($0) }
  guard let dn = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: true),
        let up = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: false) else {
    print("kc=\(kc): CGEvent = nil"); continue
  }
  for e in [dn, up] {
    e.setIntegerValueField(.keyboardEventKeycode, value: Int64(kc))
    e.flags = .maskNonCoalesced
    e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
  }
  dn.post(tap: .cgSessionEventTap)
  up.post(tap: .cgSessionEventTap)
  print("kc=\(kc) -> '\(label)'")
  usleep(250_000)
}
usleep(500_000)
