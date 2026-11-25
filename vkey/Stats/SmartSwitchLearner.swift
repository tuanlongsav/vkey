//
//  SmartSwitchLearner.swift
//  vkey
//
//  Pure heuristic that proposes per-app Vietnamese/English Smart Switch
//  modes based on observed weekly language dominance.
//

import Foundation

enum SmartSwitchLearner {

  /// Chế độ đề xuất cho một app từ số từ Việt / Anh đã commit, hoặc `nil` nếu
  /// chưa đủ dữ liệu (≥ 1 ngày, ≥ 5 từ/ngày) hay tỉ lệ lưng chừng (< 75%).
  static func suggestion(vn: Int, en: Int, days: Int) -> AppSmartSwitchState? {
    let total = vn + en
    guard total > 0, days >= 1, Double(total) / Double(days) >= 5 else { return nil }
    let ratio = Double(vn) / Double(total)
    if ratio >= 0.75 { return .vietnameseMode }
    if ratio <= 0.25 { return .englishMode }
    return nil
  }

  static func computeAutoLearn(from bucket: WeekBucket) -> [String: AppSmartSwitchState] {
    var out: [String: AppSmartSwitchState] = [:]
    let bundles = Set(bucket.appLanguageVnCounts.keys).union(bucket.appLanguageEnCounts.keys)
    for bundleId in bundles {
      if let state = suggestion(
        vn: bucket.appLanguageVnCounts[bundleId] ?? 0,
        en: bucket.appLanguageEnCounts[bundleId] ?? 0,
        days: bucket.appLanguageDays[bundleId]?.count ?? 0
      ) {
        out[bundleId] = state
      }
    }
    return out
  }
}
