//
//  SpellDecisionEngine.swift
//  vkey
//
//  Decides whether a committed word should stay Vietnamese, be restored
//  to the raw English keys, or surface suggestions. Extracted from
//  InputProcessor.swift in 1.5.0 to keep the input pipeline composable.
//

import Defaults
import Foundation

final class SpellDecisionEngine {
  static let shared = SpellDecisionEngine()

  private let lexiconManager: LexiconManager
  private let suggestionService: SuggestionService

  private let extremelyCommonVietnameseWords: Set<String> = [
    "mẹ", "ăn", "đi", "cho", "tôi", "anh", "em", "gì", "là", "và", "có", "không", "ở", "này", 
    "của", "đã", "được", "trong", "người", "với", "một", "để", "những", "khi", "đến", "về", 
    "tại", "cũng", "ra", "năm", "nhiều", "từ", "việc", "đồng", "nhà", "làm", "đó", "hiện", 
    "ông", "vào", "học", "bị", "trên", "thể", "theo", "trường"
  ]

  init(
    lexiconManager: LexiconManager = .shared,
    suggestionService: SuggestionService = .shared
  ) {
    self.lexiconManager = lexiconManager
    self.suggestionService = suggestionService
  }

  func evaluate(rawInput: String, transformed: String, needsRecovery: Bool) -> SpellDecision {
    guard Defaults[.spellCheckEnabled] else { return .keepVietnamese }
    guard !rawInput.isEmpty, !transformed.isEmpty else { return .keepVietnamese }

    let rawToken = rawInput.normalizedDictionaryToken
    let transformedToken = transformed.normalizedDictionaryToken
    guard !rawToken.isEmpty, !transformedToken.isEmpty else { return .keepRaw }

    // Doubled Tone Mark Preservation: if raw input contains consecutive doubled tone marks, keep it raw
    let doubledTones = ["ss", "ff", "rr", "xx", "jj"]
    if doubledTones.contains(where: { rawToken.contains($0) }) {
      return .keepRaw
    }

    if lexiconManager.shouldApplyLegacyRestore(transformed: transformed, rawInput: rawInput),
      Defaults[.englishAutoRestoreEnabled]
    {
      return .restoreRawEnglish(rawInput)
    }

    if lexiconManager.shouldKeepVietnamese(transformed) {
      return .keepVietnamese
    }

    let isVietnameseWord = lexiconManager.isVietnameseWord(transformed)
    var rawIsEnglish = lexiconManager.isEnglishWord(rawInput)

    // 1.5.0: the `en_vn_mapping` widens our notion of "English" — if the raw
    // token is a key in the bilingual reference, treat it as English even if
    // it wasn't in the embedded EN list. This catches all the words shipped
    // by Phase 4 (and by future Wiktionary-derived data drops) without
    // bloating the `english[]` array specifically for restore.
    if !rawIsEnglish, Defaults[.useEnVnReference],
       EnVnReference.shared.lookupEnglish(rawInput) != nil {
      rawIsEnglish = true
    }

    if Defaults[.englishAutoRestoreEnabled] {
      // 1. If transformed output is NOT a valid Vietnamese word
      if !isVietnameseWord {
        if rawToken.isASCIIAlphabeticWord, rawToken != transformedToken {
          return .restoreRawEnglish(rawInput)
        }
        if needsRecovery && rawIsEnglish {
          return .restoreRawEnglish(rawInput)
        }
      } 
      // 2. If transformed output IS a valid Vietnamese word (checking policies for ambiguous words)
      else {
        if rawIsEnglish {
          let policy = Defaults[.restorePolicy]
          switch policy {
          case .englishFirst:
            return .restoreRawEnglish(rawInput)
          case .balanced:
            if extremelyCommonVietnameseWords.contains(transformedToken) {
              return .keepVietnamese
            } else {
              return .restoreRawEnglish(rawInput)
            }
          case .vietnameseFirst:
            return .keepVietnamese
          }
        }
      }
    }

    if needsRecovery {
      if isVietnameseWord {
        return .keepVietnamese
      }
      guard Defaults[.suggestionEnabled] else { return .keepRaw }
      let suggestions = suggestionService.suggest(word: transformed, locale: "vi_VN", limit: 5)
      return suggestions.isEmpty ? .keepRaw : .suggest(suggestions)
    }

    return .keepVietnamese
  }
}
