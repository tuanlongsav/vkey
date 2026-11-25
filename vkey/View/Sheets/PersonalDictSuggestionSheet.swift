//
//  PersonalDictSuggestionSheet.swift
//  vkey
//
//  Sheet duyệt đề xuất bổ sung từ điển cá nhân (Allow / Keep) từ Thống kê.
//

import Defaults
import SwiftUI

struct PersonalDictSuggestionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.pendingDictSuggestions) private var pending
  @Default(.userAllowWords) private var userAllowWords
  @Default(.userKeepWords) private var userKeepWords

  var body: some View {
    VKSheetScaffold(
      title: "Đề xuất bổ sung từ điển cá nhân",
      subtitle: "Các từ vkey nhận thấy bạn gõ ≥5 lần/tuần và có thể thêm vào Allow / Keep. Đổi loại nếu cần, rồi quyết định thêm.",
      width: 600,
      height: 480
    ) {
      if pending.isEmpty {
        VKEmptyState(
          systemImage: "lightbulb",
          title: "Chưa có đề xuất.",
          message: "Bấm \"Chạy tính toán\" trong tab Thống kê để tính đề xuất từ dữ liệu tuần này."
        )
      } else {
        Table($pending) {
          TableColumn("Từ") { $s in
            Text(s.word)
          }
          TableColumn("Số lần") { $s in
            Text("\(s.count)")
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          .width(60)
          TableColumn("Loại") { $s in
            Picker("", selection: $s.kind) {
              Text("Allow").tag(PendingDictSuggestion.Kind.allow)
              Text("Keep").tag(PendingDictSuggestion.Kind.keep)
            }
            .labelsHidden()
            .pickerStyle(.menu)
          }
          .width(110)
          TableColumn("") { $s in
            HStack(spacing: 4) {
              Button("Thêm") { accept(s) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
              Button("Bỏ qua") { dismissOne(s) }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
          }
          .width(150)
        }
      }
    } footer: {
      Button("Thêm tất cả", action: acceptAll)
        .disabled(pending.isEmpty)
      Button("Bỏ qua tất cả", role: .destructive, action: dismissAll)
        .disabled(pending.isEmpty)
      Spacer()
      Text("\(pending.count) đề xuất")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Button("Đóng") { dismiss() }
        .keyboardShortcut(.defaultAction)
    }
  }

  private func accept(_ s: PendingDictSuggestion) {
    switch s.kind {
    case .allow:
      if !userAllowWords.contains(s.word) {
        userAllowWords.append(s.word)
      }
    case .keep:
      if !userKeepWords.contains(s.word) {
        userKeepWords.append(s.word)
      }
    }
    pending.removeAll { $0.id == s.id }
  }

  private func dismissOne(_ s: PendingDictSuggestion) {
    pending.removeAll { $0.id == s.id }
  }

  private func acceptAll() {
    let snapshot = pending
    for s in snapshot {
      accept(s)
    }
  }

  private func dismissAll() {
    pending.removeAll()
  }
}
