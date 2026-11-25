//
//  Lexicon.swift
//  vkey
//
//  Lexicon core types and Vietnamese/dictionary string normalization helpers.
//

import Foundation

// MARK: - Sources

/// Where a given lexicon's words came from. Influences ordering and conflict
/// resolution: `embedded` < `updatePackage` < `user`.
enum LexiconSource: String {
  case embedded
  case updatePackage
  case user
}

// MARK: - In-memory lexicon

struct InMemoryLexicon {
  let version: Int
  let source: LexiconSource
  let words: Set<String>

  func contains(_ word: String) -> Bool {
    words.contains(word.normalizedDictionaryToken)
  }
}

// MARK: - String helpers used by lexicon code

/// Dựng `Locale` không rẻ, mà `vietnameseFolded` chạy cho từng từ trong từ điển
/// mỗi lần gợi ý chính tả — dùng chung một instance.
private let vietnameseFoldingLocale = Locale(identifier: "vi_VN")

extension String {
  /// Trim whitespace and lowercase for dictionary lookups.
  var normalizedDictionaryToken: String {
    trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  /// Diacritic- and case-insensitive form used for fuzzy Vietnamese matching.
  var vietnameseFolded: String {
    let prepared = replacingOccurrences(of: "đ", with: "d")
      .replacingOccurrences(of: "Đ", with: "d")
    return prepared.folding(
      options: [.diacriticInsensitive, .caseInsensitive],
      locale: vietnameseFoldingLocale
    )
  }

  /// True if the string consists solely of ASCII letters (a–z, A–Z).
  var isASCIIAlphabeticWord: Bool {
    guard !isEmpty else { return false }
    return unicodeScalars.allSatisfy {
      let value = $0.value
      return (value >= 65 && value <= 90) || (value >= 97 && value <= 122)
    }
  }
}
