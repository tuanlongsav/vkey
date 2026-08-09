//
//  TopWordsDetail.swift
//  vkey
//
//  Sheet "Xem chi tiết" cho danh sách top từ trong tab Thống kê, tách ra khi
//  StatisticsView (tab Thống kê đời cũ) bị VKStatsTab thay thế. Chỉ còn hai
//  kiểu này sống sót từ file StatisticsView.swift cũ.
//

import AppKit
import Defaults
import SwiftUI


/// 1.7.4: identifier cho sheet "Xem chi tiết" của top từ — VN hoặc EN.
/// 1.8.4: thêm `.vietnamesePhrases` cho cụm 2-3 từ tiếng Việt.
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


/// + nút Đóng.
struct TopWordsDetailSheet: View {
  let category: TopWordsDetailCategory
  let words: [WordCount]
  let onDelete: (String) -> Void
  let onDismiss: () -> Void

  @State private var localWords: [WordCount] = []

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(category.title)
          .font(.headline)
        Spacer()
        Text("\(localWords.count) từ")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      Divider()

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
              ThemedSymbol(name: "trash")
                .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Xoá khỏi thống kê tuần này")
          }
        }
      }
      .listStyle(.inset)

      Divider()

      HStack {
        Spacer()
        Button("Đóng", action: onDismiss)
          .keyboardShortcut(.cancelAction)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
    .frame(width: 420, height: 520)
    .onAppear {
      localWords = words
    }
  }
}
