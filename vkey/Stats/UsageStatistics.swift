//
//  UsageStatistics.swift
//  vkey
//
//  Local-only usage tracking, introduced in 1.5.0 (the "Bilingual Reborn"
//  patch series escalates this from "deferred" to "shipping" because the
//  data also feeds the personal-dictionary auto-promotion in
//  `performWeeklyFeedback()`).
//
//  Privacy contract (cam kết riêng tư):
//
//  1. Tất cả dữ liệu nằm dưới `~/Library/Application Support/vkey/stats/`
//     trên máy người dùng. Không có lệnh gọi mạng nào trong file này.
//  2. Người dùng có thể tắt qua `Defaults[.statisticsEnabled]`. Khi tắt,
//     `recordCommit(...)` no-op ngay lập tức.
//  3. Người dùng có thể clear toàn bộ data thông qua
//     `UsageStatistics.shared.clearAll()` (gọi từ Settings UI).
//  4. Mỗi tuần ISO-week có một file riêng (`2026-W21.json`); rotate giữ
//     4 tuần gần nhất.
//

import Carbon  // IsSecureEventInputEnabled (HIToolbox)
import Defaults
import Foundation
import os.log

private let log = OSLog(subsystem: "dev.longht.vkey", category: "UsageStatistics")

// MARK: - Public types

/// Snapshot tóm tắt một tuần đã đóng (hoặc tuần hiện tại đến thời điểm hỏi).
public struct UsageSummary: Codable, Equatable {
  /// ISO week id, ví dụ "2026-W21". Khoá unique giữa các file lưu.
  let weekId: String
  /// Thời điểm tuần kết thúc (ISO-8601). Dùng để rotate.
  let weekEnd: Date

  // Counters
  let wordsTotal: Int
  let wordsKeptVietnamese: Int
  let wordsRestoredEnglish: Int
  let wordsKeptRaw: Int
  let wordsSuggested: Int

  let smartSwitchFires: Int
  let typoCorrectionsApplied: Int

  // Frequency tables — capped at top 20 to keep file size predictable.
  let topVietnameseWords: [WordCount]
  let topEnglishWords: [WordCount]
  let topApps: [WordCount]

  /// Words promoted to the user's personal dictionary during this week's
  /// feedback pass. Surfaced so the Settings UI can show
  /// "đã thêm 3 từ vào danh sách Allow".
  let promotedToAllow: [String]
  let promotedToKeep: [String]
}

public struct WordCount: Codable, Equatable {
  let word: String
  let count: Int
}

/// 1.7.6: full snapshot của 1 tuần để export/import lossless. Mirror nội bộ
/// `WeekBucket` (private) nhưng public-encodable. Backward-compat: mọi field
/// optional, decode file backup v1 (chỉ có UsageSummary) bằng cách fallback
/// raw counts = 0 / empty maps.
public struct WeekBucketExport: Codable {
  public let weekId: String
  public let weekEnd: Date

  public let wordsTotal: Int
  public let wordsKeptVietnamese: Int
  public let wordsRestoredEnglish: Int
  public let wordsKeptRaw: Int
  public let wordsSuggested: Int
  public let smartSwitchFires: Int
  public let typoCorrectionsApplied: Int

  // Full frequency tables — không phải top 10% summary.
  public let vnWordCounts: [String: Int]
  public let enWordCounts: [String: Int]
  public let appCounts: [String: Int]

  public let vnKeepStreak: [String: Int]
  public let enRestoreStreak: [String: Int]

  public let vnPhraseCounts2: [String: Int]   // 1.6.1+
  public let vnPhraseCounts3: [String: Int]

  public let enPhraseCounts2: [String: Int]   // 1.7.9+
  public let enPhraseCounts3: [String: Int]

  public let appLanguageVnCounts: [String: Int]  // 1.7.0+
  public let appLanguageEnCounts: [String: Int]
  public let appLanguageDays: [String: [Int]]

  // Backward-compat decode: mọi field optional, fallback empty.
  enum CodingKeys: String, CodingKey {
    case weekId, weekEnd
    case wordsTotal, wordsKeptVietnamese, wordsRestoredEnglish
    case wordsKeptRaw, wordsSuggested, smartSwitchFires
    case typoCorrectionsApplied
    case vnWordCounts, enWordCounts, appCounts
    case vnKeepStreak, enRestoreStreak
    case vnPhraseCounts2, vnPhraseCounts3
    case enPhraseCounts2, enPhraseCounts3   // 1.7.9+
    case appLanguageVnCounts, appLanguageEnCounts, appLanguageDays
  }

  public init(
    weekId: String, weekEnd: Date,
    wordsTotal: Int, wordsKeptVietnamese: Int, wordsRestoredEnglish: Int,
    wordsKeptRaw: Int, wordsSuggested: Int, smartSwitchFires: Int,
    typoCorrectionsApplied: Int,
    vnWordCounts: [String: Int], enWordCounts: [String: Int], appCounts: [String: Int],
    vnKeepStreak: [String: Int], enRestoreStreak: [String: Int],
    vnPhraseCounts2: [String: Int], vnPhraseCounts3: [String: Int],
    enPhraseCounts2: [String: Int] = [:], enPhraseCounts3: [String: Int] = [:],
    appLanguageVnCounts: [String: Int], appLanguageEnCounts: [String: Int],
    appLanguageDays: [String: [Int]]
  ) {
    self.weekId = weekId
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
    self.enPhraseCounts2 = enPhraseCounts2
    self.enPhraseCounts3 = enPhraseCounts3
    self.appLanguageVnCounts = appLanguageVnCounts
    self.appLanguageEnCounts = appLanguageEnCounts
    self.appLanguageDays = appLanguageDays
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.weekId = try c.decodeIfPresent(String.self, forKey: .weekId) ?? ""
    self.weekEnd = try c.decodeIfPresent(Date.self, forKey: .weekEnd) ?? Date()
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
    self.enPhraseCounts2 = try c.decodeIfPresent([String: Int].self, forKey: .enPhraseCounts2) ?? [:]
    self.enPhraseCounts3 = try c.decodeIfPresent([String: Int].self, forKey: .enPhraseCounts3) ?? [:]
    self.appLanguageVnCounts = try c.decodeIfPresent([String: Int].self, forKey: .appLanguageVnCounts) ?? [:]
    self.appLanguageEnCounts = try c.decodeIfPresent([String: Int].self, forKey: .appLanguageEnCounts) ?? [:]
    self.appLanguageDays = try c.decodeIfPresent([String: [Int]].self, forKey: .appLanguageDays) ?? [:]
  }
}

// MARK: - UsageStatistics

/// Tracker singleton. Stateful but thread-safe via a serial queue.
final class UsageStatistics {

  static let shared = UsageStatistics()

  // MARK: Hot path counters (current week)

  private var counters = WeekBucket()
  private let queue = DispatchQueue(label: "dev.longht.vkey.stats", qos: .utility)

  // MARK: Storage

  /// `~/Library/Application Support/vkey/stats/` by default. Tests can pass
  /// a private directory through the test-only initializer so parallel
  /// suites don't share on-disk state.
  let storageDir: URL

