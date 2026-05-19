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
    typoCorrectionApplied: Bool = false
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
        typoCorrectionApplied: typoCorrectionApplied
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
  func allSummariesForExport() -> [UsageSummary] {
    [currentWeekSummary()] + historicalSummaries()
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
  /// current week. Historical weeks không track phrase (chỉ từ 1.6.1+).
  /// Dùng cho Macro suggestion UI.
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
  func clearAll() {
    queue.sync {
      counters = WeekBucket(weekId: counters.weekId, weekEnd: counters.weekEnd)
      let urls = (try? FileManager.default.contentsOfDirectory(
        at: storageDir, includingPropertiesForKeys: nil
      )) ?? []
      for url in urls {
        try? FileManager.default.removeItem(at: url)
      }
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

    init(weekId: String = WeekBucket.currentWeekId(),
         weekEnd: Date = WeekBucket.endOfCurrentWeek()) {
      self.weekId = weekId
      self.weekEnd = weekEnd
    }

    enum CodingKeys: String, CodingKey {
      case weekId, weekEnd
      case wordsTotal, wordsKeptVietnamese, wordsRestoredEnglish
      case wordsKeptRaw, wordsSuggested, smartSwitchFires
      case typoCorrectionsApplied
      case vnWordCounts, enWordCounts, appCounts
      case vnKeepStreak, enRestoreStreak
      case vnPhraseCounts2, vnPhraseCounts3   // 1.6.1+
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
        topVietnameseWords: top(vnWordCounts, n: 20),
        topEnglishWords: top(enWordCounts, n: 20),
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
    typoCorrectionApplied: Bool
  ) {
    rotateIfNeeded()
    counters.wordsTotal += 1

    let rawToken = rawInput.normalizedDictionaryToken
    let vnToken = transformed.normalizedDictionaryToken

    switch decision {
    case .keepVietnamese:
      counters.wordsKeptVietnamese += 1
      if !vnToken.isEmpty {
        counters.vnWordCounts[vnToken, default: 0] += 1
        counters.vnKeepStreak[vnToken, default: 0] += 1
        // 1.6.1: phrase tracking — append to sliding window + tăng counter.
        recordVnPhraseTransition(append: vnToken)
      } else {
        recentVnQueue.removeAll()
      }
    case .restoreRawEnglish:
      counters.wordsRestoredEnglish += 1
      if !rawToken.isEmpty {
        counters.enWordCounts[rawToken, default: 0] += 1
        counters.enRestoreStreak[rawToken, default: 0] += 1
      }
      recentVnQueue.removeAll()
    case .keepRaw:
      counters.wordsKeptRaw += 1
      if !rawToken.isEmpty {
        // Track raw too — could be a name or technical term the user uses
        // often. They become candidates for personal dictionary later.
        counters.enWordCounts[rawToken, default: 0] += 1
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
    }

    // Cap the per-bucket sizes so a runaway map can't blow disk.
    trimDict(&counters.vnWordCounts, max: 500)
    trimDict(&counters.enWordCounts, max: 500)
    trimDict(&counters.vnPhraseCounts2, max: 300)
    trimDict(&counters.vnPhraseCounts3, max: 300)

    scheduleFlush()
  }

  /// 1.6.1: sliding window cập nhật phrase counters. Gọi từ `applyCommit`
  /// mỗi khi commit `.keepVietnamese` thành công.
  private func recordVnPhraseTransition(append token: String) {
    recentVnQueue.append(token)
    if recentVnQueue.count > 3 {
      recentVnQueue.removeFirst(recentVnQueue.count - 3)
    }
    if recentVnQueue.count >= 2 {
      let phrase2 = recentVnQueue.suffix(2).joined(separator: " ")
      counters.vnPhraseCounts2[phrase2, default: 0] += 1
    }
    if recentVnQueue.count >= 3 {
      let phrase3 = recentVnQueue.suffix(3).joined(separator: " ")
      counters.vnPhraseCounts3[phrase3, default: 0] += 1
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

    // Allow candidates: enRestoreStreak ≥ threshold, ASCII-only.
    for (token, count) in counters.enRestoreStreak where count >= promotionThreshold {
      let n = token.normalizedDictionaryToken
      guard n.count >= 2, n.isASCIIAlphabeticWord else { continue }
      if existingAllow.contains(n) || existingDeny.contains(n) { continue }
      // Loại nếu LexiconManager nhận là tiếng Việt (sai mục đích allow).
      if LexiconManager.shared.isVietnameseWord(n) { continue }
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
