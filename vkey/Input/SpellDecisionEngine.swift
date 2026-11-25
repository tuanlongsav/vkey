//
//  SpellDecisionEngine.swift
//  vkey
//
//  Decides whether a committed word should stay Vietnamese, be restored
//  to the raw English keys, or surface suggestions.
//

import Defaults
import Foundation

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

/// Pure configuration snapshot for `SpellDecisionEngine.evaluate(...)`.
struct SpellDecisionConfig: Equatable, Sendable {
  var spellCheckEnabled: Bool = true
  var englishAutoRestoreEnabled: Bool = true
  var restorePolicy: RestorePolicy = .balanced
  var useEnVnReference: Bool = true
  var suggestionEnabled: Bool = true

  static var currentFromDefaults: SpellDecisionConfig {
    SpellDecisionConfig(
      spellCheckEnabled: Defaults[.spellCheckEnabled],
      englishAutoRestoreEnabled: Defaults[.englishAutoRestoreEnabled],
      restorePolicy: Defaults[.restorePolicy],
      useEnVnReference: Defaults[.useEnVnReference],
      suggestionEnabled: Defaults[.suggestionEnabled]
    )
  }
}

// MARK: - Engine

final class SpellDecisionEngine {
  static let shared = SpellDecisionEngine()

  private let lexiconManager: LexiconManager
  private let suggestionService: SuggestionService
  private let enVnReference: EnVnReference

  private static let doubledTones = ["ss", "ff", "rr", "xx", "jj"]

  private let extremelyCommonVietnameseWords: Set<String> = [
    "mẹ", "ăn", "đi", "cho", "tôi", "anh", "em", "gì", "là", "và", "có", "không", "ở", "này",
    "của", "đã", "được", "trong", "người", "với", "một", "để", "những", "khi", "đến", "về",
    "tại", "cũng", "ra", "năm", "nhiều", "từ", "việc", "đồng", "nhà", "làm", "đó", "hiện",
    "ông", "vào", "học", "bị", "trên", "thể", "theo", "trường",
  ]

  private static let vnDiacriticChars: Set<Character> = Set(
    "àáảãạăắằẳẵặâấầẩẫậ" +
    "èéẻẽẹêếềểễệ" +
    "ìíỉĩị" +
    "òóỏõọôốồổỗộơớờởỡợ" +
    "ùúủũụưứừửữự" +
    "ỳýỷỹỵđ"
  )

  static func hasVietnameseDiacritic(_ word: String) -> Bool {
    word.lowercased().contains { vnDiacriticChars.contains($0) }
  }

  /// Detect Telex mũ cancellation pattern (3 identical vowels collapsed to 2, e.g. `foooter` → `footer`).
  static func isLikelyTelexCancellation(rawInput: String, transformed: String) -> Bool {
    let raw = rawInput.lowercased()
    let trans = transformed.lowercased()
    for triple in ["ooo", "aaa", "eee", "uuu", "iii"] where raw.contains(triple) {
      let doubled = String(triple.prefix(2))
      if raw.replacingOccurrences(of: triple, with: doubled) == trans {
        return true
      }
    }
    return false
  }

  /// Màn hình là chữ Latin trơn và chỉ thiếu so với phím thô đúng các phím lặp huỷ dấu (`a/e/o/w/d`).
  static func isTelexCancelResidue(rawInput: String, transformed: String) -> Bool {
    guard transformed.isASCIIAlphabeticWord else { return false }
    let raw = Array(rawInput.lowercased())
    let shown = Array(transformed.lowercased())
    guard raw.count > shown.count else { return false }
    let repeatMarkKeys: Set<Character> = ["a", "e", "o", "w", "d"]
    var matched = 0
    for (i, key) in raw.enumerated() {
      if matched < shown.count, key == shown[matched] {
        matched += 1
        continue
      }
      let repeatsNeighbour = (i > 0 && raw[i - 1] == key)
        || (i + 1 < raw.count && raw[i + 1] == key)
      guard repeatMarkKeys.contains(key), repeatsNeighbour else { return false }
    }
    return matched == shown.count
  }

  /// Detect short ALL-CAPS English initialism (e.g. ARM, USA, API, OK).
  static func isLikelyEnglishAcronym(_ raw: String) -> Bool {
    let chars = Array(raw)
    guard chars.count >= 2, chars.count <= 5 else { return false }
    guard chars.allSatisfy({ $0.isASCII && $0.isUppercase && $0.isLetter }) else {
      return false
    }
    let lower = raw.lowercased()
    let vnDoublePatterns = [
      "dd", "aa", "oo", "ee", "uu", "ww", "uw", "ow", "aw",
      "rr", "ss", "ff", "xx", "jj",
    ]
    if vnDoublePatterns.contains(where: { lower.contains($0) }) {
      return false
    }
    if let last = lower.last, TiengViet.TelexToneKeys[last] != nil {
      return false
    }
    return true
  }

