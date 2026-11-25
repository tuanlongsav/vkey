//
//  UsageStatistics.swift
//  vkey
//
//  Thread-safe local-only usage tracking facade coordinating StatsStore,
//  PhraseTracker, PersonalDictMiner, and SmartSwitchLearner.
//

import Carbon  // IsSecureEventInputEnabled (HIToolbox)
import Defaults
import Foundation
import os.log

private let log = OSLog(subsystem: "dev.longht.vkey", category: "UsageStatistics")

/// Tracker singleton. Stateful but thread-safe via a serial queue.
final class UsageStatistics {

  typealias StatCategory = UsageStatCategory
  typealias PromotionResult = PersonalDictMiner.PromotionResult

  static let shared = UsageStatistics()

  private var counters = WeekBucket()
  private var phraseTracker = PhraseTracker()
  private let store: StatsStore
  private let queue = DispatchQueue(label: "dev.longht.vkey.stats", qos: .utility)
  private let isSecureInput: () -> Bool
  private var pendingFlushItem: DispatchWorkItem?
  private let promotionThreshold = 5

  var storageDir: URL { store.storageDir }

  init(
    storageDir: URL? = nil,
    isSecureInput: @escaping () -> Bool = UsageStatistics.isSecureInputActive
  ) {
    self.store = StatsStore(storageDir: storageDir, maxWeeksRetained: 4)
    self.isSecureInput = isSecureInput
    if let loaded = store.loadCurrentWeek() {
      queue.sync {
        counters = loaded
        rotateIfNeeded()
      }
    }
  }

  // MARK: - Static Utilities

  static func excludeFromBackup(_ url: URL) {
    StatsStore.excludeFromBackup(url)
  }

  static func isValidWeekId(_ weekId: String) -> Bool {
    WeekBucket.isValidWeekId(weekId)
  }

  static func isSecureInputActive() -> Bool {
    IsSecureEventInputEnabled()
  }

  static func isMeaningfulVietnamesePhrase(_ words: [String]) -> Bool {
    PhraseTracker.isMeaningfulVietnamesePhrase(words)
  }

  static func smartSwitchSuggestion(vn: Int, en: Int, days: Int) -> AppSmartSwitchState? {
    SmartSwitchLearner.suggestion(vn: vn, en: en, days: days)
  }

  static func computePromotion(
    enRestoreStreak: [String: Int],
    vnKeepStreak: [String: Int],
    existingAllow: Set<String>,
    existingKeep: Set<String>,
    existingDeny: Set<String>,
    threshold: Int = 5,
    maxBatch: Int = 10
  ) -> PromotionResult {
    PersonalDictMiner.computePromotion(
      enRestoreStreak: enRestoreStreak,
      vnKeepStreak: vnKeepStreak,
      existingAllow: existingAllow,
      existingKeep: existingKeep,
      existingDeny: existingDeny,
      threshold: threshold,
      maxBatch: maxBatch
    )
  }

  /// Lọc từ "sạch" để hiển thị trong bảng Top words.
  static func isCleanTopWord(_ word: String, category: StatCategory) -> Bool {
    let normalized = word.normalizedDictionaryToken
    guard normalized.count >= 2 else { return false }
    if LexiconManager.shared.personalDictionary().deny.contains(normalized) { return false }
    switch category {
    case .vietnamese, .vietnamesePhrase:
      return LexiconManager.shared.isVietnameseWord(normalized)
        || LexiconManager.shared.shouldKeepVietnamese(normalized)
    case .english, .englishPhrase:
      return !LexiconManager.shared.isVietnameseWord(normalized)
    case .app:
      return true
    }
  }

  // MARK: - Hot Path

