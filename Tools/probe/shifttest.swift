// shifttest — công cụ ĐO: dựng hai tình huống Shift mà `hardwareShiftDown`
// phân biệt, để kiểm cơ chế đó thay vì suy diễn. KHÔNG phải mã sản phẩm.
//
//   stuck : keyDown mang maskShift NHƯNG không có `flagsChanged` nào trước đó
//           — đúng mô tả "Shift kẹt sau chữ hoa tổng hợp" của v4.32.
//   real  : flagsChanged(Shift down) → keyDown mang maskShift → flagsChanged(up)
//           — người gõ thật sự giữ Shift.
//
// Hai ca này cũng là CÙNG MỘT thứ dưới mắt vkey khi `flagsChanged` bị mất (tap
// bị hệ thống vô hiệu, tap gắn lại, quyền Trợ năng mất rồi cấp lại). Nên `stuck`
// đồng thời là phép đo thiệt hại của lần cờ mắc sai.
//
// Post vào `.cghidEventTap`: vkey tap ở session tap, post vào đó thì vkey không
// thấy gì (xem `keyprobe.swift`).
//
// Kết quả 09/10/2026 trên bản đã sửa:
//   stuck "xin " + Shift+c + "hao" → "xin chao"   (cờ làm việc của nó)
//   real  "xin " + Shift+c + "hao" → "xin Chao"
// Còn lỗi GỐC mà v4.32 đi vá — chữ cái thứ hai đầu câu bị viết hoa trên BÀN
// PHÍM THẬT — thì phép đo này KHÔNG tái hiện được: với event tổng hợp, event
// HID sau chữ hoa tổng hợp không mang Shift (xem `evlog.swift`). Ai muốn gỡ
// `hardwareShiftDown` phải đo lại trên bàn phím thật trước.
//
// Build:  swiftc -O Tools/probe/shifttest.swift -o /tmp/shifttest
// Chạy:   mở tài liệu TextEdit trống rồi
//         /tmp/shifttest stuck "xin " c "hao"
//         osascript -e 'tell application "TextEdit" to get text of document 1'
// ⚠️ Bộ đệm từ của vkey còn giữ từ cuối của lượt trước, nên ký tự đầu lượt sau
// hay dính vào nó. Bắt đầu prefix bằng dấu cách, hoặc bỏ qua nhiễu đầu dòng.

import AppKit
import Foundation
let a = CommandLine.arguments
guard a.count >= 5 else { print("usage: shifttest <stuck|real> <prefix> <char> <suffix>"); exit(2) }
let mode = a[1], prefix = a[2], shifted = Character(a[3]), suffix = a[4]
guard let src = CGEventSource(stateID: .hidSystemState) else { exit(1) }
guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" else {
  print("TỪ CHỐI: frontmost = \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?")"); exit(1)
}
let map: [Character: CGKeyCode] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,
  "b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"o":31,"u":32,"i":34,"p":35,"l":37,"j":38,
  "k":40,"n":45,"m":46," ":49,".":47]
let kShift: CGKeyCode = 56
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
for ch in prefix { if let kc = map[ch] { key(kc, []) } }
guard let sk = map[shifted] else { print("ký tự không có trong bảng"); exit(2) }
if mode == "real" {
  flagsChanged(.maskShift, down: true)
  key(sk, .maskShift)
  flagsChanged([], down: false)
} else {
  key(sk, .maskShift)   // Shift chỉ dính trên event, không có flagsChanged
}
for ch in suffix { if let kc = map[ch] { key(kc, []) } }
print("mode=\(mode) xong")