  /// Test-only initializer. Production code uses `.shared`.
  init(storageDir: URL? = nil) {
    let resolved: URL
    if let custom = storageDir {
      resolved = custom
    } else {
      let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
      resolved = (appSupport ?? URL(fileURLWithPath: "/tmp"))
        .appendingPathComponent("vkey/stats", isDirectory: true)
    }
    try? FileManager.default.createDirectory(
      at: resolved, withIntermediateDirectories: true, attributes: nil
    )
    self.storageDir = resolved
    loadCurrentWeekIfNeeded()
  }

  /// Pending flush task token — set when a counter changes, cleared when
  /// flushed. Keeps disk writes throttled to one per ~10 seconds.
  private var pendingFlushItem: DispatchWorkItem?

  /// 1.6.1: sliding window các từ tiếng Việt vừa commit (≤3) để tracking
  /// phrase bigram/trigram. Reset khi gõ tiếng Anh/raw/Smart Switch.
  private var recentVnQueue: [String] = []

  /// 1.7.9: sliding window EN/raw vừa commit (≤3) — đối ứng với recentVnQueue.
  /// Reset khi xen .keepVietnamese / .suggest / smart switch (đổi context).
  private var recentEnQueue: [String] = []

  /// Limit on the number of weekly files we keep on disk. Older files get
  /// deleted automatically during flush.
  private let maxWeeksRetained = 4

  /// Word-count cap per category to keep memory + disk bounded.
  private let topNCap = 20

  /// Minimum repetitions before a word is eligible for personal-dictionary
  /// promotion. Conservative — 5 confirmed commits in a week is a strong
  /// signal but not so high we miss common patterns.
  private let promotionThreshold = 5

  // MARK: - Hot path

  /// Called from `InputProcessor.applySpellDecisionOnCommit(...)` for every
  /// committed word. The `decision` tells us what we did with the word.
  /// Bundle ID of the foreground app helps build the top-apps chart.
  func recordCommit(
    decision: SpellDecision,
    rawInput: String,
    transformed: String,
    appBundleId: String?,
    typoCorrectionApplied: Bool = false,
    needsRecovery: Bool = false
  ) {
    guard Defaults[.statisticsEnabled] else { return }
    // 1.5.9: defense-in-depth — không ghi nhận khi macOS đang trong
    // chế độ secure input (ô mật khẩu, sudo prompt, 1Password reveal,
    // ...). EventHook đã bypass processing trong secure input, nhưng
    // có thể có race window khi vừa thoát secure input mà buffer còn
    // commit lưng chừng. Guard này đảm bảo password không bao giờ rò
    // vào top words list.
    guard !UsageStatistics.isSecureInputActive() else { return }
    queue.async { [weak self] in
      self?.applyCommit(
        decision: decision,
        rawInput: rawInput,
        transformed: transformed,
        appBundleId: appBundleId,
        typoCorrectionApplied: typoCorrectionApplied,
        needsRecovery: needsRecovery
      )
    }
  }

  /// Wrapper quanh `CGSIsSecureEventInputSet` (đã được declare ở
  /// `EventHook.swift`). Tách thành static để mock được trong test.
  /// File-scoped declaration sang `CGSIsSecureEventInputSet` không
  /// access được cross-file, nên dùng public API `IsSecureEventInputEnabled`
  /// từ HIToolbox (Carbon framework).
  private static func isSecureInputActive() -> Bool {
    // `IsSecureEventInputEnabled` là public API trong HIToolbox/Carbon,
    // không cần private @_silgen_name như CGSIsSecureEventInputSet.
    return IsSecureEventInputEnabled()
  }

  /// Called from `EventHook` when Smart Switch auto-disables / restores VN
  /// because the user moved to a launcher app.
  func recordSmartSwitchFire(toApp: String?) {
    guard Defaults[.statisticsEnabled] else { return }
    queue.async { [weak self] in
      guard let self else { return }
      self.rotateIfNeeded()
      self.counters.smartSwitchFires += 1
      if let app = toApp {
        self.counters.appCounts[app, default: 0] += 1
      }
      // 1.6.1: ngắt chain phrase khi Smart Switch (đổi context).
      self.recentVnQueue.removeAll()
      // 1.7.9: ngắt EN phrase chain cùng lúc.
      self.recentEnQueue.removeAll()
      self.scheduleFlush()
    }
  }

  // MARK: - Public reads

  /// Current (incomplete) week's snapshot.
  func currentWeekSummary() -> UsageSummary {
    queue.sync {
      rotateIfNeeded()
      return counters.summary(promotedAllow: [], promotedKeep: [])
    }
  }

  /// All closed-week snapshots on disk, newest first.
  /// 1.6.1: defensive filter loại `<currentWeekId>.json` nếu lỡ tồn tại
  /// trên disk (legacy 1.5.x/1.6.0 ghi nhầm) — tuần đang chạy phải đọc
  /// từ `counters` qua `currentWeekSummary()`.
  func historicalSummaries() -> [UsageSummary] {
    queue.sync {
      let currentWeekFile = "\(WeekBucket.currentWeekId()).json"
      let urls = (try? FileManager.default.contentsOfDirectory(
        at: storageDir, includingPropertiesForKeys: nil
      )) ?? []
      var out: [UsageSummary] = []
      for url in urls where url.pathExtension == "json"
                           && url.lastPathComponent != "current.json"
                           && url.lastPathComponent != currentWeekFile {
        if let data = try? Data(contentsOf: url),
           let summary = try? JSONDecoder.statsConfigured.decode(UsageSummary.self, from: data) {
          out.append(summary)
        }
      }
      out.sort { $0.weekId > $1.weekId }
      return out
    }
  }

