// kcpost — công cụ ĐO: bắn MỘT event chỉ mang chuỗi Unicode vào một tiến trình cụ
// thể, theo mã phím chỉ định. KHÔNG phải mã sản phẩm. Dùng kèm `kcsweep` khi cần đo
// trên app nền Blink (Chrome, Electron) thay vì TextEdit.
//
// Nhắm theo PID, không theo bundle id, và TỪ CHỐI gửi nếu pid đó không đang
// frontmost: trên máy này thường có hai Chrome cùng bundle id (hồ sơ thật của người
// dùng và hồ sơ tạm của phép đo) — gửi lạc vào hồ sơ thật là gõ chữ vào tab của
// người dùng. Tiến trình gọi cũng KHÔNG tự activate: dùng
//   osascript -e 'tell application "System Events" to set frontmost of ¬
//     (first process whose unix id is PID) to true'
//
// Cách đo trên Chrome (hồ sơ tạm, không đụng hồ sơ thật):
//   1. /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
//        --user-data-dir=/tmp/kcprobe-profile --remote-debugging-port=9222 \
//        --no-first-run --no-default-browser-check file:///tmp/kc.html
//      (kc.html: một <input id="f" autofocus>)
//   2. node Tools/probe/cdp.mjs "(()=>{const f=document.getElementById('f');f.value='';f.focus();return 'ok'})()" --match kc.html
//   3. đưa pid lên frontmost (lệnh osascript ở trên), rồi /tmp/kcpost <pid> <keycode> 'ề'
//   4. node Tools/probe/cdp.mjs "document.getElementById('f').value" --match kc.html
//   5. xoá /tmp/kcprobe-profile sau khi đo.
//
// Kết quả 09/10/2026 (Chrome 1xx, ô <input> web): mã 0, 10, 90, 110 ra đúng chữ và
// KHÔNG chèn thêm ký tự nào; mã 0 gửi "google" ra đúng "google" — tức giả thuyết
// "Chromium chèn cả ký tự của mã phím" của v4.32 không tái hiện được. Mã 255 mất trắng.
//
// Build:  swiftc -O Tools/probe/kcpost.swift -o /tmp/kcpost

import AppKit
import Foundation
let a = CommandLine.arguments
guard a.count >= 4, let pid = Int32(a[1]), let kcRaw = UInt16(a[2]) else {
  print("usage: kcpost2 <pid> <kc> <text>"); exit(2)
}
let kc = CGKeyCode(kcRaw), text = a[3]
guard let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier == pid else {
  let f = NSWorkspace.shared.frontmostApplication
  print("TỪ CHỐI: frontmost pid=\(f?.processIdentifier ?? -1) (\(f?.bundleIdentifier ?? "?")) != \(pid)")
  exit(1)
}
guard let src = CGEventSource(stateID: .privateState),
      let dn = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: true),
      let up = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: false)
else { print("kc=\(kc): không tạo được event"); exit(1) }
let units = Array(text.utf16).map { UniChar($0) }
for e in [dn, up] {
  e.setIntegerValueField(.keyboardEventKeycode, value: Int64(kc))
  e.flags = .maskNonCoalesced
  e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
}
dn.post(tap: .cgSessionEventTap); up.post(tap: .cgSessionEventTap)
usleep(300_000)
print("sent kc=\(kc) '\(text)'")
