import XCTest
import Defaults
@testable import vkey

// MARK: - vkey 1.5.0 Phase 10 — UserDataMigration

final class UserDataMigrationTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Baseline so the test starts from known defaults.
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userKeepWords)
    Defaults.reset(.userDenyWords)
    Defaults.reset(.macros)
  }

  func test_currentExport_capturesState() {
    Defaults[.userAllowWords] = ["alpha", "beta"]
    Defaults[.macros] = [Macro(from: "vn", to: "Việt Nam")]
    Defaults[.autoUpdateEnabled] = false
    Defaults[.uiTheme] = .glass
    Defaults[.appearanceMode] = .dark
    Defaults[.hudOpacityPercent] = 64
    Defaults[.autoCapitalizeEnabled] = false
    Defaults[.nonLatinIMEAutoDisable] = false
    Defaults[.freeMarkModeEnabled] = true
    defer {
      Defaults.reset(.userAllowWords)
      Defaults.reset(.macros)
      Defaults.reset(.autoUpdateEnabled)
      Defaults.reset(.uiTheme)
      Defaults.reset(.appearanceMode)
      Defaults.reset(.hudOpacityPercent)
      Defaults.reset(.autoCapitalizeEnabled)
      Defaults.reset(.nonLatinIMEAutoDisable)
      Defaults.reset(.freeMarkModeEnabled)
    }

    let export = UserDataMigration.currentExport(includeStatistics: false)
    XCTAssertEqual(export.schemaVersion, UserDataExport.currentSchemaVersion)
    XCTAssertEqual(export.userAllowWords?.sorted(), ["alpha", "beta"])
    XCTAssertEqual(export.macros?.first?.from, "vn")
    XCTAssertEqual(export.autoUpdateEnabled, false)
    XCTAssertEqual(export.uiTheme, UITheme.glass.rawValue)
    XCTAssertEqual(export.appearanceMode, AppearanceMode.dark.rawValue)
    XCTAssertEqual(export.hudOpacityPercent, 64)
    XCTAssertEqual(export.autoCapitalizeEnabled, false)
    XCTAssertEqual(export.nonLatinIMEAutoDisable, false)
    XCTAssertEqual(export.freeMarkModeEnabled, true)
  }

  func test_encodeRoundTrip() throws {
    let export = UserDataMigration.currentExport(includeStatistics: false)
    let data = try UserDataMigration.encode(export)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(UserDataExport.self, from: data)
    XCTAssertEqual(decoded.schemaVersion, export.schemaVersion)
    XCTAssertEqual(decoded.appVersion, export.appVersion)
  }

  func test_autoUpdateEnabled_roundTrip() {
    Defaults[.autoUpdateEnabled] = false
    defer { Defaults.reset(.autoUpdateEnabled) }

    let export = UserDataMigration.currentExport(includeStatistics: false)
    XCTAssertEqual(export.autoUpdateEnabled, false)

    Defaults[.autoUpdateEnabled] = true
    UserDataMigration.importExport(export)
    XCTAssertEqual(Defaults[.autoUpdateEnabled], false)
  }

  func test_importMerge_keepsExistingEntries() {
    Defaults[.userAllowWords] = ["existing"]
    defer { Defaults.reset(.userAllowWords) }

    let export = UserDataExport(
      schemaVersion: 1, exportedAt: Date(),
      appVersion: "1.5.0", appBuild: "15000",
      userAllowWords: ["fresh"]
    )
    let changes = UserDataMigration.importExport(export, replaceLists: false)
    XCTAssertTrue(changes.contains { $0.contains("Từ cho phép: +1") })
    XCTAssertEqual(Set(Defaults[.userAllowWords]), Set(["existing", "fresh"]))
  }

  func test_importReplace_overwritesLists() {
    Defaults[.userAllowWords] = ["existing"]
    defer { Defaults.reset(.userAllowWords) }

    let export = UserDataExport(
      schemaVersion: 1, exportedAt: Date(),
      appVersion: "1.5.0", appBuild: "15000",
      userAllowWords: ["fresh"]
    )
    UserDataMigration.importExport(export, replaceLists: true)
    XCTAssertEqual(Defaults[.userAllowWords], ["fresh"])
  }

}
