//
//  PersonalDictMiner.swift
//  vkey
//
//  Pure mining logic that turns weekly word streaks into personal-dictionary
//  review suggestions, with length-bucketed Levenshtein anti-mash filtering.
//

import Foundation

enum PersonalDictMiner {

  struct PromotionResult: Equatable {
    let allow: [String]
    let keep: [String]
  }

  /// Pure promotion rule core (tested directly without global Defaults).
  static func computePromotion(
    enRestoreStreak: [String: Int],
    vnKeepStreak: [String: Int],
    existingAllow: Set<String>,
    existingKeep: Set<String>,
    existingDeny: Set<String>,
    threshold: Int = 5,
    maxBatch: Int = 10
  ) -> PromotionResult {
    var newAllow: [String] = []
    for (token, count) in enRestoreStreak where count >= threshold {
      let n = token.normalizedDictionaryToken
      guard n.count >= 2, n.isASCIIAlphabeticWord else { continue }
      if existingAllow.contains(n) || existingDeny.contains(n) { continue }
      newAllow.append(n)
    }

    var newKeep: [String] = []
    for (token, count) in vnKeepStreak where count >= threshold {
      let n = token.normalizedDictionaryToken
      guard n.count >= 2 else { continue }
      if existingKeep.contains(n) || existingDeny.contains(n) { continue }
      let hasNonAscii = n.unicodeScalars.contains { $0.value > 127 }
      guard hasNonAscii else { continue }
      newKeep.append(n)
    }

    return PromotionResult(
      allow: Array(newAllow.prefix(maxBatch)),
      keep: Array(newKeep.prefix(maxBatch))
    )
  }

  /// Compute pending suggestions for user review in `PersonalDictSuggestionSheet`.
  static func computePendingSuggestions(
    enRestoreStreak: [String: Int],
    vnKeepStreak: [String: Int],
    personal: LexiconManager.PersonalDictionary,
    lexicon: LexiconManager = .shared,
    threshold: Int = 5,
    now: Date = Date()
  ) -> [PendingDictSuggestion] {
    var out: [PendingDictSuggestion] = []
    let enWordsByLen = enWordsByLengthSnapshot(lexicon: lexicon)

    for (token, count) in enRestoreStreak where count >= threshold {
      let n = token.normalizedDictionaryToken
      guard n.count >= 2, n.isASCIIAlphabeticWord else { continue }
      if personal.allow.contains(n) || personal.deny.contains(n) { continue }
      if lexicon.isVietnameseWord(n) { continue }
      if lexicon.isEnglishWord(n) { continue }
      if looksLikeKeyboardMashing(n, enWordsByLen: enWordsByLen) { continue }
      out.append(PendingDictSuggestion(word: n, count: count, kind: .allow, suggestedAt: now))
    }

    for (token, count) in vnKeepStreak where count >= threshold {
      let n = token.normalizedDictionaryToken
      guard n.count >= 2 else { continue }
      if personal.keep.contains(n) || personal.deny.contains(n) { continue }
      let hasNonAscii = n.unicodeScalars.contains { $0.value > 127 }
      guard hasNonAscii else { continue }
      if lexicon.isVietnameseWord(n) { continue }
      out.append(PendingDictSuggestion(word: n, count: count, kind: .keep, suggestedAt: now))
    }

    return out
  }

  static func looksLikeKeyboardMashing(_ word: String, enWordsByLen: [Int: [String]]) -> Bool {
    if word.count > 18 { return true }
    let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
    guard word.lowercased().contains(where: { vowels.contains($0) }) else { return true }

    let maxDist = max(2, word.count / 4)
    let lo = word.count - maxDist
    let hi = word.count + maxDist
    for len in max(1, lo)...hi {
      guard let candidates = enWordsByLen[len] else { continue }
      for c in candidates {
        if SuggestionService.levenshtein(word, c) <= maxDist { return false }
      }
    }
    return true
  }

  private static func enWordsByLengthSnapshot(lexicon: LexiconManager) -> [Int: [String]] {
    let all = lexicon.englishWordsSnapshot()
    var buckets: [Int: [String]] = [:]
    for w in all { buckets[w.count, default: []].append(w) }
    return buckets
  }
}
