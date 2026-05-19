//
//  MacroSuggestionSheet.swift
//  vkey
//
//  Sheet mở từ `MacroView` khi user bấm "Xem & thêm" ở dòng "Gợi ý từ
//  Thống kê". Hiển thị các từ tiếng Việt user đã gõ ≥10 lần (cộng dồn
//  qua tuần) mà chưa có macro `to` tương ứng. User chọn / sửa `from`
//  (đã auto-suggest) rồi bấm "Thêm" → entry vào `Defaults[.macros]`.
//

import Defaults
import SwiftUI

struct MacroSuggestionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.macros) private var macros

  /// Suggestion 1 dòng — track state edit cục bộ.
  private struct Suggestion: Identifiable {
    let id: String          // word
    let word: String
    let count: Int
    var from: String        // auto-suggested, editable
    var added: Bool = false
  }

  @State private var suggestions: [Suggestion] = []

  var body: some View {
    VStack(spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        Text("Gợi ý macro từ Thống kê")
          .font(.headline)
        Text("Các từ và cụm từ bạn gõ ≥10 lần. Sửa cột \"Viết tắt\" nếu muốn rồi bấm \"Thêm\".")
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
        Text("Chưa có gợi ý — gõ nhiều hơn để vkey học thói quen của bạn.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding()
        Spacer()
      } else {
        Table($suggestions) {
          TableColumn("Từ") { $suggestion in
            Text(suggestion.word)
              .foregroundStyle(suggestion.added ? .secondary : .primary)
          }
          TableColumn("Số lần") { $suggestion in
            Text("\(suggestion.count)")
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          .width(60)
          TableColumn("Viết tắt") { $suggestion in
            TextField("viết tắt", text: $suggestion.from)
              .textFieldStyle(.roundedBorder)
              .disabled(suggestion.added)
          }
          TableColumn("") { $suggestion in
            Button(suggestion.added ? "Đã thêm" : "Thêm") {
              addMacro(suggestion)
            }
            .disabled(suggestion.added || suggestion.from.isEmpty)
          }
          .width(70)
        }
        .frame(minHeight: 240)
      }

      Divider()

      HStack {
        Button("Thêm tất cả") {
          addAllPending()
        }
        .disabled(suggestions.allSatisfy { $0.added || $0.from.isEmpty })

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
    // 1.6.1: kết hợp single-word + phrases (2-3 từ liền).
    let words = UsageStatistics.shared.aggregatedTopVietnameseWords(threshold: 10)
    let phrases = UsageStatistics.shared.aggregatedTopVietnamesePhrases(threshold: 10)
    // Phrases ưu tiên hiển thị trước (giá trị macro cao hơn — cụm dài
    // tiết kiệm nhiều keystroke hơn từ đơn).
    let aggregated = phrases + words
    let existingTo = Set(macros.map { $0.to.lowercased() })
    var existingFrom = Set(macros.map { $0.from.lowercased() })

    suggestions = aggregated.compactMap { wc in
      // Filter — bỏ từ user đã có macro `to == word`.
      guard !existingTo.contains(wc.word.lowercased()) else { return nil }
      // Auto-suggest `from` không trùng entry hiện có.
      let suggested = uniqueShortcut(for: wc.word, taken: &existingFrom)
      return Suggestion(id: wc.word, word: wc.word, count: wc.count, from: suggested)
    }
  }

  /// Sinh viết tắt từ word: lấy ký tự đầu mỗi token, diacritic strip,
  /// lowercase, tối đa 5 ký tự. Nếu trùng với `taken`, thêm số 1..99.
  private func uniqueShortcut(for word: String, taken: inout Set<String>) -> String {
    let tokens = word
      .lowercased()
      .folding(options: .diacriticInsensitive, locale: .current)
      .split(separator: " ")
    let prefix = tokens
      .compactMap { $0.first.map(String.init) }
      .joined()
    let base = String(prefix.prefix(5))
    if base.isEmpty {
      return ""
    }
    var candidate = base
    var suffix = 1
    while taken.contains(candidate) {
      candidate = "\(base)\(suffix)"
      suffix += 1
      if suffix > 99 { break }
    }
    taken.insert(candidate)
    return candidate
  }

  private func addMacro(_ suggestion: Suggestion) {
    guard let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
    let from = suggestions[idx].from.trimmingCharacters(in: .whitespaces)
    guard !from.isEmpty else { return }
    // Đảm bảo không trùng `from` với macro hiện có.
    if macros.contains(where: { $0.from == from }) {
      // Nếu trùng, append "_" để user nhận biết và sửa lại.
      return
    }
    macros.insert(Macro(from: from, to: suggestion.word), at: 0)
    suggestions[idx].added = true
  }

  private func addAllPending() {
    for s in suggestions where !s.added && !s.from.isEmpty {
      addMacro(s)
    }
  }
}
