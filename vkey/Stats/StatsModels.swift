//
//  StatsModels.swift
//  vkey
//
//  Data models for local usage statistics (summaries, unified WeekBucket,
//  categories, and ISO-8601 JSON codecs).
//

import Foundation

// MARK: - Summary DTOs

/// Snapshot tóm tắt một tuần đã đóng (hoặc tuần hiện tại đến thời điểm hỏi).
public struct UsageSummary: Codable, Equatable {
  /// ISO week id, ví dụ "2026-W21". Khoá unique giữa các file lưu.
  let weekId: String
  /// Thời điểm tuần kết thúc (ISO-8601). Dùng để rotate.
  let weekEnd: Date

  let wordsTotal: Int
  let wordsKeptVietnamese: Int
  let wordsRestoredEnglish: Int
  let wordsKeptRaw: Int
  let wordsSuggested: Int

  let smartSwitchFires: Int
  let typoCorrectionsApplied: Int

  let topVietnameseWords: [WordCount]
  let topEnglishWords: [WordCount]
  let topApps: [WordCount]

  let promotedToAllow: [String]
  let promotedToKeep: [String]
}

public struct WordCount: Codable, Equatable {
  let word: String
  let count: Int
}

/// Stat category để lọc / xoá mục cụ thể trong tuần hiện tại.
enum UsageStatCategory {
  case vietnamese       // Top từ tiếng Việt
  case english          // Top từ tiếng Anh / raw
  case app              // Top app
  case vietnamesePhrase // Cụm 2–4 từ tiếng Việt
  case englishPhrase    // Cụm 2–3 từ ngoài tiếng Việt
}

// MARK: - Unified WeekBucket (in-memory + on-disk + lossless backup export)

/// Alias giữ tương thích API với `UserDataExport` và các bản backup v2.
public typealias WeekBucketExport = WeekBucket

/// Full weekly counters, frequency tables, streaks, phrase tables, and
/// per-app language tracking. Backward-compatible `Codable` so files from
/// older vkey versions always decode without throwing.
public struct WeekBucket: Codable {
  public var weekId: String
  public var weekEnd: Date

  public var wordsTotal: Int = 0
  public var wordsKeptVietnamese: Int = 0
  public var wordsRestoredEnglish: Int = 0
  public var wordsKeptRaw: Int = 0
  public var wordsSuggested: Int = 0
  public var smartSwitchFires: Int = 0
  public var typoCorrectionsApplied: Int = 0

  public var vnWordCounts: [String: Int] = [:]
  public var enWordCounts: [String: Int] = [:]
  public var appCounts: [String: Int] = [:]

  public var vnKeepStreak: [String: Int] = [:]
  public var enRestoreStreak: [String: Int] = [:]

  public var vnPhraseCounts2: [String: Int] = [:]
  public var vnPhraseCounts3: [String: Int] = [:]
  public var vnPhraseCounts4: [String: Int] = [:]

  public var enPhraseCounts2: [String: Int] = [:]
  public var enPhraseCounts3: [String: Int] = [:]

  public var appLanguageVnCounts: [String: Int] = [:]
  public var appLanguageEnCounts: [String: Int] = [:]
  public var appLanguageDays: [String: [Int]] = [:]

  enum CodingKeys: String, CodingKey {
    case weekId, weekEnd
    case wordsTotal, wordsKeptVietnamese, wordsRestoredEnglish
    case wordsKeptRaw, wordsSuggested, smartSwitchFires
    case typoCorrectionsApplied
    case vnWordCounts, enWordCounts, appCounts
    case vnKeepStreak, enRestoreStreak
    case vnPhraseCounts2, vnPhraseCounts3, vnPhraseCounts4
    case enPhraseCounts2, enPhraseCounts3
    case appLanguageVnCounts, appLanguageEnCounts, appLanguageDays
  }