  init(
    lexiconManager: LexiconManager = .shared,
    suggestionService: SuggestionService = .shared,
    enVnReference: EnVnReference = .shared
  ) {
    self.lexiconManager = lexiconManager
    self.suggestionService = suggestionService
    self.enVnReference = enVnReference
  }

  private func isKnownEnglish(_ word: String, config: SpellDecisionConfig) -> Bool {
    if lexiconManager.isEnglishWord(word) { return true }
    return config.useEnVnReference && enVnReference.lookupEnglish(word) != nil
  }

  func evaluate(
    rawInput: String,
    transformed: String,
    needsRecovery: Bool,
    config: SpellDecisionConfig? = nil
  ) -> SpellDecision {
    let cfg = config ?? .currentFromDefaults
    guard cfg.spellCheckEnabled else { return .keepVietnamese }
    guard !rawInput.isEmpty, !transformed.isEmpty else { return .keepVietnamese }

    let rawToken = rawInput.normalizedDictionaryToken
    let transformedToken = transformed.normalizedDictionaryToken
    guard !rawToken.isEmpty, !transformedToken.isEmpty else { return .keepRaw }

    // Short ALL-CAPS English acronym (ARM, USA, API); preserve valid ALL-CAPS VN words (TOÁN, HỌC).
    if cfg.englishAutoRestoreEnabled, Self.isLikelyEnglishAcronym(rawInput) {
      if isKnownEnglish(rawInput, config: cfg) || !lexiconManager.isVietnameseWord(transformed) {
        return .restoreRawEnglish(rawInput)
      }
    }

    // Consecutive doubled tone marks (ss/ff/rr/xx/jj) → keep raw.
    if Self.doubledTones.contains(where: { rawToken.contains($0) }) {
      return .keepRaw
    }

    // Cancel residue from doubled repeat-mark keys (aa/oo/ee/ww/ddd), unless raw is a known EN word.
    if Self.isTelexCancelResidue(rawInput: rawInput, transformed: transformed),
       !isKnownEnglish(rawInput, config: cfg) {
      return .keepRaw
    }

    if lexiconManager.shouldApplyLegacyRestore(transformed: transformed, rawInput: rawInput),
       cfg.englishAutoRestoreEnabled
    {
      return .restoreRawEnglish(rawInput)
    }

    if lexiconManager.shouldKeepVietnamese(transformed) {
      return .keepVietnamese
    }

    let isVietnameseWord = lexiconManager.isVietnameseWord(transformed)
    let rawIsEnglish = isKnownEnglish(rawInput, config: cfg)

    if cfg.englishAutoRestoreEnabled {
      if Self.hasVietnameseDiacritic(transformedToken),
         !isVietnameseWord, !rawIsEnglish {
        return .keepVietnamese
      }

      if !isVietnameseWord {
        if lexiconManager.isEnglishWord(transformed) {
          return .keepRaw
        }
        if Self.isLikelyTelexCancellation(rawInput: rawInput, transformed: transformed) {
          return .keepRaw
        }
        if rawToken.isASCIIAlphabeticWord, rawToken != transformedToken {
          return .restoreRawEnglish(rawInput)
        }
        if needsRecovery && rawIsEnglish {
          return .restoreRawEnglish(rawInput)
        }
      } else if rawIsEnglish {
        switch cfg.restorePolicy {
        case .englishFirst:
          return .restoreRawEnglish(rawInput)
        case .balanced:
          if Self.hasVietnameseDiacritic(transformedToken) {
            return .keepVietnamese
          }
          return extremelyCommonVietnameseWords.contains(transformedToken)
            ? .keepVietnamese
            : .restoreRawEnglish(rawInput)
        case .vietnameseFirst:
          return .keepVietnamese
        }
      }
    }

    if needsRecovery {
      if isVietnameseWord {
        return .keepVietnamese
      }
      guard cfg.suggestionEnabled else { return .keepRaw }
      let suggestions = suggestionService.suggest(word: transformed, locale: "vi_VN", limit: 5)
      return suggestions.isEmpty ? .keepRaw : .suggest(suggestions)
    }

    return .keepVietnamese
  }
}
