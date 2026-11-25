//
//  SecureInputMonitor.swift
//  vkey
//
//  Theo dõi trạng thái Secure Input (ô mật khẩu, terminal sudo, app nền giữ kẹt)
//  và cảnh báo người dùng khi có tiến trình giữ Secure Input ngoài ý muốn.
//

import AppKit
import Foundation
import IOKit

// Private macOS API to detect secure input mode (password fields)
@_silgen_name("CGSIsSecureEventInputSet")
func CGSIsSecureEventInputSet() -> Bool

final class SecureInputMonitor {

  /// PID của tiến trình đang sở hữu system-wide secure input hiện tại (`nil` khi tắt).
  var ownerPID: pid_t?

  /// Số nhịp watchdog liên tiếp thấy tiến trình giữ secure input ngoài ý muốn.
  private var warningTicks = 0
  private let ownPID = getpid()

  /// Watchdog gọi định kỳ để gỡ ổ khoá khi cờ hệ thống đã tắt (Screen Sharing
  /// hoặc chưa có phím mới sau khi rời ô mật khẩu). Chỉ gỡ, không bật.
  func reconcile(systemFlag: Bool, lockShown: Bool) -> Bool {
    guard !systemFlag else { return false }
    ownerPID = nil
    return lockShown
  }

  /// Đánh giá secure input cho một event trong event tap callback và cập nhật `ownerPID`.
  func evaluateForEvent(
    systemFlag: Bool,
    frontmostApp: NSRunningApplication?
  ) -> Bool {
    let frontmostPID = frontmostApp?.processIdentifier
    let frontmostBundle = frontmostApp?.bundleIdentifier
    let verdict = Self.resolve(
      systemFlag: systemFlag,
      knownOwner: ownerPID,
      backgroundHolder: Self.backgroundHolderApp(frontmost: frontmostApp)?.processIdentifier,
      frontmostPID: frontmostPID,
      frontField: Focused.secureFieldState(),
      frontmostHidesPasswordPrompts: AppCompatibilityRegistry.isTerminalApp(frontmostBundle)
    )
    ownerPID = verdict.owner
    return verdict.isSecure
  }

  /// Gọi từ watchdog 2 giây. Trả tên tiến trình đang giữ Secure Input ngoài ý muốn
  /// sau 2 nhịp liên tiếp (tránh nháy icon khi ô mật khẩu vừa mở).
  func warningHolder(systemFlag: Bool) -> String? {
    guard systemFlag else {
      warningTicks = 0
      return nil
    }
    let frontmost = NSWorkspace.shared.frontmostApplication
    if let app = Self.backgroundHolderApp(frontmost: frontmost) {
      ownerPID = app.processIdentifier
    }
    guard let pid = Self.systemSecureInputOwnerPID(),
      Self.shouldWarnAboutHolder(
        ownerPID: pid, ownPID: ownPID, screenLocked: Self.isScreenLocked(),
        standingAsideForPasswordEntry: Self.resolve(
          systemFlag: true, knownOwner: pid, backgroundHolder: nil,
          frontmostPID: frontmost?.processIdentifier,
          frontField: Focused.secureFieldState(),
          frontmostHidesPasswordPrompts: AppCompatibilityRegistry.isTerminalApp(
            frontmost?.bundleIdentifier)
        ).isSecure)
    else {
      warningTicks = 0
      return nil
    }
    warningTicks += 1
    guard warningTicks >= 2 else { return nil }
    if let app = NSRunningApplication(processIdentifier: pid),
      let name = app.localizedName ?? app.bundleIdentifier
    {
      return name
    }
    if let path = RemoteInputPolicy.executablePath(of: pid) {
      return (path as NSString).lastPathComponent
    }
    return "pid \(pid)"
  }

  // MARK: - System Queries & Pure Decision Logic

  /// PID của tiến trình đang giữ secure input từ IORegistry (`IOConsoleUsers[].kCGSSessionSecureInputPID`).
  static func systemSecureInputOwnerPID() -> pid_t? {
    let root = IORegistryGetRootEntry(kIOMainPortDefault)
    guard root != 0 else { return nil }
    defer { IOObjectRelease(root) }
    guard
      let users = IORegistryEntryCreateCFProperty(
        root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? [[String: Any]]
    else { return nil }
    let uid = Int(getuid())
    let mine = users.filter { ($0["kCGSSessionUserIDKey"] as? NSNumber)?.intValue == uid }
    for user in mine.isEmpty ? users : mine {
      if let pid = (user["kCGSSessionSecureInputPID"] as? NSNumber)?.int32Value, pid > 0 {
        return pid
      }
    }
    return nil
  }

  /// Chủ secure input có chắc chắn là một app thường chạy nền (không phải app
  /// đang trước, tiến trình phụ của nó, agent hệ thống, hay chính vkey) không.
  static func isBackgroundHolder(
    ownerPID: pid_t?, ownerBundle: String?, ownerIsRegularApp: Bool,
    frontmostPID: pid_t?, frontmostBundle: String?, ownPID: pid_t
  ) -> Bool {
    guard let ownerPID, ownerPID > 0, ownerPID != ownPID, ownerPID != frontmostPID,
      ownerIsRegularApp
    else { return false }
    if let ownerBundle, let frontmostBundle, !frontmostBundle.isEmpty,
      ownerBundle == frontmostBundle || ownerBundle.hasPrefix(frontmostBundle + ".")
    {
      return false
    }
    return true
  }

  /// App nền đang giữ secure input, hoặc `nil`.
  static func backgroundHolderApp(
    frontmost: NSRunningApplication?
  ) -> NSRunningApplication? {
    guard let pid = systemSecureInputOwnerPID(),
      let owner = NSRunningApplication(processIdentifier: pid),
      isBackgroundHolder(
        ownerPID: pid, ownerBundle: owner.bundleIdentifier,
        ownerIsRegularApp: owner.activationPolicy == .regular,
        frontmostPID: frontmost?.processIdentifier,
        frontmostBundle: frontmost?.bundleIdentifier, ownPID: getpid())
    else { return nil }
    return owner
  }

  /// Có nên cảnh báo rằng Secure Input đang bật ngoài ý muốn không.
  static func shouldWarnAboutHolder(
    ownerPID: pid_t?, ownPID: pid_t, screenLocked: Bool,
    standingAsideForPasswordEntry: @autoclosure () -> Bool
  ) -> Bool {
    guard let ownerPID, ownerPID > 0, ownerPID != ownPID, !screenLocked else { return false }
    return !standingAsideForPasswordEntry()
  }

  /// Màn hình đang khoá (theo WindowServer).
  static func isScreenLocked() -> Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
  }

  /// Quyết định vkey có phải đứng ngoài vì secure input không cho một event.
  static func resolve(
    systemFlag: Bool, knownOwner: pid_t?,
    backgroundHolder: @autoclosure () -> pid_t?,
    frontmostPID: pid_t?,
    frontField: @autoclosure () -> Focused.SecureFieldState,
    frontmostHidesPasswordPrompts: Bool
  ) -> (isSecure: Bool, owner: pid_t?) {
    guard systemFlag else { return (false, nil) }
    let field = frontField()
    if field == .secure { return (true, frontmostPID) }
    let owner = knownOwner ?? backgroundHolder() ?? frontmostPID
    guard owner == frontmostPID else { return (false, owner) }
    if field == .plainText, !frontmostHidesPasswordPrompts { return (false, owner) }
    return (true, owner)
  }
}
