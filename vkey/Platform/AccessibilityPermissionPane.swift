//
//  AccessibilityPermissionPane.swift
//  vkey
//
//  Tên mục cấp quyền Trợ năng theo phiên bản macOS và deep link mở System Settings.
//

import AppKit
import Foundation

/// Tên mục cấp quyền mà vkey cần trong Cài đặt Hệ thống → Quyền riêng tư & Bảo mật.
/// macOS 27 đổi tên mục này từ "Accessibility / Trợ năng" sang
/// "Device Control and Data Access / Điều khiển thiết bị và truy cập dữ liệu".
enum AccessibilityPermissionPane {
  static let settingsURLString =
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

  static func names(
    osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
  ) -> (vi: String, en: String) {
    osMajorVersion >= 27
      ? ("Điều khiển thiết bị và truy cập dữ liệu", "Device Control and Data Access")
      : ("Trợ năng", "Accessibility")
  }

  /// Tên tiếng Việt kèm tên tiếng Anh (vì System Settings theo ngôn ngữ của máy).
  static var displayName: String {
    let n = names()
    return "\(n.vi) (\(n.en))"
  }

  /// Đường dẫn đầy đủ trong Cài đặt Hệ thống (tiếng Anh).
  static var settingsPath: String {
    "System Settings → Privacy & Security → \(names().en)"
  }

  /// Mở thẳng trang quyền Accessibility trong System Settings.
  static func openSettings() {
    if let url = URL(string: settingsURLString) {
      NSWorkspace.shared.open(url)
    }
  }
}
