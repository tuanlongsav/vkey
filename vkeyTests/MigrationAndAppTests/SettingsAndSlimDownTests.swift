import XCTest
import Defaults
import KeyboardShortcuts
@testable import vkey

// MARK: - Cache giá trị suy ra từ Defaults (rà soát tài nguyên)

final class DefaultsDerivedCacheTests: XCTestCase {

  override func tearDown() {
    Defaults.reset(.macros)
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userDenyWords)
    super.tearDown()
  }

  /// Dựng một lần, giữ cho tới khi key nguồn đổi — kể cả `Defaults.reset`.
  func testRecomputesOnlyAfterSourceKeyChanges() {
    Defaults[.macros] = [Macro(from: "a", to: "b")]
    var computeCount = 0
    let cache = DefaultsDerivedCache<Int>(.macros) {
      computeCount += 1
      return Defaults[.macros].count
    }
    XCTAssertEqual(cache.value, 1)
    XCTAssertEqual(cache.value, 1)
    XCTAssertEqual(computeCount, 1)

    Defaults[.macros] = [Macro(from: "a", to: "b"), Macro(from: "c", to: "d")]
    XCTAssertEqual(cache.value, 2)
    XCTAssertEqual(computeCount, 2)

    Defaults.reset(.macros)
    XCTAssertEqual(cache.value, 0)
    XCTAssertEqual(computeCount, 3)
  }

  /// Set từ điển cá nhân được cache trong LexiconManager — sửa danh sách phải
  /// có hiệu lực ngay ở lần tra kế tiếp trên CÙNG instance.
  func testPersonalDictionaryCacheFollowsDefaults() {
    Defaults[.userAllowWords] = []
    Defaults[.userDenyWords] = []
    let manager = LexiconManager(
      updatePackageURL: URL(fileURLWithPath: "/tmp/vkey-lexicon-personal-cache.json"))
    XCTAssertFalse(manager.isVietnameseWord("abcxyz"))

    Defaults[.userAllowWords] = ["abcxyz"]
    XCTAssertTrue(manager.isVietnameseWord("abcxyz"))
    XCTAssertTrue(manager.isInstantRestoreEnglish("abcxyz"))

    Defaults[.userDenyWords] = ["abcxyz"]
    XCTAssertFalse(manager.isVietnameseWord("abcxyz"))
  }
}


// MARK: - Đợt gọn lại sau 4.34 (2026-11-10)

/// Phần còn sống sau khi gỡ bốn tính năng, và các sửa đi kèm.
final class SlimDownTests: XCTestCase {

  // MARK: Hướng dẫn cấp quyền

  /// macOS 27 đổi tên mục cấp quyền; "Trợ năng" giờ là mục KHÁC. Tên đọc từ
  /// `SecurityPrivacyExtension` trên macOS 27.2.
  func testPermissionPaneNameFollowsTheOSVersion() throws {
    let old = AccessibilityPermissionPane.names(osMajorVersion: 26)
    XCTAssertEqual(old.vi, "Trợ năng")
    XCTAssertEqual(old.en, "Accessibility")

    let new = AccessibilityPermissionPane.names(osMajorVersion: 27)
    XCTAssertEqual(new.vi, "Điều khiển thiết bị và truy cập dữ liệu")
    XCTAssertEqual(new.en, "Device Control and Data Access")
    XCTAssertEqual(AccessibilityPermissionPane.names(osMajorVersion: 28).en, new.en)
  }

  /// Onboarding từng ghi cứng "⌃⇧" trong khi mặc định là ⇧⌥ từ 2.0.2.
  func testOnboardingShowsTheHotkeyThatIsActuallySet() throws {
    let shiftOption =
      Int(NSEvent.ModifierFlags.shift.rawValue) | Int(NSEvent.ModifierFlags.option.rawValue)
    XCTAssertEqual(ConfigurationStepView.toggleHotkeyLine(mask: shiftOption), "Phím tắt đổi VI/EN: ⌥⇧")
    XCTAssertEqual(ConfigurationStepView.toggleHotkeyLine(mask: 0), "Phím tắt đổi VI/EN: chưa đặt")
    XCTAssertEqual(
      Defaults.Keys.modifierOnlyToggleHotkey.defaultValue, shiftOption,
      "mặc định phải là ⇧⌥ — nếu đổi thì sửa cả ảnh hướng dẫn")
  }

  // MARK: Secure Input

