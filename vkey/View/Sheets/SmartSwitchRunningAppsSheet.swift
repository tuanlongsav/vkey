//
//  SmartSwitchRunningAppsSheet.swift
//  vkey
//
//  Sheet hiển thị các app đang chạy trên macOS để thêm nhanh vào Smart Switch.
//

import AppKit
import Defaults
import SwiftUI

struct SmartSwitchRunningAppsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.appSmartSwitchConfigs) private var configs

  @State private var apps: [RunningAppInfo] = []
  @State private var searchText: String = ""

  private var filteredApps: [RunningAppInfo] {
    guard !searchText.isEmpty else { return apps }
    let q = searchText.lowercased()
    return apps.filter {
      $0.displayName.lowercased().contains(q) || $0.bundleId.lowercased().contains(q)
    }
  }

  var body: some View {
    VKSheetScaffold(
      title: "Chọn ứng dụng đang chạy",
      subtitle: "Click 1 app để thêm vào danh sách Smart Switch (mặc định state 🇺🇸 EN, có thể đổi sau). App đã cấu hình sẽ hiện ✓.",
      width: 420,
      height: 520
    ) {
      VStack(spacing: 0) {
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
          TextField("Tìm theo tên hoặc bundle ID", text: $searchText)
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)

        Divider()

        if filteredApps.isEmpty {
          Spacer()
          VKEmptyState(
            systemImage: "tray",
            title: apps.isEmpty ? "Không tìm thấy app đang chạy" : "Không có app khớp tìm kiếm"
          )
          Spacer()
        } else {
          List {
            ForEach(filteredApps) { app in
              Button { addApp(app) } label: {
                HStack(spacing: 10) {
                  VKAppIdentityRow(
                    displayName: app.displayName, bundleId: app.bundleId, icon: app.icon)
                  Spacer()
                  if let existing = configs[app.bundleId] {
                    Text("Đã cấu hình: \(existing.state.shortLabel)")
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundStyle(.green)
                  } else {
                    Image(systemName: "plus.circle")
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
      }
    } footer: {
      Text("\(filteredApps.count) app")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Button("Đóng") { dismiss() }
        .keyboardShortcut(.defaultAction)
    }
    .onAppear(perform: loadRunningApps)
  }

  private func loadRunningApps() {
    apps = RunningAppsLookup.regularRunningApps()
  }

  private func addApp(_ app: RunningAppInfo) {
    configs[app.bundleId] = AppSmartSwitchConfig(
      state: .englishMode,
      source: .user,
      lastModified: Date()
    )
    loadRunningApps()
  }
}