  /// 1.6.1: chẩn đoán — liệt kê file + đếm word counts để user gửi lại
  /// khi báo lỗi stats. Trả về plain text (multi-line).
  func diagnosticReport() -> String {
    queue.sync {
      var lines: [String] = []
      lines.append("vkey stats diagnostic — \(ISO8601DateFormatter().string(from: Date()))")
      lines.append("storageDir: \(storageDir.path)")
      lines.append("counters.weekId: \(counters.weekId)")
      lines.append("counters.wordsTotal: \(counters.wordsTotal)")
      lines.append("counters.vnWordCounts.count: \(counters.vnWordCounts.count)")
      lines.append("counters.enWordCounts.count: \(counters.enWordCounts.count)")
      lines.append("currentWeekId(): \(WeekBucket.currentWeekId())")
      lines.append("--- files on disk ---")
      let urls = (try? FileManager.default.contentsOfDirectory(
        at: storageDir, includingPropertiesForKeys: [.fileSizeKey]
      )) ?? []
      for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        var summary = "(decode failed)"
        if let data = try? Data(contentsOf: url) {
          if url.lastPathComponent == "current.json" {
            if let bucket = try? JSONDecoder.statsConfigured.decode(WeekBucket.self, from: data) {
              summary = "weekId=\(bucket.weekId), wordsTotal=\(bucket.wordsTotal), vnWords=\(bucket.vnWordCounts.count)"
            }
          } else if let s = try? JSONDecoder.statsConfigured.decode(UsageSummary.self, from: data) {
            summary = "weekId=\(s.weekId), wordsTotal=\(s.wordsTotal), vnWords=\(s.topVietnameseWords.count)"
          }
        }
        lines.append("  \(url.lastPathComponent) (\(size) bytes) — \(summary)")
      }
      return lines.joined(separator: "\n")
    }
  }

  /// Combined snapshot (current + historical) for export/backup.
  /// 1.7.6+ deprecated — chỉ giữ cho backward-compat. Production export
  /// dùng `allWeekBucketsForExport()` để lưu full data (vnWordCounts, ...).
  func allSummariesForExport() -> [UsageSummary] {
    [currentWeekSummary()] + historicalSummaries()
  }

  /// 1.7.6: full-fidelity export. Trả về current week + historical weeks
  /// dưới dạng `WeekBucketExport` chứa toàn bộ raw frequency tables, streaks,
  /// phrase counters, per-app language tracking. Dùng cho backup/restore.
  func allWeekBucketsForExport() -> [WeekBucketExport] {
    queue.sync {
      rotateIfNeeded()
      var out: [WeekBucketExport] = [counters.toExport()]
      let currentWeekFile = "\(WeekBucket.currentWeekId()).json"
      let urls = (try? FileManager.default.contentsOfDirectory(
        at: storageDir, includingPropertiesForKeys: nil
      )) ?? []
      for url in urls where url.pathExtension == "json"
                           && url.lastPathComponent != "current.json"
                           && url.lastPathComponent != currentWeekFile {
        // Cố gắng decode file lịch sử thành WeekBucket trước. Nếu cũ chỉ
        // có UsageSummary thì decode fallback và "promote" sang export
        // với raw maps rỗng (lossy nhưng không crash).
        guard let data = try? Data(contentsOf: url) else { continue }
        if let bucket = try? JSONDecoder.statsConfigured.decode(WeekBucket.self, from: data) {
          out.append(bucket.toExport())
        } else if let summary = try? JSONDecoder.statsConfigured.decode(UsageSummary.self, from: data) {
          out.append(WeekBucketExport(
            weekId: summary.weekId, weekEnd: summary.weekEnd,
            wordsTotal: summary.wordsTotal,
            wordsKeptVietnamese: summary.wordsKeptVietnamese,
            wordsRestoredEnglish: summary.wordsRestoredEnglish,
            wordsKeptRaw: summary.wordsKeptRaw,
            wordsSuggested: summary.wordsSuggested,
            smartSwitchFires: summary.smartSwitchFires,
            typoCorrectionsApplied: summary.typoCorrectionsApplied,
            vnWordCounts: Dictionary(uniqueKeysWithValues: summary.topVietnameseWords.map { ($0.word, $0.count) }),
            enWordCounts: Dictionary(uniqueKeysWithValues: summary.topEnglishWords.map { ($0.word, $0.count) }),
            appCounts: Dictionary(uniqueKeysWithValues: summary.topApps.map { ($0.word, $0.count) }),
            vnKeepStreak: [:], enRestoreStreak: [:],
            vnPhraseCounts2: [:], vnPhraseCounts3: [:],
            appLanguageVnCounts: [:], appLanguageEnCounts: [:], appLanguageDays: [:]
          ))
        }
      }
      return out
    }
  }

  /// 1.7.6: restore stats từ backup. Match current weekId → load thành
  /// in-memory `counters`. Các tuần khác → ghi file `<weekId>.json` vào
  /// storageDir (atomic). Caller (UserDataMigration) gọi sau khi apply
  /// Defaults. Trả về số tuần restored thành công.
  @discardableResult
  func restoreFromBackup(_ buckets: [WeekBucketExport]) -> Int {
    queue.sync {
      var restored = 0
      let currentId = WeekBucket.currentWeekId()
      for export in buckets {
        let bucket = WeekBucket(from: export)
        if bucket.weekId == currentId {
          counters = bucket
          flushNow()
          restored += 1
        } else {
          // Tuần đã đóng — ghi vào file riêng.
          let url = storageDir.appendingPathComponent("\(bucket.weekId).json")
          if let data = try? JSONEncoder.indented.encode(bucket) {
            do {
              try data.write(to: url, options: .atomic)
              restored += 1
            } catch {
              os_log("UsageStatistics.restoreFromBackup: write %{public}@ failed: %{public}@",
                     log: log, type: .error, bucket.weekId, error.localizedDescription)
            }
          }
        }
      }
      return restored
    }
  }

  /// Aggregate `topVietnameseWords` qua tất cả tuần (current + historical),
  /// trả về list (word, totalCount) sắp xếp giảm dần, lọc count >= threshold.
  /// Dùng cho "Gợi ý từ Thống kê" trong MacroView (1.5.5+).
  func aggregatedTopVietnameseWords(threshold: Int = 10) -> [WordCount] {
    var totals: [String: Int] = [:]
    let allWeeks = [currentWeekSummary()] + historicalSummaries()
    for week in allWeeks {
      for wc in week.topVietnameseWords {
        totals[wc.word, default: 0] += wc.count
      }
    }
    return totals
      .filter { $0.value >= threshold }
      .map { WordCount(word: $0.key, count: $0.value) }
      .sorted { $0.count > $1.count }
  }

  /// 1.6.1: Aggregate top phrases (2 hoặc 3 từ tiếng Việt liền) qua
  /// current week. Chỉ gồm cụm có nghĩa (mọi token là từ VN hợp lệ).
  /// Dùng cho Macro suggestion UI và phrase-aware prediction.
  func aggregatedTopVietnamesePhrases(
    minWords: Int = 2, maxWords: Int = 3, threshold: Int = 10
  ) -> [WordCount] {
    queue.sync {
      var out: [String: Int] = [:]
      if minWords <= 2 && maxWords >= 2 {
        for (phrase, count) in counters.vnPhraseCounts2 where count >= threshold {
          out[phrase] = count
        }
      }
      if minWords <= 3 && maxWords >= 3 {
        for (phrase, count) in counters.vnPhraseCounts3 where count >= threshold {
          out[phrase] = count
        }
      }
      return out
        .map { WordCount(word: $0.key, count: $0.value) }
        .sorted { $0.count > $1.count }
    }
  }

  /// Gợi ý từ tiếp theo từ cụm 3 từ user hay gõ (vd "kính gửi" → "anh").
  /// Chỉ dùng phrase counters đã lọc có nghĩa.
  func phraseCompletionHints(prev2: String, prev1: String) -> [String: Int] {
    let p2 = prev2.lowercased()
    let p1 = prev1.lowercased()
    let prefix = "\(p2) \(p1) "
    guard !p2.isEmpty, !p1.isEmpty else { return [:] }
    return queue.sync {
      var hints: [String: Int] = [:]
      for (phrase, count) in counters.vnPhraseCounts3 where phrase.hasPrefix(prefix) {
        let remainder = phrase.dropFirst(prefix.count)
        guard let nextWord = remainder.split(separator: " ", omittingEmptySubsequences: true).first
        else { continue }
        hints[String(nextWord), default: 0] += count
      }
      return hints
    }
  }

  /// 1.7.9: Aggregate top phrases EN/raw (2 hoặc 3 từ ngoài tiếng Việt liền).
  /// Mirror logic của aggregatedTopVietnamesePhrases.
  func aggregatedTopEnglishPhrases(
    minWords: Int = 2, maxWords: Int = 3, threshold: Int = 3
  ) -> [WordCount] {
    queue.sync {
      var out: [String: Int] = [:]
      if minWords <= 2 && maxWords >= 2 {
        for (phrase, count) in counters.enPhraseCounts2 where count >= threshold {
          out[phrase] = count
        }
      }
      if minWords <= 3 && maxWords >= 3 {
        for (phrase, count) in counters.enPhraseCounts3 where count >= threshold {
          out[phrase] = count
        }
      }
      return out
        .map { WordCount(word: $0.key, count: $0.value) }
        .sorted { $0.count > $1.count }
    }
  }

  /// Aggregate `topApps` (bundle ID) qua tất cả tuần, dùng cho "Gợi ý từ
  /// Thống kê" trong SmartSwitchView (1.5.5+). `word` chứa bundle ID.
  func aggregatedTopApps(threshold: Int = 10) -> [WordCount] {
    var totals: [String: Int] = [:]
    let allWeeks = [currentWeekSummary()] + historicalSummaries()
    for week in allWeeks {
      for wc in week.topApps {
        totals[wc.word, default: 0] += wc.count
      }
    }
    return totals
      .filter { $0.value >= threshold }
      .map { WordCount(word: $0.key, count: $0.value) }
      .sorted { $0.count > $1.count }
  }

  /// 1.7.0: Auto-learn Smart Switch state per-app từ stats current week.
  /// Threshold: ≥5 ngày dataset, ≥5 commit/ngày trung bình (~35/tuần),
  /// ratio language ≥75% (Tiếng Việt hoặc Tiếng Anh).
  /// User-set entries (source=.user) KHÔNG bị override.
  /// Returns: map bundleId → suggested state cho các app pass tất cả gates.
  func computeSmartSwitchAutoLearn() -> [String: AppSmartSwitchState] {
    queue.sync {
      var out: [String: AppSmartSwitchState] = [:]
      for bundleId in Set(counters.appLanguageVnCounts.keys).union(counters.appLanguageEnCounts.keys) {
        let vn = counters.appLanguageVnCounts[bundleId] ?? 0
        let en = counters.appLanguageEnCounts[bundleId] ?? 0
        let total = vn + en
        guard total > 0 else { continue }
        let days = counters.appLanguageDays[bundleId]?.count ?? 0
        let avgPerDay = days > 0 ? Double(total) / Double(days) : 0
        // Gate: ≥5 ngày dataset spread, ≥5 commit/ngày avg
        // v1.7.2: lower threshold ≥1 day, ≥5 commit/day (was ≥5 days, ≥5/day).
        // Combined với daily check (thay weekly) cho auto-learn phản hồi nhanh hơn.
        guard days >= 1, avgPerDay >= 5 else { continue }
        let ratio = Double(vn) / Double(total)
        if ratio >= 0.75 {
          out[bundleId] = .vietnameseMode
        } else if ratio <= 0.25 {
          out[bundleId] = .englishMode
        }
        // else: ambiguous, không auto-set
      }
      return out
    }
  }

  /// Promote frequently-confirmed words into the user's personal dictionary.
  /// Returns the summary of the closed week so the UI can show what changed.
  ///
  /// Called once per app launch (with a guard that runs the closing logic
  /// at most once per ISO week). Also exposed publicly so a Settings button
  /// can trigger it on demand for the previous week.
  ///
  /// Promotion rules (conservative, to avoid surprising the user):
  /// - Vietnamese word seen ≥ `promotionThreshold` times AND `kept` every time
  ///   → add to `userKeepWords` (so future occurrences are never auto-restored
  ///     to English).
  /// - English word seen ≥ `promotionThreshold` times AND restored every time
  ///   → add to `userAllowWords` (so future occurrences are recognised as
  ///     English faster, even if not in the embedded lexicon).
  /// - Existing user entries are never touched, never removed.
  /// - A hardcoded ignore list (the lexicon's `keep[]`) is respected.
  @discardableResult
  func performWeeklyFeedback() -> UsageSummary {
    queue.sync {
      rotateIfNeeded()
      // 1.6.0: KHÔNG auto-promote vào userAllowWords / userKeepWords nữa.
      // Compute pending suggestions cho user review qua sheet.
      let suggestions = computePendingSuggestions()
      appendToPendingSuggestions(suggestions)
      // Legacy promoted fields in UsageSummary giữ rỗng — pending list
      // là nơi mới track promotions.
      let summary = counters.summary(promotedAllow: [], promotedKeep: [])
      persistCurrentWeek(includingPromotionLog: PromotionResult(allow: [], keep: []))
      return summary
    }
  }

  /// Stat category để xoá cụm từ cụ thể (1.5.9+).
  enum StatCategory {
    case vietnamese  // Top tiếng Việt
    case english     // Top tiếng Anh / raw
    case app         // Top app
  }

  /// Xoá 1 cụm từ / app khỏi current week's counters. Sau khi xoá:
  /// - Top words/apps list refresh, từ đó biến mất.
  /// - Streak (vnKeepStreak / enRestoreStreak) cũng reset cho từ đó —
  ///   tránh personal-dictionary auto-promotion sai sau khi user explicit
  ///   từ chối từ đó.
  /// - Historical (closed) weeks không đụng tới — đó là snapshot lịch sử,
  ///   không sửa được.
  /// - Total counters (wordsTotal, wordsKeptVietnamese, ...) không trừ,
  ///   vì đã được dùng để tính nhiều thứ khác — chỉ remove khỏi top list.
  func removeFromCurrentWeek(word: String, category: StatCategory) {
    queue.async { [weak self] in
      guard let self else { return }
      self.rotateIfNeeded()
      switch category {
      case .vietnamese:
        self.counters.vnWordCounts.removeValue(forKey: word)
        self.counters.vnKeepStreak.removeValue(forKey: word)
      case .english:
        self.counters.enWordCounts.removeValue(forKey: word)
        self.counters.enRestoreStreak.removeValue(forKey: word)
      case .app:
        self.counters.appCounts.removeValue(forKey: word)
      }
      self.scheduleFlush()
    }
  }

  /// Synchronous flush — force write current counters to disk ngay
  /// trước khi return. Gọi từ `applicationWillTerminate` để đảm bảo
  /// in-memory state không mất khi app exit (vd Sparkle restart sau
  /// install). Bình thường `scheduleFlush()` debounce 10s là đủ, nhưng
  /// terminate race không thể đợi.
  func flushSynchronously() {
    queue.sync { [weak self] in
      self?.flushNow()
    }
  }

  /// Clear *all* stats (current week + history). Triggered from Settings.
  /// 1.9.0: xóa files TRƯỚC, reset counters SAU. Nếu crash giữa chừng,
  /// counters in-memory vẫn match disk state (cả 2 đều có data cũ hoặc đã
  /// xóa). Trước v1.9 reset counters trước → crash mid-loop → memory empty
  /// nhưng disk còn files → inconsistent next launch.
  /// Pending flush task cancel để tránh ghi lại current.json sau clear.
  func clearAll() {
    queue.sync {
      pendingFlushItem?.cancel()
      pendingFlushItem = nil
      let urls = (try? FileManager.default.contentsOfDirectory(
        at: storageDir, includingPropertiesForKeys: nil
      )) ?? []
      for url in urls {
        try? FileManager.default.removeItem(at: url)
      }
      counters = WeekBucket(weekId: counters.weekId, weekEnd: counters.weekEnd)
      recentVnQueue.removeAll()
      recentEnQueue.removeAll()
    }
  }

  // MARK: - Internal: bucket + rotation

  private struct WeekBucket: Codable {
    var weekId: String
    var weekEnd: Date

    var wordsTotal: Int = 0
    var wordsKeptVietnamese: Int = 0
    var wordsRestoredEnglish: Int = 0
    var wordsKeptRaw: Int = 0
    var wordsSuggested: Int = 0
    var smartSwitchFires: Int = 0
    var typoCorrectionsApplied: Int = 0

    var vnWordCounts: [String: Int] = [:]
    var enWordCounts: [String: Int] = [:]
    var appCounts: [String: Int] = [:]

    /// Track "kept" / "restored" event counts per token so we have a
    /// confidence signal for personal-dictionary promotion.
    var vnKeepStreak: [String: Int] = [:]   // word → times kept
    var enRestoreStreak: [String: Int] = [:] // raw → times restored

    /// 1.6.1: phrase counters (chuỗi 2-3 từ tiếng Việt liền kề user gõ).
    /// Dùng cho macro suggestion — đề xuất viết tắt cho cụm hay gõ.
    /// Chỉ tăng khi commit liền nhau là `.keepVietnamese`; ngắt khi xen
    /// English / raw / Smart Switch.
    var vnPhraseCounts2: [String: Int] = [:]   // "công ty" → count
    var vnPhraseCounts3: [String: Int] = [:]   // "kính gửi anh" → count

    /// 1.7.9: phrase counters cho EN/raw — đối ứng vnPhraseCounts.
    /// Chỉ tăng khi commit liền nhau là `.restoreRawEnglish` hoặc `.keepRaw`;
    /// ngắt khi xen VN / suggest / Smart Switch.
    var enPhraseCounts2: [String: Int] = [:]   // "machine learning" → count
    var enPhraseCounts3: [String: Int] = [:]   // "thank you so" → count

    /// 1.7.0: per-app language tracking — đếm số commit Tiếng Việt vs
    /// Tiếng Anh trong từng app. Dùng cho Smart Switch auto-learn:
    /// nếu app dùng đủ data và 1 ngôn ngữ chiếm ≥75%, auto-set state.
    /// `vn` = .keepVietnamese commits; `en` = .restoreRawEnglish + .keepRaw.
    /// `days` = set ngày-trong-tuần đã ghi (1-7, ISO Monday=1) → để check
    /// dataset spread ≥5 ngày.
    var appLanguageVnCounts: [String: Int] = [:]
    var appLanguageEnCounts: [String: Int] = [:]
    var appLanguageDays: [String: [Int]] = [:]  // bundle → list of weekday (1-7)

    init(weekId: String = WeekBucket.currentWeekId(),
         weekEnd: Date = WeekBucket.endOfCurrentWeek()) {
      self.weekId = weekId
      self.weekEnd = weekEnd
    }

    /// 1.7.6: build từ WeekBucketExport (file backup) → in-memory bucket.
    init(from export: WeekBucketExport) {
      self.weekId = export.weekId.isEmpty ? WeekBucket.currentWeekId() : export.weekId
      self.weekEnd = export.weekEnd
      self.wordsTotal = export.wordsTotal
      self.wordsKeptVietnamese = export.wordsKeptVietnamese
      self.wordsRestoredEnglish = export.wordsRestoredEnglish
      self.wordsKeptRaw = export.wordsKeptRaw
      self.wordsSuggested = export.wordsSuggested
      self.smartSwitchFires = export.smartSwitchFires
      self.typoCorrectionsApplied = export.typoCorrectionsApplied
      self.vnWordCounts = export.vnWordCounts
      self.enWordCounts = export.enWordCounts
      self.appCounts = export.appCounts
      self.vnKeepStreak = export.vnKeepStreak
      self.enRestoreStreak = export.enRestoreStreak
      self.vnPhraseCounts2 = export.vnPhraseCounts2
      self.vnPhraseCounts3 = export.vnPhraseCounts3
      // 1.7.9: EN phrase counters từ export.
      self.enPhraseCounts2 = export.enPhraseCounts2
      self.enPhraseCounts3 = export.enPhraseCounts3
      self.appLanguageVnCounts = export.appLanguageVnCounts
      self.appLanguageEnCounts = export.appLanguageEnCounts
      self.appLanguageDays = export.appLanguageDays
    }

    /// 1.7.6: snapshot ra WeekBucketExport (file backup).
    func toExport() -> WeekBucketExport {
      WeekBucketExport(
        weekId: weekId, weekEnd: weekEnd,
        wordsTotal: wordsTotal,
        wordsKeptVietnamese: wordsKeptVietnamese,
        wordsRestoredEnglish: wordsRestoredEnglish,
        wordsKeptRaw: wordsKeptRaw,
        wordsSuggested: wordsSuggested,
        smartSwitchFires: smartSwitchFires,
        typoCorrectionsApplied: typoCorrectionsApplied,
        vnWordCounts: vnWordCounts,
        enWordCounts: enWordCounts,
        appCounts: appCounts,
        vnKeepStreak: vnKeepStreak,
        enRestoreStreak: enRestoreStreak,
        vnPhraseCounts2: vnPhraseCounts2,
        vnPhraseCounts3: vnPhraseCounts3,
        enPhraseCounts2: enPhraseCounts2,
        enPhraseCounts3: enPhraseCounts3,
        appLanguageVnCounts: appLanguageVnCounts,
        appLanguageEnCounts: appLanguageEnCounts,
        appLanguageDays: appLanguageDays
      )
    }

    enum CodingKeys: String, CodingKey {
      case weekId, weekEnd
      case wordsTotal, wordsKeptVietnamese, wordsRestoredEnglish
      case wordsKeptRaw, wordsSuggested, smartSwitchFires
      case typoCorrectionsApplied
      case vnWordCounts, enWordCounts, appCounts
      case vnKeepStreak, enRestoreStreak
      case vnPhraseCounts2, vnPhraseCounts3   // 1.6.1+
      case enPhraseCounts2, enPhraseCounts3   // 1.7.9+
      case appLanguageVnCounts, appLanguageEnCounts, appLanguageDays  // 1.7.0+
    }

    /// 1.6.0: backward-compat Codable. Mọi field optional với fallback
    /// default — đảm bảo file `current.json` từ phiên bản cũ (thiếu
    /// field) hoặc mới hơn (extra field SwiftUI ignore) đều decode được
    /// thay vì throw → tạo bucket rỗng → data "biến mất".
    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      self.weekId = try c.decodeIfPresent(String.self, forKey: .weekId)
                    ?? WeekBucket.currentWeekId()
      self.weekEnd = try c.decodeIfPresent(Date.self, forKey: .weekEnd)
                    ?? WeekBucket.endOfCurrentWeek()
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
      // 1.6.1: phrase counters — luôn optional (file v1.5.x/1.6.0 không có).
      self.vnPhraseCounts2 = try c.decodeIfPresent([String: Int].self, forKey: .vnPhraseCounts2) ?? [:]
      self.vnPhraseCounts3 = try c.decodeIfPresent([String: Int].self, forKey: .vnPhraseCounts3) ?? [:]
      // 1.7.9: EN phrase counters — optional (file < v1.7.9 không có).
      self.enPhraseCounts2 = try c.decodeIfPresent([String: Int].self, forKey: .enPhraseCounts2) ?? [:]
      self.enPhraseCounts3 = try c.decodeIfPresent([String: Int].self, forKey: .enPhraseCounts3) ?? [:]
      // 1.7.0: per-app language tracking — optional (file < v1.7.0 không có).
      self.appLanguageVnCounts = try c.decodeIfPresent([String: Int].self, forKey: .appLanguageVnCounts) ?? [:]
      self.appLanguageEnCounts = try c.decodeIfPresent([String: Int].self, forKey: .appLanguageEnCounts) ?? [:]
      self.appLanguageDays = try c.decodeIfPresent([String: [Int]].self, forKey: .appLanguageDays) ?? [:]
    }

    func summary(promotedAllow: [String], promotedKeep: [String]) -> UsageSummary {
      func top(_ counts: [String: Int], n: Int) -> [WordCount] {
        counts.sorted { lhs, rhs in
          lhs.value > rhs.value
            || (lhs.value == rhs.value && lhs.key < rhs.key)
        }
        .prefix(n)
        .map { WordCount(word: $0.key, count: $0.value) }
      }
      // 1.7.4: top từ tiếng Việt / tiếng Anh = top 10% theo count, không
      // cap cứng nữa (cũ là n=20). Trimmed bởi `trimDict` ở line ~695
      // nên upper bound vẫn 500 unique tokens. Min 1 entry nếu có data
      // (Int(ceil(N*0.1)) đảm bảo ≥1 khi N≥1).
      func topPercent(_ counts: [String: Int], percent: Double) -> [WordCount] {
        let sorted = counts.sorted { lhs, rhs in
          lhs.value > rhs.value
            || (lhs.value == rhs.value && lhs.key < rhs.key)
        }
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

    static func currentWeekId() -> String {
      let cal = Calendar(identifier: .iso8601)
      let now = Date()
      let year = cal.component(.yearForWeekOfYear, from: now)
      let week = cal.component(.weekOfYear, from: now)
      return String(format: "%04d-W%02d", year, week)
    }

    static func endOfCurrentWeek() -> Date {
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

  private func loadCurrentWeekIfNeeded() {
    let url = storageDir.appendingPathComponent("current.json")
    guard let data = try? Data(contentsOf: url) else { return }
    guard let loaded = try? JSONDecoder.statsConfigured.decode(WeekBucket.self, from: data) else {
      os_log("UsageStatistics: current.json decode failed; preserving in-memory state",
             log: log, type: .error)
      return
    }
    // 1.6.1: Always load, then let rotateIfNeeded handle stale weeks.
    // Trước: nếu loaded.weekId != currentWeekId thì skip — data tuần
    // trước bị bỏ rơi và lần flush kế tiếp ghi đè empty bucket lên
    // current.json → mất hết stats khi upgrade qua biên tuần ISO.
    queue.sync {
      counters = loaded
      rotateIfNeeded()
    }
  }

  private func rotateIfNeeded() {
    let current = WeekBucket.currentWeekId()
    guard counters.weekId != current else { return }

    // Persist the closing week as its own file, with no further promotion
    // log (caller of `performWeeklyFeedback` decides whether to promote).
    let closedURL = storageDir.appendingPathComponent("\(counters.weekId).json")
    if let data = try? JSONEncoder.indented.encode(
      counters.summary(promotedAllow: [], promotedKeep: [])
    ) {
      try? data.write(to: closedURL, options: .atomic)
    }
    os_log("UsageStatistics: rotated week %{public}@ → %{public}@",
           log: log, type: .info, counters.weekId, current)

    // Reset counters for the new week.
    counters = WeekBucket()
    try? FileManager.default.removeItem(at: storageDir.appendingPathComponent("current.json"))

    pruneOldWeeks()
  }

  private func pruneOldWeeks() {
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: storageDir, includingPropertiesForKeys: nil
    )) ?? []
    let closed = urls
      .filter { $0.pathExtension == "json" && $0.lastPathComponent != "current.json" }
      .sorted { $0.lastPathComponent > $1.lastPathComponent }
    for url in closed.dropFirst(maxWeeksRetained) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  // MARK: - Internal: bookkeeping

  private func applyCommit(
    decision: SpellDecision,
    rawInput: String,
    transformed: String,
    appBundleId: String?,
    typoCorrectionApplied: Bool,
    needsRecovery: Bool
  ) {
    rotateIfNeeded()
    counters.wordsTotal += 1

    let rawToken = rawInput.normalizedDictionaryToken
    let vnToken = transformed.normalizedDictionaryToken

    // 1.7.4: nếu commit qua đường recovery (raw không transform được
    // thành VN hợp lệ, hoặc parser ngắt do stopProcessing), KHÔNG bơm
    // vào per-token counters để khỏi nhiễu top từ + đề xuất personal
    // dictionary. Vẫn cộng vào aggregate counts (wordsTotal/category)
    // để stats tổng vẫn phản ánh hoạt động gõ.
    let trackPerToken = !needsRecovery

    switch decision {
    case .keepVietnamese:
      counters.wordsKeptVietnamese += 1
      if trackPerToken, !vnToken.isEmpty {
        counters.vnWordCounts[vnToken, default: 0] += 1
        counters.vnKeepStreak[vnToken, default: 0] += 1
        // 1.6.1: phrase tracking — append to sliding window + tăng counter.
        recordVnPhraseTransition(append: vnToken)
      } else {
        recentVnQueue.removeAll()
      }
      // 1.7.9: xen VN → reset EN phrase chain.
      recentEnQueue.removeAll()
    case .restoreRawEnglish:
      counters.wordsRestoredEnglish += 1
      if trackPerToken, !rawToken.isEmpty {
        counters.enWordCounts[rawToken, default: 0] += 1
        counters.enRestoreStreak[rawToken, default: 0] += 1
        // 1.7.9: phrase tracking EN.
        recordEnPhraseTransition(append: rawToken)
      } else {
        recentEnQueue.removeAll()
      }
      recentVnQueue.removeAll()
    case .keepRaw:
      counters.wordsKeptRaw += 1
      if trackPerToken, !rawToken.isEmpty {
        // Track raw too — could be a name or technical term the user uses
        // often. They become candidates for personal dictionary later.
        counters.enWordCounts[rawToken, default: 0] += 1
        // 1.7.9: keepRaw cũng đóng góp vào EN phrase chain.
        recordEnPhraseTransition(append: rawToken)
      } else {
        recentEnQueue.removeAll()
      }
      recentVnQueue.removeAll()
    case .suggest:
      counters.wordsSuggested += 1
      // Suggest không reset queue (chưa commit cuối cùng).
    }

    if typoCorrectionApplied {
      counters.typoCorrectionsApplied += 1
    }
    if let app = appBundleId, !app.isEmpty {
      counters.appCounts[app, default: 0] += 1
      // 1.7.0: per-app language tracking cho Smart Switch auto-learn.
      switch decision {
      case .keepVietnamese:
        counters.appLanguageVnCounts[app, default: 0] += 1
      case .restoreRawEnglish, .keepRaw:
        counters.appLanguageEnCounts[app, default: 0] += 1
      case .suggest:
        break
      }
      // Track which weekdays user typed in this app (for dataset spread).
      let today = Calendar(identifier: .iso8601).component(.weekday, from: Date())
      var days = counters.appLanguageDays[app] ?? []
      if !days.contains(today) { days.append(today) }
      counters.appLanguageDays[app] = days
    }

    // Cap the per-bucket sizes so a runaway map can't blow disk.
    trimDict(&counters.vnWordCounts, max: 500)
    trimDict(&counters.enWordCounts, max: 500)
    trimDict(&counters.vnPhraseCounts2, max: 300)
    trimDict(&counters.vnPhraseCounts3, max: 300)
    // 1.7.9: cap EN phrase counters tương tự.
    trimDict(&counters.enPhraseCounts2, max: 300)
    trimDict(&counters.enPhraseCounts3, max: 300)

    scheduleFlush()
  }

  /// 1.6.1: sliding window cập nhật phrase counters. Gọi từ `applyCommit`
  /// mỗi khi commit `.keepVietnamese` thành công. Chỉ ghi cụm có nghĩa.
  private func recordVnPhraseTransition(append token: String) {
    recentVnQueue.append(token)
    if recentVnQueue.count > 3 {
      recentVnQueue.removeFirst(recentVnQueue.count - 3)
    }
    if recentVnQueue.count >= 2 {
      let words2 = Array(recentVnQueue.suffix(2))
      if Self.isMeaningfulVietnamesePhrase(words2) {
        let phrase2 = words2.joined(separator: " ")
        counters.vnPhraseCounts2[phrase2, default: 0] += 1
      }
    }
    if recentVnQueue.count >= 3 {
      let words3 = Array(recentVnQueue.suffix(3))
      if Self.isMeaningfulVietnamesePhrase(words3) {
        let phrase3 = words3.joined(separator: " ")
        counters.vnPhraseCounts3[phrase3, default: 0] += 1
      }
    }
  }

  /// Cụm tiếng Việt có nghĩa: mọi token ≥2 ký tự và nằm trong từ điển VN
  /// (hoặc user keep/allow). Loại chuỗi ngẫu nhiên / xen tiếng Anh.
  static func isMeaningfulVietnamesePhrase(_ words: [String]) -> Bool {
    guard words.count >= 2 else { return false }
    let allowSet = Set(Defaults[.userAllowWords].map { $0.lowercased() })
    let keepSet = Set(Defaults[.userKeepWords].map { $0.lowercased() })
    for word in words {
      let lower = word.lowercased()
      guard lower.count >= 2 else { return false }
      if keepSet.contains(lower) || allowSet.contains(lower) { continue }
      if !LexiconManager.shared.isVietnameseWord(lower) { return false }
    }
    return true
  }

  /// 1.7.9: sliding window phrase counters cho EN/raw. Gọi từ `applyCommit`
  /// khi commit `.restoreRawEnglish` hoặc `.keepRaw`.
  private func recordEnPhraseTransition(append token: String) {
    recentEnQueue.append(token)
    if recentEnQueue.count > 3 {
      recentEnQueue.removeFirst(recentEnQueue.count - 3)
    }
    if recentEnQueue.count >= 2 {
      let phrase2 = recentEnQueue.suffix(2).joined(separator: " ")
      counters.enPhraseCounts2[phrase2, default: 0] += 1
    }
    if recentEnQueue.count >= 3 {
      let phrase3 = recentEnQueue.suffix(3).joined(separator: " ")
      counters.enPhraseCounts3[phrase3, default: 0] += 1
    }
  }

  private func trimDict(_ dict: inout [String: Int], max: Int) {
    guard dict.count > max else { return }
    let keepers = dict.sorted { $0.value > $1.value }.prefix(max)
    dict = Dictionary(uniqueKeysWithValues: keepers.map { ($0.key, $0.value) })
  }

  private func scheduleFlush() {
    pendingFlushItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      self?.flushNow()
    }
    pendingFlushItem = item
    queue.asyncAfter(deadline: .now() + 10, execute: item)
  }

  private func flushNow() {
    let url = storageDir.appendingPathComponent("current.json")
    if let data = try? JSONEncoder.indented.encode(counters) {
      try? data.write(to: url, options: .atomic)
    }
  }

  // MARK: - Promotion (weekly feedback loop)

  struct PromotionResult: Equatable {
    let allow: [String]
    let keep: [String]
  }

  /// Pure-function core of the promotion logic. Exposed `internal` so tests
  /// can drive it without sharing process-wide `Defaults` state — the
  /// instance method below reads/writes Defaults and delegates here.
  ///
  /// - Parameters:
  ///   - enRestoreStreak: Map of `raw english token → times restored` within
  ///     the current week's bucket.
  ///   - vnKeepStreak: Map of `transformed VN word → times kept`.
  ///   - existingAllow / existingKeep / existingDeny: User's current
  ///     personal dictionary sets, already normalised.
  ///   - threshold: Min repeats before a token is eligible for promotion.
  ///   - maxBatch: Cap on promoted entries per category per call.
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
      // Only promote actual Vietnamese-looking words (contain at least one
      // diacritic / non-ASCII char). Otherwise the user already typed it as
      // pure ASCII and we'd be adding noise.
      let hasNonAscii = n.unicodeScalars.contains { $0.value > 127 }
      guard hasNonAscii else { continue }
      newKeep.append(n)
    }

    return PromotionResult(
      allow: Array(newAllow.prefix(maxBatch)),
      keep: Array(newKeep.prefix(maxBatch))
    )
  }

  /// 1.6.0: thay vì auto-write vào `userAllowWords` / `userKeepWords`,
  /// compute SUGGESTIONS và append vào `pendingDictSuggestions`. User
  /// review qua `PersonalDictSuggestionSheet` rồi chốt thêm hoặc bỏ qua.
  ///
  /// Filter:
  /// - Loại từ đã có trong `userAllowWords` / `userKeepWords` / `userDenyWords`.
  /// - Loại từ đã có trong built-in lexicon `LexiconManager.isVietnameseWord`
  ///   (cho keep — không cần override; cho allow — nếu là VN word thì sai
  ///   mục đích).
  /// - Note: filter "lỗi gõ" qua SuggestionService có thể thêm sau khi
  ///   verify API signature. MVP: chỉ check existing dictionaries.
  private func computePendingSuggestions() -> [PendingDictSuggestion] {
    let existingAllow = Set(Defaults[.userAllowWords].map { $0.normalizedDictionaryToken })
    let existingKeep = Set(Defaults[.userKeepWords].map { $0.normalizedDictionaryToken })
    let existingDeny = Set(Defaults[.userDenyWords].map { $0.normalizedDictionaryToken })
    let now = Date()
    var out: [PendingDictSuggestion] = []

    // 1.8.2: pre-build length-bucketed lexicon snapshot. Levenshtein chỉ
    // chạy trên candidates có độ dài ±maxDist từ word → tránh full scan
    // 9826 từ cho mỗi candidate. Saving ~50-100x cho weekly feedback pass.
    let enWordsByLen = enWordsByLengthSnapshot()

    // Allow candidates: enRestoreStreak ≥ threshold, ASCII-only.
    for (token, count) in counters.enRestoreStreak where count >= promotionThreshold {
      let n = token.normalizedDictionaryToken
      guard n.count >= 2, n.isASCIIAlphabeticWord else { continue }
      if existingAllow.contains(n) || existingDeny.contains(n) { continue }
      // Loại nếu LexiconManager nhận là tiếng Việt (sai mục đích allow).
      if LexiconManager.shared.isVietnameseWord(n) { continue }
      // 1.8.4: loại từ đã có trong built-in enLexicon — user không cần
      // promote "footer", "syntax", "abacus", ... vào Personal Dict vì
      // spell-check đã nhận diện sẵn. Tránh suggestion list trùng lặp.
      if LexiconManager.shared.isEnglishWord(n) { continue }
      // 1.7.x: bỏ qua chuỗi gõ ngẫu nhiên (asdfgh, xzcvbn...) — chỉ
      // promote nếu gần một từ tiếng Anh thực sự (Levenshtein ≤ ngưỡng
      // phụ thuộc độ dài) hoặc là từ exact-match trong lexicon.
      if looksLikeKeyboardMashing(n, enWordsByLen: enWordsByLen) { continue }
      out.append(PendingDictSuggestion(
        word: n, count: count, kind: .allow, suggestedAt: now
      ))
    }

    // Keep candidates: vnKeepStreak ≥ threshold, has non-ASCII diacritic.
    for (token, count) in counters.vnKeepStreak where count >= promotionThreshold {
      let n = token.normalizedDictionaryToken
      guard n.count >= 2 else { continue }
      if existingKeep.contains(n) || existingDeny.contains(n) { continue }
      let hasNonAscii = n.unicodeScalars.contains { $0.value > 127 }
      guard hasNonAscii else { continue }
      // Loại nếu đã có trong built-in vnLexicon — không cần override
      // (lexicon đã nhận là VN; userKeep chỉ cần cho từ riêng tư).
      if LexiconManager.shared.isVietnameseWord(n) { continue }
      out.append(PendingDictSuggestion(
        word: n, count: count, kind: .keep, suggestedAt: now
      ))
    }

    return out
  }

  /// Heuristic loại keyboard mashing: chuỗi không có nguyên âm, hoặc quá
  /// dài, hoặc cách quá xa mọi từ tiếng Anh đã biết. Distance threshold
  /// scale theo độ dài (max(2, n/4)) để cho phép typo dài hơn ở từ dài.
  ///
  /// 1.8.2: nhận `enWordsByLen` (length-bucketed dict) thay vì array flat
  /// → chỉ scan candidates có độ dài trong khoảng [n-maxDist, n+maxDist].
  /// Saving ~50-100x với enLexicon 9826 từ.
  private func looksLikeKeyboardMashing(_ word: String, enWordsByLen: [Int: [String]]) -> Bool {
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

  /// 1.8.2: snapshot enLexicon đã bucket theo length. Re-build mỗi lần
  /// `computePendingSuggestions` (call rate ~1/tuần) — không cần cache lâu
  /// dài để tránh stale khi lexicon update apply giữa các lần check.
  private func enWordsByLengthSnapshot() -> [Int: [String]] {
    let all = LexiconManager.shared.englishWordsSnapshot()
    var buckets: [Int: [String]] = [:]
    for w in all { buckets[w.count, default: []].append(w) }
    return buckets
  }

  /// Append suggestions vào pending list, dedupe theo `id`. Public-equivalent
  /// gọi trên main thread sau khi compute.
  private func appendToPendingSuggestions(_ new: [PendingDictSuggestion]) {
    DispatchQueue.main.async {
      var pending = Defaults[.pendingDictSuggestions]
      let existingIds = Set(pending.map { $0.id })
      for s in new where !existingIds.contains(s.id) {
        pending.append(s)
      }
      Defaults[.pendingDictSuggestions] = pending
    }
  }

  private func persistCurrentWeek(includingPromotionLog promoted: PromotionResult) {
    // 1.6.1: KHÔNG ghi `<currentWeekId>.json` cho tuần ĐANG chạy.
    // File per-week chỉ được tạo khi rotateIfNeeded() đóng một tuần
    // hoàn chỉnh. Trước đây ghi cả lúc đang chạy → file rỗng / nửa vời
    // lẫn vào `historicalSummaries()` và che lấp data thật.
    // promoted log hiện không dùng (1.6.0 đã chuyển sang pending suggestions).
    _ = promoted
    flushNow()
  }
}

