// evlog — công cụ ĐO: ghi lại chuỗi event bàn phím mà vkey nhận, kèm trạng thái
// modifier của phần cứng. KHÔNG phải mã sản phẩm.
//
// ⚠️ ĐÂY LÀ KEYLOGGER. Nó đọc được mọi phím, kể cả mật khẩu. Hai chốt cứng,
// không có cờ để bỏ qua:
//   1. chỉ ghi khi bundle id truyền vào đang là app frontmost — gõ ở app khác
//      thì event vẫn đi qua tap nhưng KHÔNG được ghi ra;
//   2. tự thoát sau số giây truyền vào.
// Thiếu một trong hai tham số là từ chối chạy. Đo xong thì XOÁ file log —
// trong phiên 09/10/2026 bản đầu của công cụ này (chưa có chốt 1) đã kịp ghi
// phím người dùng gõ tay sang app khác, phải tắt và xoá ngay.
//
// Vì sao cần: `InputProcessor.hardwareShiftDown` phân biệt "Shift thật" với
// "Shift chỉ dính trên event" BẰNG `flagsChanged`, và quyết định đó không đọc
// được từ ngoài. Công cụ này cho thấy đúng chuỗi event vkey nhận, nên trả lời
// được hai câu mà suy diễn không trả lời được: có `flagsChanged` nào đi kèm
// không, và event do vkey tự phát (`sid=synth`) mang cờ gì.
//
// Kết quả 09/10/2026, so với `shifttest.swift`:
//   real : flagsChg kc=56 SHIFT hidShift=true → keyDown kc=8 SHIFT hidShift=true → "C"
//   stuck:                                      keyDown kc=8 SHIFT hidShift=true → "c"
// Tức `CGEventSource.flagsState` báo `true` ở CẢ HAI ca, nên nó KHÔNG dùng để
// phân biệt Shift kẹt được — chỉ dùng để đồng bộ lại cờ sau khi tap gián đoạn.
// `NSEvent.modifierFlags` thì trễ một event (`nsShift` trong log), đừng dùng.
//
// Build:  swiftc -O Tools/probe/evlog.swift -o /tmp/evlog
// Chạy:   /tmp/evlog com.apple.TextEdit 7 > /tmp/evlog.txt

import AppKit
import Foundation

let a = CommandLine.arguments
guard a.count >= 3, let seconds = Double(a[2]) else {
  print("usage: evlog2 <bundleId> <seconds>"); exit(2)
}
let target = a[1]

func fmt(_ f: CGEventFlags) -> String {
  var s: [String] = []
  if f.contains(.maskShift) { s.append("SHIFT") }
  if f.contains(.maskAlphaShift) { s.append("CAPS") }
  if f.contains(.maskCommand) { s.append("CMD") }
  if f.contains(.maskControl) { s.append("CTRL") }
  if f.contains(.maskAlternate) { s.append("ALT") }
  return s.isEmpty ? "-" : s.joined(separator: "+")
}

let cb: CGEventTapCallBack = { _, type, event, refcon in
  let want = Unmanaged<NSString>.fromOpaque(refcon!).takeUnretainedValue() as String
  guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == want else {
    return Unmanaged.passUnretained(event)  // app khác đang focus → KHÔNG ghi
  }
  let kc = event.getIntegerValueField(.keyboardEventKeycode)
  let sid = event.getIntegerValueField(.eventSourceStateID)
  var len = 0
  var buf = [UniChar](repeating: 0, count: 8)
  event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &len, unicodeString: &buf)
  let str = len > 0 ? String(utf16CodeUnits: buf, count: len) : ""
  let name = type == .keyDown ? "keyDown " : (type == .flagsChanged ? "flagsChg" : "keyUp   ")
  // Nguồn sự thật ứng viên: trạng thái modifier hiện tại của phần cứng, đọc
  // trực tiếp thay vì theo dõi qua flagsChanged.
  let hidState = CGEventSource.flagsState(.hidSystemState)
  let nsFlags = NSEvent.modifierFlags
  FileHandle.standardOutput.write(
    "\(name) kc=\(String(format: "%3d", kc)) flags=\(fmt(event.flags)) sid=\(sid == 1 ? "HID" : "synth") hidShift=\(hidState.contains(.maskShift)) nsShift=\(nsFlags.contains(.shift)) str=\(str.debugDescription)\n"
      .data(using: .utf8)!)
  return Unmanaged.passUnretained(event)
}

let box = Unmanaged.passRetained(target as NSString).toOpaque()
let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
guard let tap = CGEvent.tapCreate(
  tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
  eventsOfInterest: CGEventMask(mask), callback: cb, userInfo: box)
else { print("tapCreate = nil"); exit(1) }
let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exit(0) }
CFRunLoopRun()
