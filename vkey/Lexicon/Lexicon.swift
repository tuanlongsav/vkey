//
//  Lexicon.swift
//  vkey
//
//  Spell-check / lexicon core types. Extracted from InputProcessor.swift in
//  1.5.0 as part of the Phase 3 split — InputProcessor was 8.5k lines and
//  was bundling type definitions, data tables, managers and event-pipeline
//  glue. Moving these declarations here lets the lexicon module evolve
//  (e.g. the new EnVnReference, schema v5) without dragging the event loop
//  along with it.
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

// MARK: - Protocol & in-memory implementation

protocol Lexicon {
  var version: Int { get }
  var source: LexiconSource { get }
  func contains(_ word: String) -> Bool
}

struct InMemoryLexicon: Lexicon {
  let version: Int
  let source: LexiconSource
  let words: Set<String>

  func contains(_ word: String) -> Bool {
    words.contains(word.normalizedDictionaryToken)
  }
}

// MARK: - Spell decision types

/// A spelling suggestion with a confidence score in [0, 1].
struct SuggestionCandidate: Equatable {
  let word: String
  let score: Double
}

/// The decision the spell engine returns after evaluating a committed word.
enum SpellDecision: Equatable {
  case keepVietnamese
  case restoreRawEnglish(String)
  case keepRaw
  case suggest([SuggestionCandidate])
}

// MARK: - String helpers used by lexicon code

/// `internal` (default) so it's visible to LexiconManager, SpellDecisionEngine,
/// SuggestionService and any future module in the lexicon group. It was
/// previously `private` to InputProcessor.swift, which is why so much
/// dictionary code lived in that single file.
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
      locale: Locale(identifier: "vi_VN")
    )
  }

  /// True if the string consists solely of ASCII letters (a–z, A–Z).
  /// Used to gate English restoration: only restore if the raw input is
  /// pure ASCII, otherwise we'd "restore" away genuine Vietnamese diacritics.
  var isASCIIAlphabeticWord: Bool {
    guard !isEmpty else { return false }
    return unicodeScalars.allSatisfy {
      let value = $0.value
      return (value >= 65 && value <= 90) || (value >= 97 && value <= 122)
    }
  }
}