// MARK: - File-private helpers

private extension JSONEncoder {
  static let indented: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    e.dateEncodingStrategy = .iso8601
    return e
  }()
}

private extension JSONDecoder {
  /// 1.6.3: decoder pre-configured để khớp `JSONEncoder.indented`:
  /// `.iso8601` date strategy. **CRITICAL FIX**: trước đây các call site
  /// dùng `JSONDecoder()` mặc định (date = Double timestamp). Vì encoder
  /// ghi ISO 8601 string, decode `weekEnd` luôn fail → `try?` nuốt lỗi →
  /// counters về default empty → tab Thống kê hiển thị toàn 0 sau khi
  /// cài bản mới. Đây là root cause thực sự của bug "mất hiển thị stats"
  /// (mạnh hơn cả các fix v1.6.1 trước đây — vốn không giải quyết được
  /// vì lỗi decode silent).
  static let statsConfigured: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()
}

// MARK: - UsageSummary date helpers (v1.7.0+)

extension UsageSummary {
  /// Parse `weekId` (vd "2026-W21") → (Monday, Sunday) Date range.
  /// Trả nil nếu format sai.
  static func dateRange(for weekId: String) -> (monday: Date, sunday: Date)? {
    let parts = weekId.split(separator: "-W")
    guard parts.count == 2,
          let year = Int(parts[0]),
          let week = Int(parts[1])
    else { return nil }
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2  // Monday
    var monComps = DateComponents()
    monComps.yearForWeekOfYear = year
    monComps.weekOfYear = week
    monComps.weekday = 2  // Monday
    monComps.hour = 0
    monComps.minute = 0
    guard let monday = cal.date(from: monComps) else { return nil }
    let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
    return (monday, sunday)
  }

  /// Format header tiếng Việt: "Tuần 21 năm 2026 (từ 18/05 đến 24/05/2026)".
  /// Fallback raw weekId nếu không parse được.
  static func vietnameseHeader(for weekId: String) -> String {
    guard let range = dateRange(for: weekId) else { return "Tuần — \(weekId)" }
    let parts = weekId.split(separator: "-W")
    guard parts.count == 2,
          let year = Int(parts[0]),
          let week = Int(parts[1])
    else { return "Tuần — \(weekId)" }
    let fDay = DateFormatter()
    fDay.dateFormat = "dd/MM"
    let fFull = DateFormatter()
    fFull.dateFormat = "dd/MM/yyyy"
    return "Tuần \(week) năm \(year) (từ \(fDay.string(from: range.monday)) đến \(fFull.string(from: range.sunday)))"
  }
}
