//
//  SmartSwitchSuggestionSheet.swift
//  vkey
//
//  Sheet mở từ `SmartSwitchView` khi user bấm "Xem & thêm" ở dòng "Gợi
//  ý từ Thống kê". Hiển thị các app user đã gõ ≥10 lần (cộng dồn qua
//  tuần) mà chưa nằm trong danh sách `smartSwitchApps`. User bấm
//  "Thêm" để add bundleID vào list.
//

import AppKit
import Defaults
import SwiftUI

struct SmartSwitchSuggestionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.smartSwitchApps) private var smartSwitchApps

  private struct Suggestion: Identifiable {
    let id: String          // bundle ID
    let bundleId: String
    let count: Int
    var added: Bool = false
    var displayName: String  // best-effort human-friendly name
  }

  @State private var suggestions: [Suggestion] = []

  var body: some View {
    VStack(spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        Text("Gợi ý app cho Smart Switch")
          .font(.headline)
        Text("Các app bạn dùng ≥10 lần (tất cả tuần) mà chưa nằm trong danh sách. Bấm \"Thêm\" để Smart Switch tự chuyển sang tiếng Anh khi mở app đó.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 8)

      Divider()

      if suggestions.isEmpty {
        Spacer()
        Text("Chưa có gợi ý — gõ nhiều hơn trong các app bạn muốn Smart Switch.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding()
        Spacer()
      } else {
        Table($suggestions) {
          TableColumn("Ứng dụng") { $suggestion in
            VStack(alignment: .leading, spacing: 2) {
              Text(suggestion.displayName)
                .foregroundStyle(suggestion.added ? .secondary : .primary)
              Text(suggestion.bundleId)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            }
          }
          TableColumn("Số lần") { $suggestion in
            Text("\(suggestion.count)")
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          .width(60)
          TableColumn("") { $suggestion in
            Button(suggestion.added ? "Đã thêm" : "Thêm") {
              addApp(suggestion)
            }
            .disabled(suggestion.added)
          }
          .width(80)
        }
        .frame(minHeight: 240)
      }

      Divider()

      HStack {
        Button("Thêm tất cả") {
          addAllPending()
        }
        .disabled(suggestions.allSatisfy { $0.added })

        Spacer()

        Button("Đóng") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding(16)
    }
    .frame(width: 520, height: 460)
    .onAppear(perform: load)
  }

  // MARK: - Actions

  private func load() {
    let aggregated = UsageStatistics.shared.aggregatedTopApps(threshold: 10)
    let existing = Set(smartSwitchApps)
    suggestions = aggregated.compactMap { wc in
      guard !existing.contains(wc.word) else { return nil }
      return Suggestion(
        id: wc.word,
        bundleId: wc.word,
        count: wc.count,
        displayName: friendlyAppName(forBundleID: wc.word)
      )
    }
  }

  private func friendlyAppName(forBundleID bundleID: String) -> String {
    // Try LaunchServices via NSWorkspace.
    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
      let bundle = Bundle(url: appURL)
      if let display = bundle?.infoDictionary?["CFBundleDisplayName"] as? String {
        return display
      }
      if let name = bundle?.infoDictionary?["CFBundleName"] as? String {
        return name
      }
      return appURL.deletingPathExtension().lastPathComponent
    }
    return bundleID
  }

  private func addApp(_ suggestion: Suggestion) {
    guard let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
    if !smartSwitchApps.contains(suggestion.bundleId) {
      smartSwitchApps.append(suggestion.bundleId)
    }
    suggestions[idx].added = true
  }

  private func addAllPending() {
    for s in suggestions where !s.added {
      addApp(s)
    }
  }
}