  public init(
    weekId: String = WeekBucket.currentWeekId(),
    weekEnd: Date = WeekBucket.endOfCurrentWeek(),
    wordsTotal: Int = 0,
    wordsKeptVietnamese: Int = 0,
    wordsRestoredEnglish: Int = 0,
    wordsKeptRaw: Int = 0,
    wordsSuggested: Int = 0,
    smartSwitchFires: Int = 0,
    typoCorrectionsApplied: Int = 0,
    vnWordCounts: [String: Int] = [:],
    enWordCounts: [String: Int] = [:],
    appCounts: [String: Int] = [:],
    vnKeepStreak: [String: Int] = [:],
    enRestoreStreak: [String: Int] = [:],
    vnPhraseCounts2: [String: Int] = [:],
    vnPhraseCounts3: [String: Int] = [:],
    vnPhraseCounts4: [String: Int] = [:],
    enPhraseCounts2: [String: Int] = [:],
    enPhraseCounts3: [String: Int] = [:],
    appLanguageVnCounts: [String: Int] = [:],
    appLanguageEnCounts: [String: Int] = [:],
    appLanguageDays: [String: [Int]] = [:]
  ) {
    self.weekId = weekId.isEmpty ? WeekBucket.currentWeekId() : weekId
    self.weekEnd = weekEnd
    self.wordsTotal = wordsTotal
    self.wordsKeptVietnamese = wordsKeptVietnamese
    self.wordsRestoredEnglish = wordsRestoredEnglish
    self.wordsKeptRaw = wordsKeptRaw
    self.wordsSuggested = wordsSuggested
    self.smartSwitchFires = smartSwitchFires
    self.typoCorrectionsApplied = typoCorrectionsApplied
    self.vnWordCounts = vnWordCounts
    self.enWordCounts = enWordCounts
    self.appCounts = appCounts
    self.vnKeepStreak = vnKeepStreak
    self.enRestoreStreak = enRestoreStreak
    self.vnPhraseCounts2 = vnPhraseCounts2
    self.vnPhraseCounts3 = vnPhraseCounts3
    self.vnPhraseCounts4 = vnPhraseCounts4
    self.enPhraseCounts2 = enPhraseCounts2
    self.enPhraseCounts3 = enPhraseCounts3
    self.appLanguageVnCounts = appLanguageVnCounts
    self.appLanguageEnCounts = appLanguageEnCounts
    self.appLanguageDays = appLanguageDays
  }

  /// Bridge backup v1 (`UsageSummary`) → `WeekBucket` (lossy: giữ top words counts).
  init(fromLegacySummary summary: UsageSummary) {
    self.init(
      weekId: summary.weekId,
      weekEnd: summary.weekEnd,
      wordsTotal: summary.wordsTotal,
      wordsKeptVietnamese: summary.wordsKeptVietnamese,
      wordsRestoredEnglish: summary.wordsRestoredEnglish,
      wordsKeptRaw: summary.wordsKeptRaw,
      wordsSuggested: summary.wordsSuggested,
      smartSwitchFires: summary.smartSwitchFires,
      typoCorrectionsApplied: summary.typoCorrectionsApplied,
      vnWordCounts: Dictionary(uniqueKeysWithValues: summary.topVietnameseWords.map { ($0.word, $0.count) }),
      enWordCounts: Dictionary(uniqueKeysWithValues: summary.topEnglishWords.map { ($0.word, $0.count) }),
      appCounts: Dictionary(uniqueKeysWithValues: summary.topApps.map { ($0.word, $0.count) })
    )
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let rawWeekId = try c.decodeIfPresent(String.self, forKey: .weekId) ?? ""
    self.weekId = rawWeekId.isEmpty ? WeekBucket.currentWeekId() : rawWeekId
    self.weekEnd = try c.decodeIfPresent(Date.self, forKey: .weekEnd) ?? WeekBucket.endOfCurrentWeek()
    self.wordsTotal = try c.decodeIfPresent(Int.self, forKey: .wordsTotal) ?? 0
    self.wordsKeptVietnamese = try c.decodeIfPresent(Int.self, forKey: .wordsKeptVietnamese) ?? 0
    self.wordsRestoredEnglish = try c.decodeIfPresent(Int.self, forKey: .wordsRestoredEnglish) ?? 0
    self.wordsKeptRaw = try c.decodeIfPresent(Int.self, forKey: .wordsKeptRaw) ?? 0
    self.wordsSuggested = try c.decodeIfPresent(Int.self, forKey: .wordsSuggested) ?? 0
    self.smartSwitchFires = try c.decodeIfPresent(Int.self, forKey: .smartSwitchFires) ?? 0
    self.typoCorrectionsApplied = try c.decodeIfPresent(Int.self, forKey: .typoCorrectionsApplied) ?? 0
    self.vnWordCounts = try c.decodeIfPresent([String: Int].self, forKey: .vnWordCounts) ?? [:]
    self.enWordCounts = try c.decodeIfPresent([String: Int].self, forKey: .enWordCounts) ?? [:]
    self.appCounts = try c.decodeIfPresent([String: Int].self, forKey: .appCounts) ?? [:]
    self.vnKeepStreak = try c.decodeIfPresent([String: Int].self, forKey: .vnKeepStreak) ?? [:]
    self.enRestoreStreak = try c.decodeIfPresent([String: Int].self, forKey: .enRestoreStreak) ?? [:]
    self.vnPhraseCounts2 = try c.decodeIfPresent([String: Int].self, forKey: .vnPhraseCounts2) ?? [:]
    self.vnPhraseCounts3 = try c.decodeIfPresent([String: Int].self, forKey: .vnPhraseCounts3) ?? [:]
    self.vnPhraseCounts4 = try c.decodeIfPresent([String: Int].self, forKey: .vnPhraseCounts4) ?? [:]
    self.enPhraseCounts2 = try c.decodeIfPresent([String: Int].self, forKey: .enPhraseCounts2) ?? [:]
    self.enPhraseCounts3 = try c.decodeIfPresent([String: Int].self, forKey: .enPhraseCounts3) ?? [:]
    self.appLanguageVnCounts = try c.decodeIfPresent([String: Int].self, forKey: .appLanguageVnCounts) ?? [:]
    self.appLanguageEnCounts = try c.decodeIfPresent([String: Int].self, forKey: .appLanguageEnCounts) ?? [:]
    self.appLanguageDays = try c.decodeIfPresent([String: [Int]].self, forKey: .appLanguageDays) ?? [:]
  }