  func recordCommit(
    decision: SpellDecision,
    rawInput: String,
    transformed: String,
    appBundleId: String?,
    typoCorrectionApplied: Bool = false,
    needsRecovery: Bool = false
  ) {
    guard Defaults[.statisticsEnabled] else { return }
    guard !isSecureInput() else { return }
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

  func recordSmartSwitchFire(toApp: String?) {
    guard Defaults[.statisticsEnabled] else { return }
    queue.async { [weak self] in
      guard let self else { return }
      self.rotateIfNeeded()
      self.counters.smartSwitchFires += 1
      if let app = toApp {
        self.counters.appCounts[app, default: 0] += 1
      }
      self.phraseTracker.resetAll()
      self.scheduleFlush()
    }
  }

  // MARK: - Public Reads & Backup

  func currentWeekSummary() -> UsageSummary {
    queue.sync {
      rotateIfNeeded()
      return counters.summary(promotedAllow: [], promotedKeep: [])
    }
  }

  func historicalSummaries() -> [UsageSummary] {
    queue.sync { store.historicalSummaries() }
  }

  func diagnosticReport() -> String {
    queue.sync { store.diagnosticReport(current: counters) }
  }

  func allWeekBucketsForExport() -> [WeekBucketExport] {
    queue.sync {
      rotateIfNeeded()
      return store.allWeekBucketsForExport(current: counters)
    }
  }

  @discardableResult
  func restoreFromBackup(_ buckets: [WeekBucketExport]) -> Int {
    queue.sync {
      var restored = 0
      let currentId = WeekBucket.currentWeekId()
      for bucket in buckets {
        guard WeekBucket.isValidWeekId(bucket.weekId) else {
          os_log("UsageStatistics.restoreFromBackup: bỏ qua weekId không hợp lệ %{public}@",
                 log: log, type: .error, bucket.weekId)
          continue
        }
        if bucket.weekId == currentId {
          counters = bucket
          flushNow()
          restored += 1
        } else if store.writeClosedWeekBucket(bucket) {
          restored += 1
        }
      }
      return restored
    }
  }

  func aggregatedTopVietnameseWords(threshold: Int = 10) -> [WordCount] {
    var totals: [String: Int] = [:]
    for week in [currentWeekSummary()] + historicalSummaries() {
      for wc in week.topVietnameseWords {
        totals[wc.word, default: 0] += wc.count
      }
    }
    return totals
      .filter { $0.value >= threshold }
      .map { WordCount(word: $0.key, count: $0.value) }
      .sorted { $0.count > $1.count }
  }

  func aggregatedTopVietnamesePhrases(
    minWords: Int = 2, maxWords: Int = 4, threshold: Int = 10
  ) -> [WordCount] {
    queue.sync {
      PhraseTracker.aggregatedVietnamesePhrases(
        from: counters, minWords: minWords, maxWords: maxWords, threshold: threshold
      )
    }
  }

  func aggregatedTopEnglishPhrases(
    minWords: Int = 2, maxWords: Int = 3, threshold: Int = 3
  ) -> [WordCount] {
    queue.sync {
      PhraseTracker.aggregatedEnglishPhrases(
        from: counters, minWords: minWords, maxWords: maxWords, threshold: threshold
      )
    }
  }

  func computeSmartSwitchAutoLearn() -> [String: AppSmartSwitchState] {
    queue.sync { SmartSwitchLearner.computeAutoLearn(from: counters) }
  }

  @discardableResult
  func performWeeklyFeedback() -> UsageSummary {
    queue.sync {
      rotateIfNeeded()
      let suggestions = PersonalDictMiner.computePendingSuggestions(
        enRestoreStreak: counters.enRestoreStreak,
        vnKeepStreak: counters.vnKeepStreak,
        personal: LexiconManager.shared.personalDictionary(),
        threshold: promotionThreshold
      )
      appendToPendingSuggestions(suggestions)
      let summary = counters.summary(promotedAllow: [], promotedKeep: [])
      flushNow()
      return summary
    }
  }

  // MARK: - Deletion & Lifecycle

  func removeTopEntry(word: String, category: StatCategory) {
    removeFromCurrentWeek(word: word, category: category)
    guard category == .english else { return }
    let norm = word.normalizedDictionaryToken
    var deny = Defaults[.userDenyWords]
    guard !deny.contains(where: { $0.normalizedDictionaryToken == norm }) else { return }
    deny.append(norm)
    Defaults[.userDenyWords] = deny
  }

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
      case .vietnamesePhrase:
        PhraseTracker.removePhrase(word, kind: .vietnamese, from: &self.counters)
      case .englishPhrase:
        PhraseTracker.removePhrase(word, kind: .english, from: &self.counters)
      }
      self.scheduleFlush()
    }
  }

  func flushSynchronously() {
    queue.sync { [weak self] in self?.flushNow() }
  }

  func clearAll() {
    queue.sync {
      pendingFlushItem?.cancel()
      pendingFlushItem = nil
      store.clearAllFiles()
      counters = WeekBucket(weekId: counters.weekId, weekEnd: counters.weekEnd)
      phraseTracker.resetAll()
    }
  }

  // MARK: - Internal Bookkeeping

  private func rotateIfNeeded() {
    let current = WeekBucket.currentWeekId()
    guard counters.weekId != current else { return }
    store.closeWeek(counters, nextWeekId: current)
    counters = WeekBucket()
  }

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
    let trackPerToken = !needsRecovery

    switch decision {
    case .keepVietnamese:
      counters.wordsKeptVietnamese += 1
      if trackPerToken, !vnToken.isEmpty {
        counters.vnWordCounts[vnToken, default: 0] += 1
        counters.vnKeepStreak[vnToken, default: 0] += 1
        phraseTracker.recordVietnamese(token: vnToken, into: &counters)
      } else {
        phraseTracker.resetVietnamese()
      }
      phraseTracker.resetEnglish()
    case .restoreRawEnglish:
      counters.wordsRestoredEnglish += 1
      if trackPerToken, !rawToken.isEmpty {
        counters.enWordCounts[rawToken, default: 0] += 1
        counters.enRestoreStreak[rawToken, default: 0] += 1
        phraseTracker.recordEnglish(token: rawToken, into: &counters)
      } else {
        phraseTracker.resetEnglish()
      }
      phraseTracker.resetVietnamese()
    case .keepRaw:
      counters.wordsKeptRaw += 1
      if trackPerToken, !rawToken.isEmpty {
        counters.enWordCounts[rawToken, default: 0] += 1
        phraseTracker.recordEnglish(token: rawToken, into: &counters)
      } else {
        phraseTracker.resetEnglish()
      }
      phraseTracker.resetVietnamese()
    case .suggest:
      counters.wordsSuggested += 1
    }

    if typoCorrectionApplied {
      counters.typoCorrectionsApplied += 1
    }
    if let app = appBundleId, !app.isEmpty {
      counters.appCounts[app, default: 0] += 1
      switch decision {
      case .keepVietnamese:
        counters.appLanguageVnCounts[app, default: 0] += 1
      case .restoreRawEnglish, .keepRaw:
        counters.appLanguageEnCounts[app, default: 0] += 1
      case .suggest:
        break
      }
      let today = Calendar(identifier: .iso8601).component(.weekday, from: Date())
      var days = counters.appLanguageDays[app] ?? []
      if !days.contains(today) { days.append(today) }
      counters.appLanguageDays[app] = days
    }

    trimDict(&counters.vnWordCounts, max: 500)
    trimDict(&counters.enWordCounts, max: 500)
    trimDict(&counters.vnPhraseCounts2, max: 300)
    trimDict(&counters.vnPhraseCounts3, max: 300)
    trimDict(&counters.vnPhraseCounts4, max: 200)
    trimDict(&counters.enPhraseCounts2, max: 300)
    trimDict(&counters.enPhraseCounts3, max: 300)

    scheduleFlush()
  }

  private func trimDict(_ dict: inout [String: Int], max: Int) {
    guard dict.count > max + max / 4 else { return }
    let keepers = dict.sorted { $0.value > $1.value }.prefix(max)
    dict = Dictionary(uniqueKeysWithValues: keepers.map { ($0.key, $0.value) })
  }

  private func scheduleFlush() {
    pendingFlushItem?.cancel()
    let item = DispatchWorkItem { [weak self] in self?.flushNow() }
    pendingFlushItem = item
    queue.asyncAfter(deadline: .now() + 10, execute: item)
  }

  private func flushNow() {
    store.saveCurrentWeek(counters)
  }

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
}
