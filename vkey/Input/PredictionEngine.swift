//
//  PredictionEngine.swift
//  vkey
//
//  Word prediction engine (1.6.0+). Đoán từ tiếp theo dựa trên:
//
//  - Layer 1: Trigram user (prev2, prev1 → ?) — chính xác nhất nhưng
//    cần sample lớn.
//  - Layer 2: Bigram user (prev1 → ?) — học từ history user gõ.
//  - Layer 3: Bigram embedded VN corpus (`EmbeddedBigrams.commonPairs`)
//    — fallback cho user mới chưa có data.
//
//  Học passively từ `InputProcessor.applySpellDecisionOnCommit` mỗi khi
//  user commit 1 từ → call `learnTransition(prev2:, prev1:, current:)`.
//

import Defaults
import Foundation

final class PredictionEngine {
  static let shared = PredictionEngine()

  /// Min count để bigram user candidate được dùng (tránh single-occurrence
  /// noise). Threshold riêng cho trigram cao hơn vì cần sample lớn.
  private let userBigramThreshold = 2
  private let userTrigramThreshold = 2

  /// 1.6.1: Trả về top prediction cho cụm "prev2 prev1". Thay vì pure
  /// frequency, ranking blended với dictionary priority để tránh suggest
  /// rác (vd "tcb", cụm trùng prev1).
  ///
  /// Scoring per candidate:
  /// - +1000 nếu là từ tiếng Việt (built-in lexicon hoặc user allow list)
  /// - +500 nếu nằm trong personal `userKeepWords`
  /// - + raw frequency (user bigram/trigram count) hoặc weight (embedded)
  ///
  /// Filter cứng: loại candidate trùng prev1 (vd "dữ" → "dữ") — đây là
  /// noise từ learnTransition đôi khi học chính từ vừa gõ.
  /// Filter mềm: candidate phải đạt ít nhất 1000 (có dict bonus) HOẶC 5
  /// (frequency cao). Tránh suggest từ thấp ngưỡng + không có cơ sở từ điển.
  func topPrediction(prev2: String?, prev1: String) -> String? {
    return topNPredictions(prev2: prev2, prev1: prev1, n: 1).first
  }

  /// 2.0 (A2): trả về top-N candidates sắp theo score giảm dần.
  /// N = 1 đảm bảo backward-compat với behavior cũ.
  /// Caller (PredictionHUDWindow) thường gọi với N = Defaults[.predictionTopN].
  func topNPredictions(prev2: String?, prev1: String, n: Int) -> [String] {
    let p1 = prev1.lowercased()
    guard !p1.isEmpty, n > 0 else { return [] }

    let candidates = collectCandidates(prev2: prev2, prev1: p1)
    let keepSet = Set(Defaults[.userKeepWords].map { $0.lowercased() })

    var scored: [(word: String, score: Int)] = []
    for (word, freq) in candidates {
      // Hard filter: không suggest từ trùng với prev1.
      if word == p1 { continue }
      let dictBonus = LexiconManager.shared.isVietnameseWord(word) ? 1000 : 0
      let personalBonus = keepSet.contains(word) ? 500 : 0
      let score = dictBonus + personalBonus + freq
      // Soft floor: phải có dict bonus hoặc freq ≥ 5.
      guard score >= 1000 || freq >= 5 else { continue }
      scored.append((word, score))
    }
    scored.sort { $0.score > $1.score }
    return Array(scored.prefix(n).map { $0.word })
  }

  /// Tập hợp toàn bộ candidates từ 3 layers cùng frequency tương đối.
  /// Internal để test (1.6.1+).
  func collectCandidates(prev2: String?, prev1: String) -> [(word: String, freq: Int)] {
    var out: [String: Int] = [:]

    // Layer 1: trigram user (1.7.x: NGramStore thay Defaults)
    if let prev2 = prev2 {
      let nexts = NGramStore.shared.trigramNexts(prev2: prev2.lowercased(), prev1: prev1)
      for (w, c) in nexts where c >= userTrigramThreshold {
        out[w, default: 0] += c * 2  // trigram weight 2× (more specific)
      }
    }

    // Layer 2: bigram user (1.7.x: NGramStore thay Defaults)
    let bigramNexts = NGramStore.shared.bigramNexts(prev1: prev1)
    for (w, c) in bigramNexts where c >= userBigramThreshold {
      out[w, default: 0] += c
    }

    // Layer 3: embedded VN corpus
    if let nexts = EmbeddedBigrams.commonPairs[prev1] {
      for (next, weight) in nexts {
        out[next, default: 0] += weight
      }
    }

    return out.map { (word: $0.key, freq: $0.value) }
  }

  /// Học từ commit: update bigram[prev1][curr] + trigram[prev2|prev1][curr].
  /// Skip nếu word quá ngắn, hoặc chứa ký tự đặc biệt (số, punctuation).
  /// 1.7.x: delegate sang NGramStore — async, không block main thread.
  func learnTransition(prev2: String?, prev1: String?, current: String) {
    let cur = current.lowercased()
    // Skip ngắn / chứa non-letter.
    guard cur.count >= 2,
          !cur.contains(where: { !$0.isLetter && !$0.isWhitespace })
    else { return }
    guard let prev1 = prev1?.lowercased(), !prev1.isEmpty else { return }

    NGramStore.shared.learn(prev2: prev2?.lowercased(), prev1: prev1, current: cur)
  }
}
