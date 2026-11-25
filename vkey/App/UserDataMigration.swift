//
//  UserDataMigration.swift
//  vkey
//
//  Pure Foundation/Defaults backup & restore for user data — Defaults,
//  macros, personal dictionaries, per-app overrides, and rolling usage stats.
//  Upgrade prompt UI lives in `UpgradeBackupPrompt.swift`.
//

import Defaults
import Foundation
import os.log

private let log = OSLog(subsystem: "dev.longht.vkey", category: "Migration")

enum UserDataMigration {

  // MARK: - Obsolete keys (forwarded to StartupMigrations)

  static var obsoleteDefaultsKeys: [String] { StartupMigrations.obsoleteDefaultsKeys }

  static func removeObsoleteStoredValues(
    defaults: UserDefaults = .standard,
    applicationSupport: URL? = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first
  ) {
    StartupMigrations.removeObsoleteStoredValues(
      defaults: defaults, applicationSupport: applicationSupport
    )
  }

  // MARK: - Export

  static func currentExport(includeStatistics: Bool = true) -> UserDataExport {
    UserDataExport(
      schemaVersion: UserDataExport.currentSchemaVersion,
      exportedAt: Date(),
      appVersion: Bundle.main.appVersionLong,
      appBuild: Bundle.main.appBuild,
      typingMethod: Defaults[.typingMethod].rawValue,
      newStyleTonePlacement: Defaults[.newStyleTonePlacement],
      autoTypoCorrection: Defaults[.autoTypoCorrection],
      allowedZWJF: Defaults[.allowedZWJF],
      hudEnabled: Defaults[.hudEnabled],
      modifierOnlyToggleHotkey: Defaults[.modifierOnlyToggleHotkey],
      smartSwitchEnabled: Defaults[.smartSwitchEnabled],
      smartSwitchApps: nil,
      spellCheckEnabled: Defaults[.spellCheckEnabled],
      englishAutoRestoreEnabled: Defaults[.englishAutoRestoreEnabled],
      restorePolicy: Defaults[.restorePolicy].rawValue,
      suggestionEnabled: Defaults[.suggestionEnabled],
      autoApplyHighConfidenceSuggestion: Defaults[.autoApplyHighConfidenceSuggestion],
      useEnVnReference: Defaults[.useEnVnReference],
      personalDictionaryEnabled: Defaults[.personalDictionaryEnabled],
      userAllowWords: Defaults[.userAllowWords],
      userKeepWords: Defaults[.userKeepWords],
      userDenyWords: Defaults[.userDenyWords],
      macros: Defaults[.macros].map { MacroSeed(from: $0.from, to: $0.to) },
      macroEnabled: Defaults[.macroEnabled],
      macrosSeeded: Defaults[.macrosSeeded],
      defaultMacrosVersion: Defaults[.defaultMacrosVersion],
      uiTheme: Defaults[.uiTheme].rawValue,
      appearanceMode: Defaults[.appearanceMode].rawValue,
      themeConfigs: Defaults[.themeConfigs],
      autoPersonalDictFeedback: Defaults[.autoPersonalDictFeedback],
      hudOpacityPercent: Defaults[.hudOpacityPercent],
      appSmartSwitchConfigs: Defaults[.appSmartSwitchConfigs],
      appSendingModes: Defaults[.appSendingModes].mapValues(\.rawValue),
      autoCapitalizeEnabled: Defaults[.autoCapitalizeEnabled],
      nonLatinIMEAutoDisable: Defaults[.nonLatinIMEAutoDisable],
      freeMarkModeEnabled: Defaults[.freeMarkModeEnabled],
      statisticsEnabled: Defaults[.statisticsEnabled],
      autoBackupOnUpgrade: Defaults[.autoBackupOnUpgrade],
      autoUpdateEnabled: Defaults[.autoUpdateEnabled],
      statistics: (includeStatistics && Defaults[.statisticsEnabled])
        ? UsageStatistics.shared.allWeekBucketsForExport() : nil
    )
  }

  static func encode(_ export: UserDataExport) throws -> Data {
    try JSONEncoder.statsIndented.encode(export)
  }

  static func writeAtomically(to url: URL, export: UserDataExport) throws {
    let data = try encode(export)
    try data.write(to: url, options: .atomic)
  }