  func summary(promotedAllow: [String], promotedKeep: [String]) -> UsageSummary {
    func sortedEntries(_ counts: [String: Int]) -> [(key: String, value: Int)] {
      counts.sorted { lhs, rhs in
        lhs.value > rhs.value || (lhs.value == rhs.value && lhs.key < rhs.key)
      }
    }
    func top(_ counts: [String: Int], n: Int) -> [WordCount] {
      sortedEntries(counts).prefix(n).map { WordCount(word: $0.key, count: $0.value) }
    }
    func topPercent(_ counts: [String: Int], percent: Double) -> [WordCount] {
      let sorted = sortedEntries(counts)
      let cap = Int(ceil(Double(sorted.count) * percent))
      return sorted.prefix(cap).map { WordCount(word: $0.key, count: $0.value) }
    }
    return UsageSummary(
      weekId: weekId,
      weekEnd: weekEnd,
      wordsTotal: wordsTotal,
      wordsKeptVietnamese: wordsKeptVietnamese,
      wordsRestoredEnglish: wordsRestoredEnglish,
      wordsKeptRaw: wordsKeptRaw,
      wordsSuggested: wordsSuggested,
      smartSwitchFires: smartSwitchFires,
      typoCorrectionsApplied: typoCorrectionsApplied,
      topVietnameseWords: topPercent(vnWordCounts, percent: 0.1),
      topEnglishWords: topPercent(enWordCounts, percent: 0.1),
      topApps: top(appCounts, n: 10),
      promotedToAllow: promotedAllow,
      promotedToKeep: promotedKeep
    )
  }

  /// `weekId` đúng dạng ISO ("2026-W21") — an toàn để làm tên file.
  static func isValidWeekId(_ weekId: String) -> Bool {
    weekId.range(of: #"^[0-9]{4}-W[0-9]{2}\z"#, options: .regularExpression) != nil
  }

  public static func currentWeekId() -> String {
    let cal = Calendar(identifier: .iso8601)
    let now = Date()
    let year = cal.component(.yearForWeekOfYear, from: now)
    let week = cal.component(.weekOfYear, from: now)
    return String(format: "%04d-W%02d", year, week)
  }

  public static func endOfCurrentWeek() -> Date {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2  // Monday — matches ISO
    let now = Date()
    let comps = cal.dateComponents(
      [.yearForWeekOfYear, .weekOfYear, .weekday, .hour, .minute, .second],
      from: now
    )
    var endComps = DateComponents()
    endComps.yearForWeekOfYear = comps.yearForWeekOfYear
    endComps.weekOfYear = comps.weekOfYear
    endComps.weekday = 1  // Sunday in ISO is the last day of the week
    endComps.hour = 23
    endComps.minute = 59
    endComps.second = 59
    return cal.date(from: endComps) ?? now
  }
}

// MARK: - Shared Stats JSON Codecs

extension JSONEncoder {
  static let statsIndented: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    e.dateEncodingStrategy = .iso8601
    return e
  }()
}

extension JSONDecoder {
  static let statsConfigured: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()
}
