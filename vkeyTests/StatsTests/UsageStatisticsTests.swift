import XCTest
import Defaults
@testable import vkey

// MARK: - vkey 1.5.0 Phase 9 — UsageStatistics

/// Tests use a per-test isolated `UsageStatistics(storageDir:)` so parallel
/// XCTest scheduling (the test plan has `parallelizable: true`) cannot
/// race on the singleton's in-memory or on-disk state.
final class UsageStatisticsTests: XCTestCase {

  private var stats: UsageStatistics!
  private var tmpDir: URL!

  override func setUp() {
    super.setUp()
    tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("vkey-stats-\(UUID().uuidString)", isDirectory: true)
    stats = UsageStatistics(storageDir: tmpDir)
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userKeepWords)
    Defaults.reset(.userDenyWords)
    Defaults[.statisticsEnabled] = true
  }

  override func tearDown() {
    stats = nil
    try? FileManager.default.removeItem(at: tmpDir)
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userKeepWords)
    Defaults.reset(.userDenyWords)
    super.tearDown()
  }

  func test_recordCommit_incrementsAggregates() throws {
    for _ in 0..<3 {
      stats.recordCommit(
        decision: .keepVietnamese,
        rawInput: "viet",
        transformed: "việt",
        appBundleId: "com.apple.dt.Xcode"
      )
    }
    // Let the async queue drain.
    let exp = expectation(description: "queue drain")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
    wait(for: [exp], timeout: 1.0)

    let summary = stats.currentWeekSummary()
    XCTAssertEqual(summary.wordsTotal, 3)
    XCTAssertEqual(summary.wordsKeptVietnamese, 3)
    XCTAssertTrue(summary.topVietnameseWords.contains { $0.word == "việt" && $0.count == 3 })
    XCTAssertTrue(summary.topApps.contains { $0.word == "com.apple.dt.Xcode" })
  }

  func test_disabledByDefaults_noOps() throws {
    Defaults[.statisticsEnabled] = false
    defer { Defaults[.statisticsEnabled] = true }

    stats.recordCommit(
      decision: .keepVietnamese,
      rawInput: "v", transformed: "v", appBundleId: nil
    )
    let exp = expectation(description: "queue drain")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
    wait(for: [exp], timeout: 1.0)

    XCTAssertEqual(stats.currentWeekSummary().wordsTotal, 0)
  }

  // The "weekly feedback" tests below exercise the pure-function core of the
  // promotion logic (`UsageStatistics.computePromotion(...)`) rather than the
  // instance method that touches global `Defaults`. The instance method is
  // a thin wrapper around the pure function — running the pure function
  // gives us deterministic results regardless of XCTest parallelization.

  func test_computePromotion_englishAboveThreshold() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: ["deploy": 5, "hello": 5],
      vnKeepStreak: [:],
      existingAllow: [], existingKeep: [], existingDeny: []
    )
    XCTAssertEqual(Set(result.allow), Set(["deploy", "hello"]))
    XCTAssertTrue(result.keep.isEmpty)
  }

  func test_computePromotion_vietnameseAboveThreshold() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: [:],
      vnKeepStreak: ["việt": 5, "không": 7, "alphaonly": 6],
      existingAllow: [], existingKeep: [], existingDeny: []
    )
    XCTAssertEqual(Set(result.keep), Set(["việt", "không"]),
                   "ascii-only word should be skipped since it has no Vietnamese marker")
  }

  func test_computePromotion_belowThresholdSkipped() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: ["deploy": 3],
      vnKeepStreak: ["việt": 4],
      existingAllow: [], existingKeep: [], existingDeny: [],
      threshold: 5
    )
    XCTAssertTrue(result.allow.isEmpty)
    XCTAssertTrue(result.keep.isEmpty)
  }

  func test_computePromotion_existingEntriesSkipped() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: ["deploy": 5, "release": 5],
      vnKeepStreak: ["việt": 5, "không": 5],
      existingAllow: ["deploy"],
      existingKeep: ["không"],
      existingDeny: []
    )
    XCTAssertEqual(result.allow, ["release"])
    XCTAssertEqual(result.keep, ["việt"])
  }

  func test_computePromotion_denyTrumpsEverything() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: ["deploy": 99],
      vnKeepStreak: ["việt": 99],
      existingAllow: [],
      existingKeep: [],
      existingDeny: ["deploy", "việt"]
    )
    XCTAssertTrue(result.allow.isEmpty,
                  "User has explicitly denied — promotion must skip even at high count")
    XCTAssertTrue(result.keep.isEmpty)
  }

  func test_computePromotion_capsBatchSize() {
    // Use letter-only labels so they pass the `isASCIIAlphabeticWord` guard
    // (digits would be rejected). Generate 20 distinct ASCII words.
    var streak: [String: Int] = [:]
    let letters = "abcdefghijklmnopqrst"
    for c in letters {
      streak["alpha\(c)"] = 5
    }
    XCTAssertEqual(streak.count, 20)
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: streak, vnKeepStreak: [:],
      existingAllow: [], existingKeep: [], existingDeny: [],
      maxBatch: 5
    )
    XCTAssertEqual(result.allow.count, 5)
  }

  private func drainStatsQueue(_ stats: UsageStatistics) {
    stats.flushSynchronously()
    let exp = expectation(description: "queue drain")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
    wait(for: [exp], timeout: 1.0)
  }

  func test_removeFromCurrentWeek_vietnamesePhrase() {
    for _ in 0..<5 {
      stats.recordCommit(
        decision: .keepVietnamese,
        rawInput: "xin", transformed: "xin", appBundleId: nil
      )
      stats.recordCommit(
        decision: .keepVietnamese,
        rawInput: "chào", transformed: "chào", appBundleId: nil
      )
    }
    drainStatsQueue(stats)
    let before = stats.aggregatedTopVietnamesePhrases(minWords: 2, maxWords: 3, threshold: 3)
    XCTAssertTrue(before.contains { $0.word == "xin chào" && $0.count >= 3 })

    stats.removeFromCurrentWeek(word: "xin chào", category: .vietnamesePhrase)
    drainStatsQueue(stats)
    let after = stats.aggregatedTopVietnamesePhrases(minWords: 2, maxWords: 3, threshold: 3)
    XCTAssertFalse(after.contains { $0.word == "xin chào" })
  }

  func test_removeFromCurrentWeek_englishPhrase() {
    for _ in 0..<5 {
      stats.recordCommit(
        decision: .restoreRawEnglish("machine"),
        rawInput: "machine", transformed: "machine", appBundleId: nil
      )
      stats.recordCommit(
        decision: .restoreRawEnglish("learning"),
        rawInput: "learning", transformed: "learning", appBundleId: nil
      )
    }
    drainStatsQueue(stats)
    let before = stats.aggregatedTopEnglishPhrases(minWords: 2, maxWords: 3, threshold: 3)
    XCTAssertTrue(before.contains { $0.word == "machine learning" && $0.count >= 3 })

    stats.removeFromCurrentWeek(word: "machine learning", category: .englishPhrase)
    drainStatsQueue(stats)
    let after = stats.aggregatedTopEnglishPhrases(minWords: 2, maxWords: 3, threshold: 3)
    XCTAssertFalse(after.contains { $0.word == "machine learning" })
  }

  func test_removeTopEntry_english_addsUserDeny() {
    stats.recordCommit(
      decision: .restoreRawEnglish("lol"),
      rawInput: "lol", transformed: "lol", appBundleId: nil
    )
    drainStatsQueue(stats)
    XCTAssertTrue(stats.currentWeekSummary().topEnglishWords.contains { $0.word == "lol" })

    stats.removeTopEntry(word: "lol", category: .english)
    drainStatsQueue(stats)
    XCTAssertTrue(
      Defaults[.userDenyWords].contains { $0.normalizedDictionaryToken == "lol" },
      "Xóa từ EN từ top phải thêm deny list để không hiện lại"
    )
    XCTAssertFalse(stats.currentWeekSummary().topEnglishWords.contains { $0.word == "lol" })
  }

  func testOnlyIsoWeekIdsAreAcceptedAsStatsFileNames() {
    XCTAssertTrue(UsageStatistics.isValidWeekId("2026-W21"))
    XCTAssertTrue(UsageStatistics.isValidWeekId("2026-W01"))
    XCTAssertFalse(UsageStatistics.isValidWeekId(""))
    XCTAssertFalse(UsageStatistics.isValidWeekId("../../../Library/x"))
    XCTAssertFalse(UsageStatistics.isValidWeekId("2026-W21/../../x"))
    XCTAssertFalse(UsageStatistics.isValidWeekId("2026-W21\n"))
  }
}

final class StatisticsExportDecodeTests: SpellResetTestCase {
  // MARK: - U3: import thống kê phân biệt null / thiếu / hỏng / hợp lệ

  func testStatisticsImportDistinguishesNullAbsentAndCorrupt() throws {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    func decode(_ json: String) throws -> UserDataExport {
      try dec.decode(UserDataExport.self, from: Data(json.utf8))
    }
    // Khóa không có → statistics nil, không ném.
    XCTAssertNil(try decode(#"{}"#).statistics)
    // JSON null tường minh → coi như "không có", KHÔNG ném (regression guard).
    XCTAssertNil(try decode(#"{"statistics": null}"#).statistics)
    // Có value nhưng sai kiểu (hỏng) → ném lỗi thay vì âm thầm bỏ.
    XCTAssertThrowsError(try decode(#"{"statistics": 42}"#))
    // Có value hợp lệ (mảng rỗng) → decode được.
    XCTAssertEqual(try decode(#"{"statistics": []}"#).statistics?.count, 0)
  }
}
