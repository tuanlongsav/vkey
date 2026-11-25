//
//  PhraseTracker.swift
//  vkey
//
//  Sliding-window tracker for consecutive Vietnamese (2–4 gram) and
//  English/raw (2–3 gram) phrases, plus aggregation and deletion helpers.
//

import Foundation

struct PhraseTracker {
  enum Kind { case vietnamese, english }

  private var recentVnQueue: [String] = []
  private var recentEnQueue: [String] = []

  mutating func resetAll() {
    recentVnQueue.removeAll()
    recentEnQueue.removeAll()
  }

  mutating func resetVietnamese() {
    recentVnQueue.removeAll()
  }

  mutating func resetEnglish() {
    recentEnQueue.removeAll()
  }

  mutating func recordVietnamese(token: String, into bucket: inout WeekBucket) {
    recentVnQueue.append(token)
    if recentVnQueue.count > 4 {
      recentVnQueue.removeFirst(recentVnQueue.count - 4)
    }
    if recentVnQueue.count >= 2 {
      let words2 = Array(recentVnQueue.suffix(2))
      if Self.isMeaningfulVietnamesePhrase(words2) {
        bucket.vnPhraseCounts2[words2.joined(separator: " "), default: 0] += 1
      }
    }
    if recentVnQueue.count >= 3 {
      let words3 = Array(recentVnQueue.suffix(3))
      if Self.isMeaningfulVietnamesePhrase(words3) {
        bucket.vnPhraseCounts3[words3.joined(separator: " "), default: 0] += 1
      }
    }
    if recentVnQueue.count >= 4 {
      let words4 = Array(recentVnQueue.suffix(4))
      if Self.isMeaningfulVietnamesePhrase(words4) {
        bucket.vnPhraseCounts4[words4.joined(separator: " "), default: 0] += 1
      }
    }
  }

  mutating func recordEnglish(token: String, into bucket: inout WeekBucket) {
    recentEnQueue.append(token)
    if recentEnQueue.count > 3 {
      recentEnQueue.removeFirst(recentEnQueue.count - 3)
    }
    if recentEnQueue.count >= 2 {
      let phrase2 = recentEnQueue.suffix(2).joined(separator: " ")
      bucket.enPhraseCounts2[phrase2, default: 0] += 1
    }
    if recentEnQueue.count >= 3 {
      let phrase3 = recentEnQueue.suffix(3).joined(separator: " ")
      bucket.enPhraseCounts3[phrase3, default: 0] += 1
    }
  }

  /// Cụm tiếng Việt có nghĩa: mọi token ≥ 2 ký tự và nằm trong từ điển VN (hoặc personal keep/allow).
  static func isMeaningfulVietnamesePhrase(_ words: [String]) -> Bool {
    guard words.count >= 2 else { return false }
    let personal = LexiconManager.shared.personalDictionary()
    for word in words {
      let lower = word.lowercased()
      guard lower.count >= 2 else { return false }
      if personal.keep.contains(lower) || personal.allow.contains(lower) { continue }
      if !LexiconManager.shared.isVietnameseWord(lower) { return false }
    }
    return true
  }

  static func aggregatedVietnamesePhrases(
    from bucket: WeekBucket,
    minWords: Int,
    maxWords: Int,
    threshold: Int
  ) -> [WordCount] {
    var out: [String: Int] = [:]
    if minWords <= 2 && maxWords >= 2 {
      for (phrase, count) in bucket.vnPhraseCounts2 where count >= threshold { out[phrase] = count }
    }
    if minWords <= 3 && maxWords >= 3 {
      for (phrase, count) in bucket.vnPhraseCounts3 where count >= threshold { out[phrase] = count }
    }
    if minWords <= 4 && maxWords >= 4 {
      for (phrase, count) in bucket.vnPhraseCounts4 where count >= threshold { out[phrase] = count }
    }
    return out
      .map { WordCount(word: $0.key, count: $0.value) }
      .sorted { $0.count > $1.count }
  }

  static func aggregatedEnglishPhrases(
    from bucket: WeekBucket,
    minWords: Int,
    maxWords: Int,
    threshold: Int
  ) -> [WordCount] {
    var out: [String: Int] = [:]
    if minWords <= 2 && maxWords >= 2 {
      for (phrase, count) in bucket.enPhraseCounts2 where count >= threshold { out[phrase] = count }
    }
    if minWords <= 3 && maxWords >= 3 {
      for (phrase, count) in bucket.enPhraseCounts3 where count >= threshold { out[phrase] = count }
    }
    return out
      .map { WordCount(word: $0.key, count: $0.value) }
      .sorted { $0.count > $1.count }
  }

  static func removePhrase(_ phrase: String, kind: Kind, from bucket: inout WeekBucket) {
    let key = phrase
      .split(separator: " ", omittingEmptySubsequences: true)
      .joined(separator: " ")
    guard !key.isEmpty else { return }
    switch kind {
    case .vietnamese:
      bucket.vnPhraseCounts2.removeValue(forKey: key)
      bucket.vnPhraseCounts3.removeValue(forKey: key)
      bucket.vnPhraseCounts4.removeValue(forKey: key)
    case .english:
      bucket.enPhraseCounts2.removeValue(forKey: key)
      bucket.enPhraseCounts3.removeValue(forKey: key)
    }
  }
}
