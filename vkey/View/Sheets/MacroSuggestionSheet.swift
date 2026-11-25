//
//  MacroSuggestionSheet.swift
//  vkey
//
//  Sheet gợi ý macro từ các từ/cụm tiếng Việt gõ ≥10 lần trong Thống kê.
//

import Defaults
import SwiftUI

struct MacroSuggestionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.macros) private var macros

  private struct Suggestion: Identifiable {
    let id: String
    let word: String
    let count: Int
    var from: String
    var added: Bool = false
  }

  @State private var suggestions: [Suggestion] = []

  var body: some View {
    VKSheetScaffold(
      title: "Gợi ý macro từ Thống kê",
      subtitle: "Các từ và cụm từ bạn gõ ≥10 lần. Sửa cột \"Viết tắt\" nếu muốn rồi bấm \"Thêm\".",
      width: 520,
      height: 460
    ) {
      if suggestions.isEmpty {
        VKEmptyState(
          systemImage: "text.badge.plus",
          title: "Chưa có gợi ý",
          message: "Gõ nhiều hơn để vkey học thói quen của bạn."
        )
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
      }
    } footer: {
      Button("Thêm tất cả", action: addAllPending)
        .disabled(suggestions.allSatisfy { $0.added || $0.from.isEmpty })

      Spacer()

      Button("Đóng") { dismiss() }
        .keyboardShortcut(.defaultAction)
    }
    .onAppear(perform: load)
  }

  private func load() {
    let words = UsageStatistics.shared.aggregatedTopVietnameseWords(threshold: 10)
    let phrases = UsageStatistics.shared.aggregatedTopVietnamesePhrases(threshold: 10)
    let aggregated = phrases + words
    let existingTo = Set(macros.map { $0.to.lowercased() })
    var existingFrom = Set(macros.map { $0.from.lowercased() })

    suggestions = aggregated.compactMap { wc in
      guard !existingTo.contains(wc.word.lowercased()) else { return nil }
      let suggested = uniqueShortcut(for: wc.word, taken: &existingFrom)
      return Suggestion(id: wc.word, word: wc.word, count: wc.count, from: suggested)
    }
  }

  private func uniqueShortcut(for word: String, taken: inout Set<String>) -> String {
    let tokens = word
      .lowercased()
      .folding(options: .diacriticInsensitive, locale: .current)
      .split(separator: " ")
    let prefix = tokens
      .compactMap { $0.first.map(String.init) }
      .joined()
    let base = String(prefix.prefix(5))
    guard !base.isEmpty else { return "" }
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
    guard !from.isEmpty, !macros.contains(where: { $0.from == from }) else { return }
    macros.insert(Macro(from: from, to: suggestion.word), at: 0)
    suggestions[idx].added = true
  }

  private func addAllPending() {
    for s in suggestions where !s.added && !s.from.isEmpty {
      addMacro(s)
    }
  }
}
