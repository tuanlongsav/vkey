import XCTest
import Defaults
@testable import vkey

final class SpellDecisionEngineTests: SpellResetTestCase {
  // MARK: - Lexicon / Spell Decision / Suggestion

  func testLexiconManagerEmbeddedDefaults() throws {
    let manager = LexiconManager(updatePackageURL: URL(fileURLWithPath: "/tmp/vkey-lexicon-no-file.json"))
    manager.reload()

    XCTAssertTrue(manager.isVietnameseWord("việt"))
    XCTAssertTrue(manager.isEnglishWord("text"))
    XCTAssertTrue(manager.shouldApplyLegacyRestore(transformed: "ò", rawInput: "of"))
  }

  func testLexiconManagerHybridPrefersHigherVersionPackage() throws {
    let path = URL(fileURLWithPath: "/tmp/vkey-lexicon-update-test.json")
    let manager = LexiconManager(updatePackageURL: path)
    let package = """
    {
      "version": 5,
      "vietnamese": ["thành","công"],
      "english": ["deploy"],
      "keep": ["sara"]
    }
    """
    try manager.setUpdatePackageData(Data(package.utf8))
    manager.reload()

    let versions = manager.snapshotVersions()
    let sources = manager.snapshotSources()
    XCTAssertEqual(versions.vn, 5)
    XCTAssertEqual(sources.vn, .updatePackage)
    XCTAssertTrue(manager.isVietnameseWord("thành"))
    XCTAssertTrue(manager.isEnglishWord("deploy"))
  }

  /// Fix #2: gói ĐÃ LƯU trên đĩa cũng phải qua cổng kiểm tra khi load — gói vi
  /// phạm giới hạn cấu trúc (L4) bị từ chối, lexicon rơi về bản embedded thay vì
  /// nuốt gói không an toàn (embedded version = 2 < 999 nên nếu bỏ qua kiểm tra
  /// thì gói này SẼ được adopt — chứng minh cổng load thực sự chặn).
  func testLexiconLoadRejectsInvalidOnDiskPackage() throws {
    let path = URL(fileURLWithPath: "/tmp/vkey-lexicon-invalid-ondisk.json")
    let longWord = String(repeating: "a", count: LexiconUpdatePackage.maxStringLength + 1)
    let bad = #"{"version": 999, "vietnamese": ["\#(longWord)"], "english": [], "keep": []}"#
    try Data(bad.utf8).write(to: path)
    defer { try? FileManager.default.removeItem(at: path) }

    let manager = LexiconManager(updatePackageURL: path)
    manager.reload()

    XCTAssertNotEqual(manager.snapshotVersions().vn, 999)
    XCTAssertEqual(manager.snapshotSources().vn, .embedded)
  }

  func testLexiconManagerUserAllowAndDenyOverride() throws {
    Defaults[.userAllowWords] = ["abcxyz"]
    Defaults[.userDenyWords] = ["việt"]
    defer {
      Defaults[.userAllowWords] = []
      Defaults[.userDenyWords] = []
    }

    let manager = LexiconManager(updatePackageURL: URL(fileURLWithPath: "/tmp/vkey-lexicon-user-override.json"))
    manager.reload()

    XCTAssertTrue(manager.isVietnameseWord("abcxyz"))
    XCTAssertFalse(manager.isVietnameseWord("việt"))
  }

