//
//  VKAppIdentityRow.swift
//  vkey
//
//  Tiện ích tra cứu app đang chạy / đã cài (`RunningAppsLookup`) và dòng hiển thị
//  icon + tên + bundle ID dùng chung giữa Smart Switch tab & các sheet chọn app.
//

import AppKit
import SwiftUI

struct RunningAppInfo: Identifiable {
  let id: String
  let bundleId: String
  let displayName: String
  let icon: NSImage?
}

enum RunningAppsLookup {
  /// Danh sách app thường đang chạy (trừ chính vkey), xếp theo tên.
  static func regularRunningApps() -> [RunningAppInfo] {
    let vkeyId = Bundle.main.bundleIdentifier ?? ""
    return NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular }
      .compactMap { app -> RunningAppInfo? in
        guard let id = app.bundleIdentifier, id != vkeyId else { return nil }
        return RunningAppInfo(
          id: id,
          bundleId: id,
          displayName: app.localizedName ?? id,
          icon: app.icon
        )
      }
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }

  /// Tên hiển thị thân thiện cho một bundle ID (ưu tiên app đang chạy, rồi tới Bundle trên đĩa).
  static func displayName(for bundleId: String) -> String {
    if let running = NSWorkspace.shared.runningApplications.first(where: {
      $0.bundleIdentifier == bundleId
    }), let name = running.localizedName {
      return name
    }
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
      let bundle = Bundle(url: url)
    {
      if let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
        return name
      }
      if let name = bundle.infoDictionary?["CFBundleName"] as? String {
        return name
      }
      return url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
    }
    return bundleId.components(separatedBy: ".").last ?? bundleId
  }

  /// Icon của ứng dụng theo bundle ID (nếu cài trên máy).
  static func icon(for bundleId: String) -> NSImage? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
      return NSWorkspace.shared.icon(forFile: url.path)
    }
    return nil
  }
}

/// Hàng hiển thị icon app (24×24) + tên + bundle ID (monospace) dùng trong các sheet.
struct VKAppIdentityRow: View {
  let displayName: String
  let bundleId: String
  let icon: NSImage?

  init(displayName: String, bundleId: String, icon: NSImage? = nil) {
    self.displayName = displayName
    self.bundleId = bundleId
    self.icon = icon
  }

  var body: some View {
    HStack(spacing: 10) {
      if let icon {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 24, height: 24)
      } else {
        Image(systemName: "app.dashed")
          .font(.system(size: 22))
          .foregroundStyle(.tertiary)
          .frame(width: 24, height: 24)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(displayName)
          .font(.body)
          .lineLimit(1)
          .truncationMode(.middle)
        Text(bundleId)
          .font(.system(.caption2, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
  }
}
