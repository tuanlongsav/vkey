//
//  PersonalDictSuggestionSheet.swift
//  vkey
//
//  Sheet mở từ tab Chính tả / Thống kê khi user bấm "Xem đề xuất".
//  Hiển thị các từ tiếng Việt / tiếng Anh user gõ ≥5 lần/tuần mà vkey
//  ĐỀ XUẤT thêm vào personal dictionary (Allow / Keep). User review,
//  chỉnh loại (Allow ↔ Keep), rồi chốt "Thêm" hoặc "Bỏ qua".
//
//  Thay thế cho cơ chế auto-promote cũ — tránh "auto bậy" làm bộ gõ
//  kém. User có quyền kiểm soát cuối.
//

import Defaults
import SwiftUI

struct PersonalDictSuggestionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.pendingDictSuggestions) private var pending
  @Default(.userAllowWords) private var userAllowWords
  @Default(.userKeepWords) private var userKeepWords

  var body: some View {
    VStack(spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        Text("Đề xuất bổ sung từ điển cá nhân")
          .font(.headline)
        Text("Các từ vkey nhận thấy bạn gõ ≥5 lần/tuần và có thể thêm vào Allow / Keep. Đổi loại nếu cần, rồi quyết định thêm.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 8)

      Divider()

      if pending.isEmpty {
        VStack(spacing: 12) {
          Spacer()
          ThemedSymbol(name: "lightbulb")
            .font(.system(size: 32))
            .foregroundStyle(.tertiary)
          Text("Chưa có đề xuất.")
            .font(.callout)
            .foregroundStyle(.secondary)
          Text("Bấm \"Chạy compute đề xuất ngay\" trong tab Thống kê để compute từ dữ liệu tuần này.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(minHeight: 280)
      }

      Divider()

      HStack {
        Button("Thêm tất cả") { acceptAll() }
          .disabled(pending.isEmpty)
        Button("Bỏ qua tất cả", role: .destructive) { dismissAll() }
          .disabled(pending.isEmpty)
        Spacer()
        Text("\(pending.count) đề xuất")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Đóng") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding(16)
    }
    .frame(width: 600, height: 480)
  }

  // MARK: - Actions

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
    // Snapshot trước khi mutate pending qua accept(_:).
    let snapshot = pending
    for s in snapshot {
      accept(s)
    }
  }

  private func dismissAll() {
    pending.removeAll()
  }
}
