//
//  RemoteInputPolicy.swift
//  vkey
//
//  Chính sách nhận diện phím từ bàn phím thật vs Screen Sharing, đứng ngoài
//  trong ứng dụng điều khiển máy từ xa, và đồng bộ Shift khi điều khiển từ xa.
//

import CoreGraphics
import Foundation

struct RemoteInputPolicy {

  /// Đường dẫn file chạy tiến trình Screen Sharing (dưới `/System/`, SIP bảo vệ).
  static let screenSharingAgentPath =
    "/System/Library/CoreServices/RemoteManagement/ScreensharingAgent.bundle/Contents/MacOS/ScreensharingAgent"

  /// Đệm kết quả theo PID nguồn để tránh gọi `proc_pidpath` trên đường nóng mỗi phím.
  private var sourcePIDCache: (pid: pid_t, isScreenSharing: Bool)?
  private let ownPID = getpid()

  /// Phím/chuột người dùng gần nhất đến qua Screen Sharing chứ không từ bàn phím thật.
  private(set) var lastUserInputWasRemote = false

  mutating func isUserInput(_ event: CGEvent) -> Bool {
    guard let remote = userInputOrigin(of: event) else { return false }
    lastUserInputWasRemote = remote
    return true
  }

  /// Nguồn của một event do người dùng gõ: `false` = HID thật, `true` = Screen Sharing,
  /// `nil` = không phải người dùng (vkey hoặc app tự động hoá tự phát).
  private mutating func userInputOrigin(of event: CGEvent) -> Bool? {
    let stateID = event.getIntegerValueField(.eventSourceStateID)
    if stateID == 1 { return false }
    let pid = pid_t(truncatingIfNeeded: event.getIntegerValueField(.eventSourceUnixProcessID))
    guard pid > 0, pid != ownPID else { return nil }
    if let cached = sourcePIDCache, cached.pid == pid { return cached.isScreenSharing ? true : nil }
    let result = Self.isUserInputSource(
      stateID: stateID, sourcePID: pid, ownPID: ownPID, pathForPID: Self.executablePath(of:))
    sourcePIDCache = (pid, result)
    return result ? true : nil
  }

  // MARK: - Pure Policy Helpers

  /// vkey đứng ngoài khi app đang trước là app điều khiển máy từ xa, trừ khi
  /// người dùng đặt app đó là "Tiếng Việt" trong Smart Switch.
  static func standsAsideForRemoteDesktop(
    frontmostBundle: String?, userState: @autoclosure () -> AppSmartSwitchState?
  ) -> Bool {
    guard let frontmostBundle,
      AppCompatibilityRegistry.remoteDesktopViewerBundles.contains(frontmostBundle)
    else {
      return false
    }
    return userState() != .vietnameseMode
  }

  /// keyDown đến qua Screen Sharing mang chữ đã soạn sẵn từ bộ gõ máy điều khiển.
  static func isPrecomposedRemoteText(_ payload: String) -> Bool {
    if payload.utf16.count > 1 { return true }
    return payload.unicodeScalars.contains {
      !$0.isASCII && !(0xF700...0xF8FF).contains($0.value)
    }
  }

  /// Chuỗi Unicode gắn trên một event phím (`""` nếu không có).
  static func unicodePayload(of event: CGEvent) -> String {
    var length = 0
    var units = [UniChar](repeating: 0, count: 32)
    event.keyboardGetUnicodeString(
      maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
    return length > 0 ? String(utf16CodeUnits: units, count: min(length, units.count)) : ""
  }

  /// Phím/chuột có phải từ bàn phím thật (HID, stateID 1) hoặc Screen Sharing không.
  static func isUserInputSource(
    stateID: Int64, sourcePID: pid_t, ownPID: pid_t,
    pathForPID: (pid_t) -> String?
  ) -> Bool {
    if stateID == 1 { return true }
    guard sourcePID > 0, sourcePID != ownPID else { return false }
    return pathForPID(sourcePID) == screenSharingAgentPath
  }

  static func executablePath(of pid: pid_t) -> String? {
    var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
    guard proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { return nil }
    return String(cString: buf)
  }

  /// Khi gõ qua Screen Sharing, không tin trạng thái HID của máy này (`nil` = tin event).
  static func resyncedShiftState(lastInputWasRemote: Bool, hidShiftDown: Bool) -> Bool? {
    lastInputWasRemote ? nil : hidShiftDown
  }
}