  private static func backupsDirectoryURL() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
    return appSupport.appendingPathComponent("vkey/backups", isDirectory: true)
  }

  static func defaultBackupURL() -> URL {
    let dir = backupsDirectoryURL()
    try? FileManager.default.createDirectory(
      at: dir, withIntermediateDirectories: true, attributes: nil
    )
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let stamp = formatter.string(from: Date())
    let name = "vkey-backup-\(Bundle.main.appVersionLong)-\(stamp).json"
    return dir.appendingPathComponent(name)
  }

  /// Giữ ≥ 5 file backup gần nhất; xoá file > 30 ngày nếu vượt 5 file.
  @discardableResult
  static func cleanupOldBackups() -> Int {
    let dir = backupsDirectoryURL()
    guard let urls = try? FileManager.default.contentsOfDirectory(
      at: dir,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ).filter({ $0.pathExtension == "json" }) else { return 0 }

    let sorted = urls.sorted { a, b in
      let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return da > db
    }

    let keepMinCount = 5
    let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
    var deleted = 0
    for (index, url) in sorted.enumerated() where index >= keepMinCount {
      let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      if modDate < cutoff {
        try? FileManager.default.removeItem(at: url)
        deleted += 1
      }
    }
    return deleted
  }

  // MARK: - Import

  static func loadFrom(_ url: URL) throws -> UserDataExport {
    let data = try Data(contentsOf: url)
    return try JSONDecoder.statsConfigured.decode(UserDataExport.self, from: data)
  }

  @discardableResult
  static func importExport(
    _ export: UserDataExport,
    replaceLists: Bool = false
  ) -> [String] {
    var changes: [String] = []

    func applyScalar<T: Equatable>(_ key: Defaults.Key<T>, _ value: T?, label: String) {
      guard let value, Defaults[key] != value else { return }
      Defaults[key] = value
      changes.append("\(label) ← \(value)")
    }

    func applyRawEnum<T: RawRepresentable & Equatable>(
      _ key: Defaults.Key<T>, _ raw: T.RawValue?, label: String
    ) {
      guard let raw, let parsed = T(rawValue: raw), Defaults[key] != parsed else { return }
      Defaults[key] = parsed
      changes.append("\(label) ← \(raw)")
    }

    // Engine + UI
    applyRawEnum(.typingMethod, export.typingMethod, label: "Kiểu gõ")
    applyScalar(.newStyleTonePlacement, export.newStyleTonePlacement, label: "Kiểu đặt dấu (mới)")
    applyScalar(.autoTypoCorrection, export.autoTypoCorrection, label: "Tự sửa lỗi gõ nhầm")
    applyScalar(.allowedZWJF, export.allowedZWJF, label: "Phụ âm z, w, j, f")
    applyScalar(.hudEnabled, export.hudEnabled, label: "HUD")
    applyScalar(.modifierOnlyToggleHotkey, export.modifierOnlyToggleHotkey,
                label: "Phím tắt chỉ modifier (VI/EN)")

    // Smart Switch
    applyScalar(.smartSwitchEnabled, export.smartSwitchEnabled, label: "Smart Switch")
    mergeStringList(.smartSwitchApps, export.smartSwitchApps,
                    replace: replaceLists, label: "Danh sách app Smart Switch", into: &changes)
    StartupMigrations.migrateLegacySmartSwitchApps()

    // Spell check
    applyScalar(.spellCheckEnabled, export.spellCheckEnabled, label: "Kiểm tra chính tả")
    applyScalar(.englishAutoRestoreEnabled, export.englishAutoRestoreEnabled,
                label: "Tự khôi phục tiếng Anh")
    applyRawEnum(.restorePolicy, export.restorePolicy, label: "Chính sách khôi phục")
    applyScalar(.suggestionEnabled, export.suggestionEnabled, label: "Gợi ý chính tả")
    applyScalar(.autoApplyHighConfidenceSuggestion,
                export.autoApplyHighConfidenceSuggestion,
                label: "Tự sửa khi tin cậy cao")
    applyScalar(.useEnVnReference, export.useEnVnReference,
                label: "Từ điển tham chiếu Anh-Việt")

    // Personal dictionary
    applyScalar(.personalDictionaryEnabled, export.personalDictionaryEnabled,
                label: "Từ điển cá nhân")
    mergeStringList(.userAllowWords, export.userAllowWords,
                    replace: replaceLists, label: "Từ cho phép", into: &changes)
    mergeStringList(.userKeepWords, export.userKeepWords,
                    replace: replaceLists, label: "Từ ưu tiên giữ", into: &changes)
    mergeStringList(.userDenyWords, export.userDenyWords,
                    replace: replaceLists, label: "Từ loại bỏ", into: &changes)

    // Macros
    if let importMacros = export.macros {
      let imported = importMacros
        .filter { !$0.from.isEmpty }
        .map { Macro(from: $0.from, to: $0.to) }
      if replaceLists {
        if Defaults[.macros] != imported {
          Defaults[.macros] = imported
          changes.append("Macro: \(imported.count) (ghi đè)")
        }
      } else {
        var current = Defaults[.macros]
        let importedFroms = Set(imported.map { $0.from })
        current.removeAll { importedFroms.contains($0.from) }
        current.append(contentsOf: imported)
        if Defaults[.macros] != current {
          Defaults[.macros] = current
          changes.append("Macro: +\(imported.count) (gộp, file ưu tiên)")
        }
      }
    }
    applyScalar(.macroEnabled, export.macroEnabled, label: "Bật macro")
    applyScalar(.macrosSeeded, export.macrosSeeded, label: "Macro đã seed")
    applyScalar(.defaultMacrosVersion, export.defaultMacrosVersion,
                label: "Phiên bản macro mặc định")

    // Theme & preferences
    applyRawEnum(.uiTheme, export.uiTheme, label: "Giao diện UI")
    applyRawEnum(.appearanceMode, export.appearanceMode, label: "Chế độ giao diện")
    applyScalar(.themeConfigs, export.themeConfigs, label: "Cấu hình theme")
    applyScalar(.autoPersonalDictFeedback, export.autoPersonalDictFeedback,
                label: "Tự động cập nhật từ điển cá nhân")
    applyScalar(.hudOpacityPercent, export.hudOpacityPercent, label: "Độ trong suốt HUD")
    applyScalar(.autoCapitalizeEnabled, export.autoCapitalizeEnabled, label: "Tự viết hoa đầu câu")
    applyScalar(.nonLatinIMEAutoDisable, export.nonLatinIMEAutoDisable,
                label: "Tự tắt khi dùng IME không Latin")
    applyScalar(.freeMarkModeEnabled, export.freeMarkModeEnabled, label: "Đặt dấu tự do")
    applyScalar(.statisticsEnabled, export.statisticsEnabled, label: "Bật thống kê")
    applyScalar(.autoBackupOnUpgrade, export.autoBackupOnUpgrade, label: "Tự sao lưu khi cập nhật")
    applyScalar(.autoUpdateEnabled, export.autoUpdateEnabled,
                label: "Tự động cập nhật phiên bản mới")
    if export.autoUpdateEnabled != nil {
      Updater.applyAutomaticUpdatePreference()
    }

    // Per-app dictionaries
    mergeDictionary(.appSmartSwitchConfigs, export.appSmartSwitchConfigs,
                    replace: replaceLists, label: "Smart Switch theo app", into: &changes)
    if let raw = export.appSendingModes {
      let imported = raw.compactMapValues(AppSendingMode.init(rawValue:))
      mergeDictionary(.appSendingModes, imported,
                      replace: replaceLists, label: "Cách gửi phím theo app", into: &changes)
    }

    // Statistics
    if let stats = export.statistics, !stats.isEmpty {
      if replaceLists {
        UsageStatistics.shared.clearAll()
      }
      let restored = UsageStatistics.shared.restoreFromBackup(stats)
      if restored > 0 {
        let mode = replaceLists ? "(ghi đè)" : "(gộp)"
        changes.append("Thống kê: khôi phục \(restored) tuần \(mode)")
      }
    }

    os_log("UserDataMigration: applied import with %d changes",
           log: log, type: .info, changes.count)
    return changes
  }

  // MARK: - Version handoff

  static var isRunningUnderXCTest: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }

  @discardableResult
  static func handleVersionChange(
    previousVersion: String = Defaults[.currentVersion]
  ) -> Bool {
    StartupMigrations.removeObsoleteStoredValues()

    let persisted = previousVersion
    let running = Bundle.main.appVersionLong
    guard persisted != "0.1", persisted != running else {
      Defaults[.currentVersion] = running
      return persisted != running
    }

    guard Defaults[.autoBackupOnUpgrade], !isRunningUnderXCTest else {
      Defaults[.currentVersion] = running
      return true
    }

    UpgradeBackupPrompt.present(from: persisted, to: running)
    return false
  }

  // MARK: - Helpers

  private static func mergeStringList(
    _ key: Defaults.Key<[String]>,
    _ value: [String]?,
    replace: Bool,
    label: String,
    into changes: inout [String]
  ) {
    guard let value else { return }
    if replace {
      if Defaults[key] != value {
        Defaults[key] = value
        changes.append("\(label): \(value.count) (ghi đè)")
      }
      return
    }
    var current = Defaults[key]
    let existing = Set(current)
    var added = 0
    for w in value where !existing.contains(w) {
      current.append(w)
      added += 1
    }
    if added > 0 {
      Defaults[key] = current
      changes.append("\(label): +\(added)")
    }
  }

  private static func mergeDictionary<V: Equatable>(
    _ key: Defaults.Key<[String: V]>,
    _ imported: [String: V]?,
    replace: Bool,
    label: String,
    into changes: inout [String]
  ) {
    guard let imported else { return }
    if replace {
      if Defaults[key] != imported {
        Defaults[key] = imported
        changes.append("\(label): \(imported.count) (ghi đè)")
      }
      return
    }
    var current = Defaults[key]
    var changed = 0
    for (k, v) in imported where current[k] != v {
      current[k] = v
      changed += 1
    }
    if changed > 0 {
      Defaults[key] = current
      changes.append("\(label): +\(changed) (gộp, file ưu tiên)")
    }
  }
}
