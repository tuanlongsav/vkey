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

  /// Trả về top prediction cho cụm "prev2 prev1". Layered fallback:
  /// 1. Trigram user (prev2, prev1 → ?), count ≥ threshold
  /// 2. Bigram user (prev1 → ?), count ≥ threshold
  /// 3. Bigram embedded corpus (prev1 → ?)
  /// 4. nil — không đoán
  func topPrediction(prev2: String?, prev1: String) -> String? {
    let p1 = prev1.lowercased()
    guard !p1.isEmpty else { return nil }

    // Layer 1: trigram user
    if let prev2 = prev2 {
      let key = "\(prev2.lowercased())|\(p1)"
      if let nexts = Defaults[.userTrigrams][key],
         let top = nexts.max(by: { $0.value < $1.value }),
         top.value >= userTrigramThreshold
      {
        return top.key
      }
    }

    // Layer 2: bigram user
    if let nexts = Defaults[.userBigrams][p1],
       let top = nexts.max(by: { $0.value < $1.value }),
       top.value >= userBigramThreshold
    {
      return top.key
    }

    // Layer 3: embedded VN corpus
    if let nexts = EmbeddedBigrams.commonPairs[p1],
       let top = nexts.max(by: { $0.weight < $1.weight })
    {
      return top.next
    }

    return nil
  }

  /// Học từ commit: update bigram[prev1][curr] + trigram[prev2|prev1][curr].
  /// Skip nếu word quá ngắn, hoặc chứa ký tự đặc biệt (số, punctuation).
  func learnTransition(prev2: String?, prev1: String?, current: String) {
    let cur = current.lowercased()
    // Skip ngắn / chứa non-letter.
    guard cur.count >= 2,
          !cur.contains(where: { !$0.isLetter && !$0.isWhitespace })
    else { return }
    guard let prev1 = prev1?.lowercased(), !prev1.isEmpty else { return }

    // Bigram update
    var bigrams = Defaults[.userBigrams]
    var nexts = bigrams[prev1, default: [:]]
    nexts[cur, default: 0] += 1
    bigrams[prev1] = nexts
    Defaults[.userBigrams] = bigrams

    // Trigram update (chỉ khi có prev2)
    if let prev2 = prev2?.lowercased(), !prev2.isEmpty {
      let key = "\(prev2)|\(prev1)"
      var trigrams = Defaults[.userTrigrams]
      var trinexts = trigrams[key, default: [:]]
      trinexts[cur, default: 0] += 1
      trigrams[key] = trinexts
      Defaults[.userTrigrams] = trigrams
    }
  }
}