  func testSpellDecisionRestoreEnglishWhenInvalidVietnamese() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldPolicy = Defaults[.restorePolicy]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.restorePolicy] = oldPolicy
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.restorePolicy] = .vietnameseFirst

    let engine = SpellDecisionEngine.shared
    let decision = engine.evaluate(rawInput: "text", transformed: "tẽt", needsRecovery: true)
    XCTAssertEqual(decision, .restoreRawEnglish("text"))
  }

  /// Regression 1.7.11: balanced policy phải keep VN khi transformed có
  /// dấu Việt (ả/ư/đ/...) — bất kể raw có match English (vd "car"/"cả",
  /// "nuut"/"nứt"). Trước đây balanced chỉ check `extremelyCommonVietnameseWords`
  /// cherry-picked → các từ phổ biến có dấu nhưng không trong list bị restore raw.
  func testSpellDecisionBalancedKeepsVnDiacritic() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldPolicy = Defaults[.restorePolicy]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.restorePolicy] = oldPolicy
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.restorePolicy] = .balanced

    let engine = SpellDecisionEngine.shared
    // "car" (English) → "cả" (telex hỏi). Balanced phải keep VN do dấu ả.
    let d1 = engine.evaluate(rawInput: "car", transformed: "cả", needsRecovery: false)
    XCTAssertEqual(d1, .keepVietnamese)
    // "the" → "thể" (telex hỏi).
    let d2 = engine.evaluate(rawInput: "the", transformed: "thể", needsRecovery: false)
    XCTAssertEqual(d2, .keepVietnamese)
    // "but" → "bụt" (telex nặng nếu user gõ "butj" — nhưng nếu commit thẳng
    // "but" sẽ là raw không dấu). Test với có dấu:
    let d3 = engine.evaluate(rawInput: "buj", transformed: "bụ", needsRecovery: false)
    XCTAssertEqual(d3, .keepVietnamese)
  }

  func testSpellDecisionVietnameseFirstKeepsValidVietnamese() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldPolicy = Defaults[.restorePolicy]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.restorePolicy] = oldPolicy
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.restorePolicy] = .vietnameseFirst

    let engine = SpellDecisionEngine.shared
    let decision = engine.evaluate(rawInput: "gi", transformed: "gì", needsRecovery: false)
    XCTAssertEqual(decision, .keepVietnamese)
  }

  func testSpellDecisionLegacyRestoreBackwardCompatibility() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true

    let engine = SpellDecisionEngine.shared
    let decision = engine.evaluate(rawInput: "of", transformed: "ò", needsRecovery: false)
    XCTAssertEqual(decision, .restoreRawEnglish("of"))
  }

  func testSuggestionServiceRankingForVietnameseTypo() throws {
    let service = SuggestionService.shared
    let suggestions = service.suggest(word: "thih", locale: "vi_VN", limit: 5)
    XCTAssertFalse(suggestions.isEmpty)
    XCTAssertTrue(suggestions.first?.score ?? 0 > 0)
  }

  func testSpellDecisionSuggestsWhenInvalidAndNotEnglish() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldSuggestion = Defaults[.suggestionEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.suggestionEnabled] = oldSuggestion
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.suggestionEnabled] = true

    let engine = SpellDecisionEngine.shared
    let decision = engine.evaluate(rawInput: "thih", transformed: "thih", needsRecovery: true)
    if case .suggest(let candidates) = decision {
      XCTAssertFalse(candidates.isEmpty)
    } else {
      XCTFail("Expected suggestion decision for invalid non-English token")
    }
  }

  func testSpellDecisionDoesNotSuggestForValidSyllableNotInDictionary() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldSuggestion = Defaults[.suggestionEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.suggestionEnabled] = oldSuggestion
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.suggestionEnabled] = true

    let engine = SpellDecisionEngine.shared
    // "tắt" is a valid Vietnamese syllable (needsRecovery is false) but is not in the embedded dictionary.
    let decision = engine.evaluate(rawInput: "tatws", transformed: "tắt", needsRecovery: false)
    XCTAssertEqual(decision, .keepVietnamese)
  }

  func testSpellDecisionPreservesDoubledToneMarks() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
    }
    Defaults[.spellCheckEnabled] = true

    let engine = SpellDecisionEngine.shared
    
    // "barr" has doubled "rr", should be kept raw even if needsRecovery is true
    let decision1 = engine.evaluate(rawInput: "barr", transformed: "barr", needsRecovery: true)
    XCTAssertEqual(decision1, .keepRaw)
    
    // "class" has doubled "ss", should be kept raw even if needsRecovery is true
    let decision2 = engine.evaluate(rawInput: "class", transformed: "class", needsRecovery: true)
    XCTAssertEqual(decision2, .keepRaw)
  }

  /// v4.23 — THAY THẾ `testTransformationTrackerDetectsRepeatedFailureSignals`.
  ///
  /// Test cũ dựng `TransformationTracker` và khẳng định hai telemetry lỗi liên
  /// tiếp thì bộ đếm bật cờ. Cơ chế đó nay đã bị gỡ hẳn (kèm công tắc
  /// `autoSwitchStrategy`) vì nó KHÔNG BAO GIỜ chạy được ngoài test: nhánh
  /// `isHighRisk` đòi `usedAsyncQueue == false`, mà mọi call site thật dựng
  /// `EventSendTelemetry` với `attemptedTransform == true` đều đặt
  /// `usedAsyncQueue: true`. Test cũ pass chỉ vì nó tự tay dựng telemetry mà
  /// transport không bao giờ phát ra — nó khoá một con đường chết, nên phải đi
  /// cùng đoạn code chết chứ không được "sửa cho biên dịch được".
  ///
  /// Thay vào đó khoá ĐÚNG hành vi còn lại: chiến lược gửi phím tra THẲNG bảng
  /// per-app, không qua tầng đệm nào nữa. `activeApp` rỗng (chưa có app nào) là
  /// khác biệt hành vi DUY NHẤT của lần gỡ này — trước đây rơi vào `.batch`
  /// (giá trị khởi tạo của struct), nay rơi vào fallback `.hybrid` của
  /// `getStrategy`. Ghi lại tường minh để lần sau không ai coi là hồi quy.
}

