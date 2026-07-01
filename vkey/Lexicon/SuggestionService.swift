//
//  SuggestionService.swift
//  vkey
//
//  Spelling suggestion engine. Combines Levenshtein distance with simple
//  phonetic heuristics over the Vietnamese lexicon. Extracted from
//  InputProcessor.swift in 1.5.0.
//

import Foundation

final class SuggestionService {
  static let shared = SuggestionService()

  private let lexiconManager: LexiconManager

  // L6: cache mảng snapshot từ điển thay vì copy cả Set → Array mỗi lần gọi.
  // Invalidate theo version từ điển. Lock để an toàn nếu gọi từ nhiều thread.
  private let cacheLock = NSLock()
  private var cachedCandidates: [String] = []
  private var cachedVnVersion: Int = Int.min

  init(lexiconManager: LexiconManager = .shared) {
    self.lexiconManager = lexiconManager
  }

  /// Snapshot từ điển VN, cache lại và chỉ dựng lại khi version đổi.
  private func candidateSnapshot() -> [String] {
    let version = lexiconManager.snapshotVersions().vn
    cacheLock.lock()
    defer { cacheLock.unlock() }
    if version != cachedVnVersion {
      cachedCandidates = lexiconManager.vietnameseWordsSnapshot()
      cachedVnVersion = version
    }
    return cachedCandidates
  }

  func suggest(word: String, locale: String = "vi_VN", limit: Int = 5) -> [SuggestionCandidate] {
    let query = word.normalizedDictionaryToken
    guard !query.isEmpty, locale.lowercased().hasPrefix("vi"), limit > 0 else { return [] }

    let queryFolded = query.vietnameseFolded
    guard !queryFolded.isEmpty else { return [] }

    let candidates = candidateSnapshot()
      .map { candidate -> SuggestionCandidate in
        let foldedCandidate = candidate.vietnameseFolded
        let distance = Self.levenshtein(queryFolded, foldedCandidate)
        let prefixBonus: Double = queryFolded.first == foldedCandidate.first ? 0.12 : 0
        let suffixBonus: Double = queryFolded.last == foldedCandidate.last ? 0.08 : 0
        let lengthPenalty = abs(queryFolded.count - foldedCandidate.count) > 2 ? 0.08 : 0
        let baseScore = 1.0 / Double(distance + 1)
        let score = max(0, min(1, baseScore + prefixBonus + suffixBonus - lengthPenalty))
        return SuggestionCandidate(word: candidate, score: score)
      }
      .filter { $0.score >= 0.24 }
      .sorted {
        if abs($0.score - $1.score) > 0.0001 {
          return $0.score > $1.score
        }
        return $0.word < $1.word
      }

    return Array(candidates.prefix(limit))
  }

  static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
    let a = Array(lhs)
    let b = Array(rhs)
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }

    var previous = Array(0...b.count)
    var current = Array(repeating: 0, count: b.count + 1)

    for i in 1...a.count {
      current[0] = i
      for j in 1...b.count {
        let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
        let insertion = current[j - 1] + 1
        let deletion = previous[j] + 1
        current[j] = min(substitution, insertion, deletion)
      }
      swap(&previous, &current)
    }
    return previous[b.count]
  }
}
