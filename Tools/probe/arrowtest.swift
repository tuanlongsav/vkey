// arrowtest — công cụ ĐO: Shift+mũi tên còn CHỌN được chữ hay không khi
// `hardwareShiftDown` đang mắc `false`. KHÔNG phải mã sản phẩm.
//
// Phép đo: gõ "abc", Shift+Left, rồi "x".
//   Shift còn tác dụng -> "abx"   (x ghi đè chữ đang được chọn)
//   Shift bị gỡ        -> "abxc"  (mũi tên chỉ dời con trỏ)
//
// Vì sao cần: `passThrough` gỡ `.maskShift` khỏi event trả về app khi cờ là
// `false`, và v4.32 gỡ trên MỌI phím. Đo 09/10/2026 trên v4.32: ca `stuck` ra
// "abxc" — mất hẳn chọn chữ bằng bàn phím. Sau khi thu phạm vi về phím chữ và
// Backspace: ca `stuck` ra "abx". Shift+Enter cũng cùng một lẽ — gỡ Shift ở đó
// thì app chat gửi tin đang viết dở thay vì xuống dòng.
//
// Build:  swiftc -O Tools/probe/arrowtest.swift -o /tmp/arrowtest
// Chạy:   mở tài liệu TextEdit trống rồi `/tmp/arrowtest stuck` (hoặc `real`)

import AppKit
import Foundation
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "stuck"
guard let src = CGEventSource(stateID: .hidSystemState) else { exit(1) }
guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" else {
  print("TỪ CHỐI: frontmost không phải TextEdit"); exit(1)
}
let kLeft: CGKeyCode = 123, kShift: CGKeyCode = 56
func key(_ kc: CGKeyCode, _ flags: CGEventFlags) {
  for down in [true, false] {
    guard let e = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: down) else { continue }
    e.flags = flags
    e.post(tap: .cghidEventTap); usleep(25_000)
  }
  usleep(35_000)
}
func flagsChanged(_ flags: CGEventFlags, down: Bool) {
  guard let e = CGEvent(keyboardEventSource: src, virtualKey: kShift, keyDown: down) else { return }
  e.type = .flagsChanged
  e.flags = flags
  e.post(tap: .cghidEventTap); usleep(45_000)
}
for kc in [CGKeyCode(0), 11, 8] { key(kc, []) }   // a b c
if mode == "real" {
  flagsChanged(.maskShift, down: true)
  key(kLeft, .maskShift)
  flagsChanged([], down: false)
} else {
  key(kLeft, .maskShift)   // Shift chỉ dính trên event
}
key(7, [])  // x
print("mode=\(mode) xong")