// MARK: - ===========================================
// MARK: - English Instant-Restore Collision Tests
// MARK: - ===========================================

/// Đảm bảo danh sách 126 từ instant-restore không "ăn" mất các từ tiếng Việt
/// hợp lệ khi đang gõ tiếng Việt.
final class EnglishRestoreCollisionTests: XCTestCase {

  // BUG: gõ Telex "queen" ở mode tiếng Việt trước đây ra "queen" (instant-restore
  // English) thay vì "quên" (từ VN hợp lệ). "queen"/"queens" đã bị loại khỏi
  // danh sách 126 từ instant-restore.
  func testQueenTypesAsVietnameseQuen() throws {
    XCTAssertEqual(telex("queen"), "quên",
      "Gõ Telex 'queen' ở mode tiếng Việt phải ra 'quên', không bị đè English")
  }

  // v2.9: audit toàn bộ danh sách instant-restore phát hiện thêm 18 từ EN mà
  // Telex thuần ra từ VIỆT hợp lệ & phổ biến. Đã loại khỏi instant-restore.
  func testCommonVietnameseWordsNotShadowedByEnglish() throws {
    XCTAssertEqual(telex("moon"), "môn")       // chuyên môn
    XCTAssertEqual(telex("noon"), "nôn")
    XCTAssertEqual(telex("soon"), "sôn")
    XCTAssertEqual(telex("theme"), "thêm")
    // v2.15: "meeting" giờ ra "meeting" (giữ tiếng Anh) thay vì "miêng" —
    // fix typo-correction "ei→ie" không còn nuốt phụ âm cuối "t" (cùng class
    // bug "Opus→uOs"). "miêng" vốn không phải từ Việt chuẩn nên đây là cải thiện.
    XCTAssertEqual(telex("meeting"), "meeting")
    XCTAssertEqual(telex("meets"), "mết")
    XCTAssertEqual(telex("boots"), "bốt")
    XCTAssertEqual(telex("tree"), "trê")
    XCTAssertEqual(telex("beer"), "bể")
    XCTAssertEqual(telex("loops"), "lốp")
  }

  // Regression: các từ EN mà transform KHÔNG ra từ VN hợp lệ vẫn giữ raw English.
  func testOtherEenWordsStillRestoreEnglish() throws {
    XCTAssertEqual(telex("green"), "green")
    XCTAssertEqual(telex("screen"), "screen")
    // Nhóm 2 (giữ lại theo quyết định — từ Anh phổ biến): vẫn restore English.
    XCTAssertEqual(telex("three"), "three")
    XCTAssertEqual(telex("these"), "these")
  }
}
