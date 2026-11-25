//
//  SmartSwitchAutoLearnSheet.swift
//  vkey
//
//  Sheet hiển thị gợi ý Smart Switch từ Stats (≥5 ngày, ≥5 commit/ngày,
//  tỷ lệ ngôn ngữ ≥75% hoặc ≤25%). Không ghi đè entry `source == .user`.
//

import AppKit
import Defaults
import SwiftUI

struct SmartSwitchAutoLearnSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.appSmartSwitchConfigs) private var configs

  @State private var suggestions: [SuggestionRow] = []
  @State private var statusMessage: String = ""

  private struct SuggestionRow: Identifiable {
    let id: String
    let bundleId: String
    let displayName: String
    let icon: NSImage?
    let suggestedState: AppSmartSwitchState
    let currentConfig: AppSmartSwitchConfig?
  }

  var body: some View {
    VKSheetScaffold(
      title: "Tự động học từ Thống kê",
      subtitle: "vkey gợi ý chế độ phù hợp cho các app bạn đã dùng ≥5 ngày trong tuần với ≥5 commit/ngày. Cài đặt do bạn đặt thủ công (👤) KHÔNG bị thay đổi.",
      width: 560,
      height: 480
    ) {
      VStack(spacing: 0) {
        if suggestions.isEmpty {
          Spacer()
          VKEmptyState(
            systemImage: "tray",
            title: "Chưa có gợi ý",
            message: "Gõ thêm trong các app khác nhau ít nhất 5 ngày để vkey có đủ data học pattern ngôn ngữ."
          )
          Spacer()
        } else {
          List(suggestions) { row in
            HStack(spacing: 10) {
              VKAppIdentityRow(displayName: row.displayName, bundleId: row.bundleId, icon: row.icon)

              Spacer()

              if let current = row.currentConfig {
                Text("Hiện: \(current.state.shortLabel)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                if current.source == .autoLearn {
                  Text("🤖").font(.caption2)
                } else {
                  Image(systemName: "person.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
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

        if !statusMessage.isEmpty {
          Divider()
          Text(statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
      }
    } footer: {
      Button("Áp dụng tất cả", action: applyAll)
        .disabled(suggestions.allSatisfy { $0.currentConfig?.source == .user })
        .help("Áp dụng các gợi ý cho app vkey chưa lock (không có 🔒). User-set entries giữ nguyên.")

      Spacer()

      Button("Đóng") { dismiss() }
        .keyboardShortcut(.defaultAction)
    }
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
          displayName: RunningAppsLookup.displayName(for: bundleId),
          icon: RunningAppsLookup.icon(for: bundleId),
          suggestedState: state,
          currentConfig: configs[bundleId]
        )
      }
  }

  private func applyAll() {
    var applied = 0
    for row in suggestions where row.currentConfig?.source != .user {
      configs[row.bundleId] = AppSmartSwitchConfig(
        state: row.suggestedState, source: .autoLearn, lastModified: Date()
      )
      applied += 1
    }
    if applied == 0 {
      statusMessage = "Không có gợi ý nào để áp dụng (tất cả đã do bạn đặt thủ công)."
    } else {
      statusMessage = "Đã áp dụng \(applied) gợi ý. Đóng sheet để xem lại tab Smart Switch."
      load()
    }
  }
}