  /// Cờ hệ thống tắt thì không có gì để báo, và bộ đếm nhịp về 0.
  func testSecureInputWarningIsSilentWhenTheSystemFlagIsOff() throws {
    let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))
    XCTAssertNil(hook.secureInputWarningHolder(systemFlag: false))
  }

  /// Symbol cảnh báo phải tồn tại ở cả hai biến thể — symbol thiếu thì biểu
  /// tượng menu bar thành ô trống đúng lúc cần báo nhất.
  func testSecureInputWarningSymbolExists() throws {
    let name = VKMenuBarLabel.secureInputWarningSymbol
    XCTAssertNotNil(NSImage(systemSymbolName: name, accessibilityDescription: nil))
    XCTAssertNotNil(NSImage(systemSymbolName: name + ".fill", accessibilityDescription: nil))
  }

  // MARK: Smart Switch — đề xuất

  func testSmartSwitchSuggestionThresholds() throws {
    typealias S = UsageStatistics
    XCTAssertEqual(S.smartSwitchSuggestion(vn: 9, en: 1, days: 1), .vietnameseMode)
    XCTAssertEqual(S.smartSwitchSuggestion(vn: 1, en: 9, days: 1), .englishMode)
    XCTAssertEqual(S.smartSwitchSuggestion(vn: 3, en: 1, days: 1), nil, "4 từ: chưa đủ 5 từ/ngày")
    XCTAssertEqual(S.smartSwitchSuggestion(vn: 15, en: 5, days: 4), .vietnameseMode, "đúng 75%, 5 từ/ngày")
    XCTAssertEqual(S.smartSwitchSuggestion(vn: 12, en: 8, days: 2), nil, "60%: lưng chừng")
    XCTAssertEqual(S.smartSwitchSuggestion(vn: 20, en: 0, days: 5), nil, "4 từ/ngày")
    XCTAssertEqual(S.smartSwitchSuggestion(vn: 20, en: 0, days: 0), nil, "không có ngày nào")
    XCTAssertEqual(S.smartSwitchSuggestion(vn: 0, en: 0, days: 3), nil)
  }

  // MARK: Tự tắt khi đổi bộ gõ không phải Latin

  func testInputSourceLanguageClassification() throws {
    XCTAssertEqual(InputSourceMonitor.classify(languageCode: "en"), .latin)
    XCTAssertEqual(InputSourceMonitor.classify(languageCode: "vi"), .latin)
    XCTAssertEqual(InputSourceMonitor.classify(languageCode: "fr-CA"), .latin, "chỉ xét phần đầu")
    XCTAssertEqual(InputSourceMonitor.classify(languageCode: "ja"), .nonLatin)
    XCTAssertEqual(InputSourceMonitor.classify(languageCode: "zh-Hans"), .nonLatin)
    XCTAssertEqual(InputSourceMonitor.classify(languageCode: "KO"), .nonLatin, "không phân biệt hoa thường")
    XCTAssertEqual(InputSourceMonitor.classify(languageCode: "ru"), .nonLatin)
    XCTAssertEqual(InputSourceMonitor.classify(languageCode: "tlh"), .unknown, "lạ thì không tắt vkey")
  }

  // MARK: Dọn dữ liệu của tính năng đã gỡ

  func testObsoleteStoredValuesAreRemovedAndLiveOnesKept() throws {
    let suite = "dev.longht.vkey.tests.obsolete-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let support = FileManager.default.temporaryDirectory
      .appendingPathComponent("vkey-obsolete-\(UUID().uuidString)", isDirectory: true)
    let ngram = support.appendingPathComponent("vkey/ngram", isDirectory: true)
    let stats = support.appendingPathComponent("vkey/stats", isDirectory: true)
    try FileManager.default.createDirectory(at: ngram, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: ngram.appendingPathComponent("ngrams.json"))
    defer { try? FileManager.default.removeItem(at: support) }

    defaults.set(true, forKey: "clipboard-history-enabled")
    defaults.set(true, forKey: "word-prediction-enabled")
    defaults.set(["x"], forKey: "window-title-rules")
    defaults.set(7, forKey: "modifier-only-text-tools-hotkey")
    defaults.set(false, forKey: "macro-enabled")

    UserDataMigration.removeObsoleteStoredValues(defaults: defaults, applicationSupport: support)
    UserDataMigration.removeObsoleteStoredValues(defaults: defaults, applicationSupport: support)

    for key in UserDataMigration.obsoleteDefaultsKeys {
      XCTAssertNil(defaults.object(forKey: key), key)
    }
    XCTAssertEqual(defaults.object(forKey: "macro-enabled") as? Bool, false, "khoá còn dùng phải nguyên")
    XCTAssertFalse(FileManager.default.fileExists(atPath: ngram.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: stats.path), "thống kê không bị đụng")
  }

  /// Không khoá nào đang được định nghĩa lại nằm trong danh sách xoá.
  func testObsoleteKeyListDoesNotNameALiveSetting() throws {
    let live: Set<String> = [
      Defaults.Keys.modifierOnlyToggleHotkey.name, Defaults.Keys.hudOpacityPercent.name,
      Defaults.Keys.smartSwitchEnabled.name, Defaults.Keys.appSmartSwitchConfigs.name,
      Defaults.Keys.smartSwitchApps.name, Defaults.Keys.spellCheckEnabled.name,
      Defaults.Keys.macroEnabled.name, Defaults.Keys.macros.name,
      Defaults.Keys.statisticsEnabled.name, Defaults.Keys.uiTheme.name,
      Defaults.Keys.themeConfigs.name, Defaults.Keys.currentVersion.name,
    ]
    XCTAssertTrue(live.isDisjoint(with: UserDataMigration.obsoleteDefaultsKeys))
    XCTAssertEqual(
      Set(UserDataMigration.obsoleteDefaultsKeys).count,
      UserDataMigration.obsoleteDefaultsKeys.count, "không lặp")
  }

  // MARK: Tab sau khi gỡ đoán từ

  /// Tab giờ chỉ là phím kết từ: đi thẳng về app và bộ đệm được xoá, để phím gõ
  /// ở ô kế tiếp không diff trên từ của ô trước.
  func testTabEndsTheWordAndPassesThrough() throws {
    let processor = InputProcessor(method: .Telex)
    for ch in "viet" { processor.push(char: ch) }
    let tab = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true))

    XCTAssertNotNil(processor.handleEvent(event: tab), "Tab không bị nuốt")
    XCTAssertTrue(processor.keys.isEmpty)
    XCTAssertEqual(processor.transformed, "")
    XCTAssertNil(processor.previousWordState, "Backspace ở ô mới không dựng lại từ của ô cũ")
  }
}
