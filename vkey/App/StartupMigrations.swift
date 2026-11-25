//
//  StartupMigrations.swift
//  vkey
//
//  One-shot and idempotent launch migrations consolidated from AppDelegate,
//  AppState, and UserDataMigration.
//

import Defaults
import Foundation

enum StartupMigrations {

  /// Khoá Defaults của các tính năng đã gỡ và khoá bỏ hoang cần dọn khỏi plist.
  static let obsoleteDefaultsKeys: [String] = [
    "modifier-only-text-tools-hotkey", "KeyboardShortcuts_openTextConversionMenu",
    "clipboard-history-enabled", "clipboard-history-capacity",
    "clipboard-history-content-mode", "clipboard-history-max-entry-megabytes",
    "clipboard-history-modifier-only-hotkey", "KeyboardShortcuts_pasteClipboardHistory",
    "word-prediction-enabled", "word-prediction-excluded-apps", "prediction-max-words",
    "prediction-hud-line-offset", "prediction-hud-font-size", "user-bigrams", "user-trigrams",
    "window-title-rules", "cgevent-race-hardening-enabled", "cgevent-flush-delay-ms",
    "translation-hud-enabled", "translation-hud-duration-ms", "programming-mode",
    "per-app-override", "quick-config-preset", "spell-check-in-sentence-enabled",
    "accent-color-choice", "last-smart-switch-auto-learn-date",
    "smart-switch-suggestions-total", "smart-switch-suggestions-accepted",
    "dictionary-update-channel", "dictionary-github-update-enabled",
    "NSWindow Frame VkeySettingsWindow",
    "NSWindow Frame VkeySettingsWindow.v174",
    "NSWindow Frame VkeySettingsWindow.v175",
    "NSWindow Frame VkeySettingsWindow.v176",
    "NSWindow Frame VkeySettingsWindow.v177",
  ]

  /// Run all launch-time migrations in their required dependency order.
  static func runAll() {
    seedDefaultMacrosIfNeeded()
    migrateSpotlightKeepMode()
    migrateLaunchersKeepMode()
    migrateLegacySmartSwitchApps()
    removeObsoleteStoredValues()
  }

  /// Xoá giá trị đã lưu của `obsoleteDefaultsKeys` và kho n-gram của tính năng
  /// đoán từ. Idempotent, chạy mỗi lần khởi động.
  static func removeObsoleteStoredValues(
    defaults: UserDefaults = .standard,
    applicationSupport: URL? = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first
  ) {
    for key in obsoleteDefaultsKeys where defaults.object(forKey: key) != nil {
      defaults.removeObject(forKey: key)
    }
    if let applicationSupport {
      let ngramDir = applicationSupport.appendingPathComponent("vkey/ngram", isDirectory: true)
      if FileManager.default.fileExists(atPath: ngramDir.path) {
        try? FileManager.default.removeItem(at: ngramDir)
      }
    }
  }

  /// Seed / migrate bộ macro mặc định (v1 → v2, idempotent).
  static func seedDefaultMacrosIfNeeded() {
    if Defaults[.defaultMacrosVersion] >= 2 { return }

    if !Defaults[.macrosSeeded] && Defaults[.macros].isEmpty {
      Defaults[.macros] = DefaultMacros.allDefaults
      Defaults[.macrosSeeded] = true
      Defaults[.defaultMacrosVersion] = 2
      return
    }

    var macros = Defaults[.macros]

    for entry in DefaultMacros.obsoleteSeedsV1 {
      macros.removeAll { $0.from == entry.from && $0.to == entry.to }
    }

    for rule in DefaultMacros.renamedSeedsV1ToV2 {
      if let idx = macros.firstIndex(where: { $0.from == rule.oldFrom && $0.to == rule.oldTo }) {
        macros[idx] = Macro(from: rule.newFrom, to: rule.newTo)
      }
    }

    let existingFroms = Set(macros.map { $0.from })
    let existingTos = Set(macros.map { $0.to })
    for newMacro in DefaultMacros.allDefaults {
      if existingFroms.contains(newMacro.from) || existingTos.contains(newMacro.to) { continue }
      macros.append(newMacro)
    }

    Defaults[.macros] = macros
    Defaults[.defaultMacrosVersion] = 2
  }

  /// v4.11: Spotlight theo mode hiện tại (không ép English) — gỡ 1 lần.
  static func migrateSpotlightKeepMode() {
    guard !Defaults[.didMigrateSpotlightKeepMode] else { return }
    let spotlight = "com.apple.Spotlight"
    if Defaults[.smartSwitchApps].contains(spotlight) {
      Defaults[.smartSwitchApps].removeAll { $0 == spotlight }
    }
    if Defaults[.appSmartSwitchConfigs][spotlight] != nil {
      Defaults[.appSmartSwitchConfigs].removeValue(forKey: spotlight)
    }
    Defaults[.didMigrateSpotlightKeepMode] = true
  }

  /// v4.12: launcher (Raycast/Alfred/LaunchBar) theo mode hiện tại — gỡ entry auto-seed `englishMode` 1 lần.
  static func migrateLaunchersKeepMode() {
    guard !Defaults[.didMigrateLaunchersKeepMode] else { return }
    let launchers = [
      "com.raycast.macos",
      "com.runningwithcrayons.Alfred",
      "com.runningwithcrayons.Alfred-Preferences",
      "com.obdev.LaunchBar",
    ]
    var apps = Defaults[.smartSwitchApps]
    apps.removeAll { launchers.contains($0) }
    Defaults[.smartSwitchApps] = apps
    var configs = Defaults[.appSmartSwitchConfigs]
    for id in launchers where configs[id]?.state == .englishMode {
      configs.removeValue(forKey: id)
    }
    Defaults[.appSmartSwitchConfigs] = configs
    Defaults[.didMigrateLaunchersKeepMode] = true
  }

  /// Chuyển danh sách `smartSwitchApps` đời cũ sang `appSmartSwitchConfigs` rồi xoá danh sách cũ.
  static func migrateLegacySmartSwitchApps() {
    let legacy = Defaults[.smartSwitchApps]
    guard !legacy.isEmpty else { return }
    Defaults[.appSmartSwitchConfigs] = mergingLegacySmartSwitchApps(
      legacy, into: Defaults[.appSmartSwitchConfigs], now: Date()
    )
    Defaults[.smartSwitchApps] = []
  }

  /// Lõi thuần của `migrateLegacySmartSwitchApps`.
  static func mergingLegacySmartSwitchApps(
    _ legacy: [String],
    into configs: [String: AppSmartSwitchConfig],
    now: Date
  ) -> [String: AppSmartSwitchConfig] {
    var merged = configs
    for bundleId in legacy where merged[bundleId] == nil {
      merged[bundleId] = AppSmartSwitchConfig(
        state: .englishMode, source: .user, lastModified: now
      )
    }
    return merged
  }
}
