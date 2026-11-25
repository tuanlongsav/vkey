//
//  TopWordsDetailSheet.swift
//  vkey
//
//  Sheet "Xem chi tiết" cho danh sách top từ / cụm từ trong tab Thống kê.
//

import SwiftUI

enum TopWordsDetailCategory: Identifiable {
  case vietnamese
  case english
  case vietnamesePhrases
  case englishPhrases

  var id: Self { self }

  var title: String {
    switch self {
    case .vietnamese:        return "Top từ tiếng Việt"
    case .english:           return "Top từ tiếng Anh / ký tự đặc biệt"
    case .vietnamesePhrases: return "Top cụm 2-3 từ tiếng Việt"
    case .englishPhrases:    return "Top cụm ngoài tiếng Việt"
    }
  }

  var statCategory: UsageStatistics.StatCategory {
    switch self {
    case .vietnamese:        return .vietnamese
    case .english:           return .english
    case .vietnamesePhrases: return .vietnamesePhrase
    case .englishPhrases:    return .englishPhrase
    }
  }
}

struct TopWordsDetailSheet: View {
  let category: TopWordsDetailCategory
  let words: [WordCount]
  let onDelete: (String) -> Void
  let onDismiss: () -> Void

  @State private var localWords: [WordCount] = []

  var body: some View {
    VKSheetScaffold(
      title: category.title,
      width: 420,
      height: 520,
      headerExtra: {
        Text("\(localWords.count) từ")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    ) {
      List {
        ForEach(localWords, id: \.word) { wc in
          HStack {
            Text(wc.word)
            Spacer()
            Text("×\(wc.count)")
              .foregroundStyle(.secondary)
              .monospacedDigit()
            Button {
              onDelete(wc.word)
              localWords.removeAll { $0.word == wc.word }
            } label: {
              Image(systemName: "trash")
                .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Xoá khỏi thống kê tuần này")
          }
        }
      }
      .listStyle(.inset)
    } footer: {
      Spacer()
      Button("Đóng", action: onDismiss)
        .keyboardShortcut(.cancelAction)
    }
    .onAppear {
      localWords = words
    }
  }
}
