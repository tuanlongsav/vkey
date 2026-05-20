//
//  SmartSwitchSuggestionSheet.swift / SmartSwitchAutoLearnSheet
//  vkey
//
//  1.7.0: Đổi từ "Gợi ý apps thêm vào smartSwitchApps" thành "Auto-learn"
//  sheet. Hiển thị các app vkey đề xuất set state (Tiếng Việt / Tiếng Anh)
//  dựa trên Stats per-app language ratio, áp ngưỡng:
//    - ≥5 ngày dataset trong tuần này
//    - ≥5 commit/ngày trung bình
//    - ratio language ≥75% (hoặc ≤25% cho Tiếng Anh)
//
//  User-set entries (source=.user) KHÔNG bị override khi áp dụng.
//

import AppKit
import Defaults
import SwiftUI

/// 1.7.0: Sheet hiển thị auto-learn suggestions từ Stats. User review +
/// apply để vkey set state (Tiếng Việt/Tiếng Anh) cho các app dùng nhiều.
struct SmartSwitchAutoLearnSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.appSmartSwitchConfigs) private var configs

  @State private var suggestions: [SuggestionRow] = []
  @State private var statusMessage: String = ""

  private struct SuggestionRow: Identifiable {
    let id: String
    let bundleId: String
    let displayName: String
    let suggestedState: AppSmartSwitchState
    let currentConfig: AppSmartSwitchConfig?
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        Text("Tự động học từ Thống kê")
          .font(.headline)
        Text("vkey gợi ý chế độ phù hợp cho các app bạn đã dùng ≥5 ngày trong tuần với ≥5 commit/ngày. Cài đặt do bạn đặt thủ công (👤) KHÔNG bị thay đổi.")
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
        VStack(spacing: 8) {
          Image(systemName: "tray")
            .font(.system(size: 36))
            .foregroundStyle(.tertiary)
          Text("Chưa có gợi ý")
            .font(.callout)
            .foregroundStyle(.secondary)
          Text("Gõ thêm trong các app khác nhau ít nhất 5 ngày để vkey có đủ data học pattern ngôn ngữ.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
        }
        Spacer()
      } else {
        List(suggestions) { row in
          HStack(spacing: 10) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: row.bundleId) {
              Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 24, height: 24)
            } else {
              Image(systemName: "app.dashed")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
              Text(row.displayName)
                .font(.body)
              Text(row.bundleId)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let current = row.currentConfig {
              Text("Hiện: \(current.state.shortLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Image(systemName: current.source.iconSymbol)
                .font(.caption2)
                .foregroundStyle(current.source == .user ? .blue : .purple)
              Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Text(row.suggestedState.shortLabel)
              .font(.system(.caption, design: .rounded))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(badgeColor(for: row.suggestedState).opacity(0.15))
              .foregroundStyle(badgeColor(for: row.suggestedState))
              .clipShape(Capsule())

            if row.currentConfig?.source == .user {
              Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .help("Bạn đã đặt thủ công — sẽ KHÔNG bị thay đổi.")
            }
          }
          .padding(.vertical, 2)
        }
        .listStyle(.inset)
      }

      Divider()

      if !statusMessage.isEmpty {
        Text(statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
      }

      HStack {
        Button("Áp dụng tất cả") {
          applyAll()
        }
        .disabled(suggestions.allSatisfy { $0.currentConfig?.source == .user })
        .help("Áp dụng các gợi ý cho app vkey chưa lock (không có 🔒). User-set entries giữ nguyên.")

        Spacer()

        Button("Đóng") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding(16)
    }
    .frame(width: 560, height: 480)
    .onAppear(perform: load)
  }

  private func badgeColor(for state: AppSmartSwitchState) -> Color {
    switch state {
    case .disabled: return .gray
    case .vietnameseMode: return .red
    case .englishMode: return .blue
    }
  }

  private func load() {
    let computed = UsageStatistics.shared.computeSmartSwitchAutoLearn()
    suggestions = computed
      .sorted { $0.key < $1.key }
      .map { (bundleId, state) in
        SuggestionRow(
          id: bundleId,
          bundleId: bundleId,
          displayName: friendlyName(for: bundleId),
          suggestedState: state,
          currentConfig: configs[bundleId]
        )
      }
  }

  private func friendlyName(for bundleId: String) -> String {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
       let bundle = Bundle(url: url) {
      if let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
        return name
      }
      if let name = bundle.infoDictionary?["CFBundleName"] as? String {
        return name
      }
      return url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
    }
    return bundleId
  }

  private func applyAll() {
    var applied = 0
    for row in suggestions {
      // Skip user-set entries (source=.user)
      if row.currentConfig?.source == .user { continue }
      configs[row.bundleId] = AppSmartSwitchConfig(
        state: row.suggestedState, source: .autoLearn, lastModified: Date()
      )
      applied += 1
    }
    if applied == 0 {
      statusMessage = "Không có gợi ý nào để áp dụng (tất cả đã do bạn đặt thủ công)."
    } else {
      statusMessage = "Đã áp dụng \(applied) gợi ý. Đóng sheet để xem lại tab Smart Switch."
      load()  // reload to refresh current state badges
    }
  }
}
