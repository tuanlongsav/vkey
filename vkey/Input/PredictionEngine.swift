//
//  PredictionEngine.swift
//  vkey
//
//  Word prediction engine (1.6.0+). Đoán từ/cụm tiếp theo dựa trên:
//
//  - Layer 1: Trigram user (prev2, prev1 → ?)
//  - Layer 2: Bigram user (prev1 → ?)
//  - Layer 3: Bigram embedded VN corpus
//  - Layer 4: Embedded phrase completions (1 từ)
//  - Layer 5: User phrase stats (suffix 1–3 từ từ UsageStatistics)
//  - Layer 6: Embedded multi-word suffixes (2–3 từ)
//
//  Học passively từ `InputProcessor.applySpellDecisionOnCommit`.
//

import Defaults
import Foundation

final class PredictionEngine {
  static let shared = PredictionEngine()

  private let userBigramThreshold = 2
  private let userTrigramThreshold = 2

  /// Gợi ý tốt nhất — 1 đến `predictionMaxWords` từ (mặc định 2).
  func topPhrasePrediction(prev2: String?, prev1: String, maxWords: Int? = nil) -> String? {
    let maxW = Self.clampedMaxWords(maxWords ?? Defaults[.predictionMaxWords])
    let p1 = prev1.lowercased()
    guard !p1.isEmpty else { return nil }

    let keepSet = Set(Defaults[.userKeepWords].map { $0.lowercased() })
    let allowSet = Set(Defaults[.userAllowWords].map { $0.lowercased() })

    var scored: [(phrase: String, score: Int)] = []

    if maxW >= 1 {
      for candidate in collectSingleWordCandidates(prev2: prev2, prev1: p1) {
        if let score = scorePhrase(
          candidate.word, freq: candidate.freq, wordCount: 1,
          prev1: p1, allowSet: allowSet, keepSet: keepSet
        ) {
          scored.append((candidate.word, score))
        }
      }
    }

    if maxW >= 2 {
      for (suffix, count) in UsageStatistics.shared.phraseSuffixHints(
        prev2: prev2, prev1: p1, maxWords: maxW
      ) where suffix.split(separator: " ").count >= 2 {
        if let score = scorePhrase(
          suffix, freq: count, wordCount: suffix.split(separator: " ").count,
          prev1: p1, allowSet: allowSet, keepSet: keepSet
        ) {
          scored.append((suffix, score))
        }
      }

      let contextKey = Self.phraseContextKey(prev2: prev2, prev1: p1)
      if let embedded = EmbeddedPhraseCompletions.multiWordSuffixes[contextKey] {
        for (suffix, weight) in embedded {
          let wc = suffix.split(separator: " ").count
          guard wc >= 2, wc <= maxW else { continue }
          if let score = scorePhrase(
            suffix, freq: weight * 2, wordCount: wc,
            prev1: p1, allowSet: allowSet, keepSet: keepSet
          ) {
            scored.append((suffix, score))
          }
        }
      }
    }

    if maxW >= 3 {
      for (suffix, count) in UsageStatistics.shared.phraseSuffixHints(
        prev2: prev2, prev1: p1, maxWords: 3
      ) where suffix.split(separator: " ").count == 3 {
        if let score = scorePhrase(
          suffix, freq: count, wordCount: 3,
          prev1: p1, allowSet: allowSet, keepSet: keepSet
        ) {
          scored.append((suffix, score))
        }
      }
    }

    scored.sort { lhs, rhs in
      if lhs.score != rhs.score { return lhs.score > rhs.score }
      return lhs.phrase.split(separator: " ").count > rhs.phrase.split(separator: " ").count
    }
    return scored.first?.phrase
  }

  /// Backward-compat: một từ đơn.
  func topPrediction(prev2: String?, prev1: String) -> String? {
    topPhrasePrediction(prev2: prev2, prev1: prev1, maxWords: 1)
  }

  func topNPredictions(prev2: String?, prev1: String, n: Int) -> [String] {
    let p1 = prev1.lowercased()
    guard !p1.isEmpty, n > 0 else { return [] }
    let allowSet = Set(Defaults[.userAllowWords].map { $0.lowercased() })
    let keepSet = Set(Defaults[.userKeepWords].map { $0.lowercased() })
    var scored: [(word: String, score: Int)] = []
    for candidate in collectSingleWordCandidates(prev2: prev2, prev1: p1) {
      if let score = scorePhrase(
        candidate.word, freq: candidate.freq, wordCount: 1,
        prev1: p1, allowSet: allowSet, keepSet: keepSet
      ) {
        scored.append((candidate.word, score))
      }
    }
    scored.sort { $0.score > $1.score }
    return Array(scored.prefix(n).map { $0.word })
  }

  func collectCandidates(prev2: String?, prev1: String) -> [(word: String, freq: Int)] {
    collectSingleWordCandidates(prev2: prev2, prev1: prev1)
  }

