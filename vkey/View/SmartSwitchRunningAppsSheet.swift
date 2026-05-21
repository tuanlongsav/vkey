//
//  SmartSwitchRunningAppsSheet.swift
//  vkey (v1.7.1+)
//
//  Sheet hiển thị danh sách các app đang chạy trên macOS. User click 1
//  app để thêm vào `appSmartSwitchConfigs` với state mặc định
//  `.englishMode` + `source = .user`. Nhanh hơn paste bundle ID thủ công.
//
//  Filter `activationPolicy == .regular` để loại bỏ helpers/daemons.
//  Loại vkey itself khỏi list.
//

import AppKit
import Defaults
import SwiftUI

struct SmartSwitchRunningAppsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.appSmartSwitchConfigs) private var configs

  private struct RunningApp: Identifiable {
    let id: String
    let bundleId: String
    let displayName: String
    let icon: NSImage?
  }

  @State private var apps: [RunningApp] = []
  @State private var searchText: String = ""

  private var filteredApps: [RunningApp] {
    guard !searchText.isEmpty else { return apps }
    let q = searchText.lowercased()
    return apps.filter {
      $0.displayName.lowercased().contains(q) || $0.bundleId.lowercased().contains(q)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Chọn ứng dụng đang chạy")
          .font(.headline)
        Text("Click 1 app để thêm vào danh sách Smart Switch (mặc định state 🇺🇸 EN, có thể đổi sau). App đã cấu hình sẽ hiện ✓.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 8)

      HStack {
        ThemedSymbol(name: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Tìm theo tên hoặc bundle ID", text: $searchText)
          .textFieldStyle(.plain)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color(NSColor.controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .padding(.horizontal, 16)
      .padding(.bottom, 8)

      Divider()

      if filteredApps.isEmpty {
        VStack(spacing: 8) {
          Spacer()
          ThemedSymbol(name: "tray")
            .font(.system(size: 36))
            .foregroundStyle(.tertiary)
          Text(apps.isEmpty ? "Không tìm thấy app đang chạy" : "Không có app khớp tìm kiếm")
            .font(.callout)
            .foregroundStyle(.secondary)
          Spacer()
        }
      } else {
        let items = filteredApps
        List {
          ForEach(items) { (app: RunningApp) in
            Button { addApp(app) } label: {
            HStack(spacing: 10) {
              if let icon = app.icon {
                Image(nsImage: icon)
                  .resizable()
                  .frame(width: 24, height: 24)
              } else {
                ThemedSymbol(name: "app.dashed")
                  .font(.system(size: 22))
                  .foregroundStyle(.tertiary)
                  .frame(width: 24, height: 24)
              }
              VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                  .font(.body)
                  .lineLimit(1)
                  .truncationMode(.middle)
                Text(app.bundleId)
                  .font(.system(.caption2, design: .monospaced))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .truncationMode(.middle)
              }
              Spacer()
              if let existing = configs[app.bundleId] {
                Text("Đã cấu hình: \(existing.state.shortLabel)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                ThemedSymbol(name: "checkmark.circle.fill")
                  .foregroundStyle(.green)
              } else {
                ThemedSymbol(name: "plus.circle")
                  .foregroundStyle(Color.accentColor)
              }
            }
            .contentShape(Rectangle())
          }
            .buttonStyle(.plain)
            .disabled(configs[app.bundleId] != nil)
          }
        }
        .listStyle(.inset)
      }

      Divider()

      HStack {
        Text("\(filteredApps.count) app")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Đóng") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding(16)
    }
    .frame(width: 420, height: 520)
    .onAppear(perform: loadRunningApps)
  }

  private func loadRunningApps() {
    let vkeyId = Bundle.main.bundleIdentifier ?? ""
    apps = NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular }
      .filter { $0.bundleIdentifier != nil && $0.bundleIdentifier != vkeyId }
      .compactMap { app in
        guard let id = app.bundleIdentifier else { return nil }
        return RunningApp(
          id: id,
          bundleId: id,
          displayName: app.localizedName ?? id,
          icon: app.icon
        )
      }
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }

  private func addApp(_ app: RunningApp) {
    configs[app.bundleId] = AppSmartSwitchConfig(
      state: .englishMode,
      source: .user,
      lastModified: Date()
    )
    // Refresh để hiện ✓
    loadRunningApps()
  }
}