  private func collectSingleWordCandidates(
    prev2: String?, prev1: String
  ) -> [(word: String, freq: Int)] {
    var out: [String: Int] = [:]

    if let prev2 = prev2 {
      let nexts = NGramStore.shared.trigramNexts(prev2: prev2.lowercased(), prev1: prev1)
      for (w, c) in nexts where c >= userTrigramThreshold {
        out[w, default: 0] += c * 6
      }
    }

    let bigramNexts = NGramStore.shared.bigramNexts(prev1: prev1)
    for (w, c) in bigramNexts where c >= userBigramThreshold {
      out[w, default: 0] += c * 3
    }

    if let nexts = EmbeddedBigrams.commonPairs[prev1] {
      for (next, weight) in nexts {
        out[next, default: 0] += weight
      }
    }

    if let prev2 = prev2 {
      let phraseKey = "\(prev2.lowercased()) \(prev1)"
      if let nexts = EmbeddedPhraseCompletions.completions[phraseKey] {
        for (next, weight) in nexts {
          out[next, default: 0] += weight * 2
        }
      }
      if let nexts = EmbeddedBigrams.commonPairs[phraseKey] {
        for (next, weight) in nexts {
          out[next, default: 0] += weight * 2
        }
      }

      let suffixHints = UsageStatistics.shared.phraseSuffixHints(
        prev2: prev2.lowercased(),
        prev1: prev1,
        maxWords: 1
      )
      for (word, count) in suffixHints where count >= 2 {
        out[word, default: 0] += count * 4
      }
    }

    return out.map { (word: $0.key, freq: $0.value) }
  }

  private func scorePhrase(
    _ phrase: String,
    freq: Int,
    wordCount: Int,
    prev1: String,
    allowSet: Set<String>,
    keepSet: Set<String>
  ) -> Int? {
    let words = phrase.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard !words.isEmpty else { return nil }
    if words.count == 1, words[0].lowercased() == prev1.lowercased() { return nil }
    for word in words {
      if !Self.isValidCandidate(word, allowedSet: allowSet) { return nil }
    }
    if words.count >= 2, !UsageStatistics.isMeaningfulVietnamesePhrase(words) { return nil }

    var score = freq * (1 + wordCount)
    var hasDictWord = false
    for word in words {
      if LexiconManager.shared.isVietnameseWord(word) {
        score += 1000
        hasDictWord = true
      }
      let lower = word.lowercased()
      if keepSet.contains(lower) || allowSet.contains(lower) {
        score += 500
      }
    }
    let minFreq = wordCount == 1 ? 5 : max(3, 4 - wordCount)
    guard hasDictWord || freq >= minFreq else { return nil }
    return score
  }

  static func phraseContextKey(prev2: String?, prev1: String) -> String {
    let p1 = prev1.lowercased()
    if let p2 = prev2?.lowercased(), !p2.isEmpty {
      return "\(p2) \(p1)"
    }
    return p1
  }

  static func clampedMaxWords(_ value: Int) -> Int {
    max(1, min(3, value))
  }

  static func isValidCandidate(_ word: String, allowedSet: Set<String>) -> Bool {
    let lower = word.lowercased()
    if allowedSet.contains(lower) {
      return true
    }
    if lower.contains(where: { !$0.isLetter }) {
      return false
    }
    if lower.count == 1 {
      let validSingleLetters = Set(
        "aàáảãạăằắẳẵặâầấẩẫậeèéẻẽẹêềếểễệiìíỉĩịoòóỏõọôồốổỗộơờớởỡợuùúủũụưừứửữựyỳýỷỹỵđ")
      if let char = lower.first, !validSingleLetters.contains(char) {
        return false
      }
    }
    return true
  }

  /// Học từ commit hoặc khi user chấp nhận gợi ý nhiều từ.
  func learnTransition(prev2: String?, prev1: String?, current: String) {
    // Privacy: tôn trọng công tắc Thống kê (giống `UsageStatistics.recordCommit`).
    // Tắt Thống kê ⇒ KHÔNG ghi nội dung n-gram từ chữ đã gõ. Thêm guard
    // secure-input phòng race khi vừa thoát ô mật khẩu (EventHook đã bypass
    // trong lúc secure input, đây là defense-in-depth cho cửa sổ thoát).
    guard Defaults[.statisticsEnabled] else { return }
    guard !UsageStatistics.isSecureInputActive() else { return }
    let cur = current.lowercased()
    guard cur.count >= 2,
          !cur.contains(where: { !$0.isLetter && !$0.isWhitespace })
    else { return }
    guard let prev1 = prev1?.lowercased(), !prev1.isEmpty else { return }
    NGramStore.shared.learn(prev2: prev2?.lowercased(), prev1: prev1, current: cur)
  }

  /// Ghi nhận chuỗi gợi ý đã chấp nhận (2–3 từ) vào n-gram store.
  func learnAcceptedPhrase(_ phrase: String, prev2: String?, prev1: String?) {
    let words = phrase
      .split(separator: " ", omittingEmptySubsequences: true)
      .map { String($0).lowercased() }
    guard !words.isEmpty else { return }
    var p2 = prev2?.lowercased()
    var p1 = prev1?.lowercased()
    for word in words {
      learnTransition(prev2: p2, prev1: p1, current: word)
      p2 = p1
      p1 = word
    }
  }
}
