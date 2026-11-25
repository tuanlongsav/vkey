//
//  Setting.swift
//  vkey
//
//  Defaults keys, KeyboardShortcuts names, Bundle version metadata,
//  and Engine ↔ Defaults bridges.
//

import AppKit
import Defaults
import Foundation
import KeyboardShortcuts

extension Bundle {
  public var appBuild: String { getInfo("CFBundleVersion") }
  public var appVersionLong: String { getInfo("CFBundleShortVersionString") }

  fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}

extension KeyboardShortcuts.Name {
  static let toggleInputMode = Self("toggleInputMode")
}

/// Default modifier-only hotkey cho VI/EN toggle: **Shift + Option** (⇧⌥).
private let kDefaultModifierOnlyMask: Int =
  Int(NSEvent.ModifierFlags.shift.rawValue) | Int(NSEvent.ModifierFlags.option.rawValue)

extension TypingMethods: Defaults.Serializable {}

extension EngineOptions {
  static var currentFromDefaults: EngineOptions {
    EngineOptions(
      autoTypoCorrection: Defaults[.autoTypoCorrection],
      newStyleTonePlacement: Defaults[.newStyleTonePlacement],
      freeMarkModeEnabled: Defaults[.freeMarkModeEnabled],
      allowedZWJF: Defaults[.allowedZWJF]
    )
  }
}

extension Defaults.Keys {
  // MARK: - Appearance & Theme
  static let uiTheme = Key<UITheme>("ui-theme", default: .tonal)
  static let appearanceMode = Key<AppearanceMode>("appearance-mode", default: .auto)
  static let themeConfigs = Key<[String: ThemeConfig]>("theme-configs", default: [
    UITheme.tonal.rawValue: .tonalDefault,
    UITheme.glass.rawValue: .glassDefault,
    UITheme.neural.rawValue: .neuralDefault,
  ])

  // MARK: - Core Typing Engine
  static let currentVersion = Key<String>("current-version", default: "0.1")
  static let typingMethod = Key<TypingMethods>("typing-method", default: .Telex)
  static let allowedZWJF = Key<Bool>("allowed-zwjf", default: true)
  static let newStyleTonePlacement = Key<Bool>("new-style-tone-placement", default: true)
  static let autoTypoCorrection = Key<Bool>("auto-typo-correction", default: true)
  static let autoCapitalizeEnabled = Key<Bool>("auto-capitalize-enabled", default: true)
  static let freeMarkModeEnabled = Key<Bool>("free-mark-mode-enabled", default: false)
  static let nonLatinIMEAutoDisable = Key<Bool>("non-latin-ime-auto-disable", default: true)

  // MARK: - Hotkeys & HUD
  static let modifierOnlyToggleHotkey = Key<Int>(
    "modifier-only-toggle-hotkey",
    default: kDefaultModifierOnlyMask
  )
  static let hudEnabled = Key<Bool>("hud-enabled", default: true)
  static let hudOpacityPercent = Key<Int>("hud-opacity-percent", default: 75)

  // MARK: - Smart Switch & Per-App Sending
  static let smartSwitchEnabled = Key<Bool>("smart-switch-enabled", default: true)
  /// Danh sách cũ pre-1.7.0 — chỉ giữ để `StartupMigrations.migrateLegacySmartSwitchApps()`
  /// và import backup v1 chuyển đổi sang `appSmartSwitchConfigs`.
  static let smartSwitchApps = Key<[String]>("smart-switch-apps", default: [])
  static let didMigrateSpotlightKeepMode = Key<Bool>("did-migrate-spotlight-keep-mode", default: false)
  static let didMigrateLaunchersKeepMode = Key<Bool>("did-migrate-launchers-keep-mode", default: false)
  static let appSmartSwitchConfigs = Key<[String: AppSmartSwitchConfig]>(
    "app-smart-switch-configs",
    default: [:]
  )
  static let appSendingModes = Key<[String: AppSendingMode]>("app-sending-modes", default: [:])

  // MARK: - Macros
  static let macros = Key<[Macro]>("macros", default: [])
  static let macroEnabled = Key<Bool>("macro-enabled", default: true)
  static let macrosSeeded = Key<Bool>("macros-seeded", default: false)
  static let defaultMacrosVersion = Key<Int>("default-macros-version", default: 0)

  // MARK: - Spell Check & Personal Dictionary
  static let spellCheckEnabled = Key<Bool>("spell-check-enabled", default: true)
  static let englishAutoRestoreEnabled = Key<Bool>("english-auto-restore-enabled", default: true)
  static let restorePolicy = Key<RestorePolicy>("restore-policy", default: .vietnameseFirst)
  static let suggestionEnabled = Key<Bool>("suggestion-enabled", default: true)
  static let autoApplyHighConfidenceSuggestion = Key<Bool>(
    "auto-apply-high-confidence-suggestion",
    default: true
  )
  static let useEnVnReference = Key<Bool>("use-en-vn-reference", default: true)
  static let personalDictionaryEnabled = Key<Bool>("personal-dictionary-enabled", default: true)
  static let userAllowWords = Key<[String]>("user-allow-words", default: [])
  static let userKeepWords = Key<[String]>("user-keep-words", default: [])
  static let userDenyWords = Key<[String]>("user-deny-words", default: [])
  static let pendingDictSuggestions = Key<[PendingDictSuggestion]>(
    "pending-dict-suggestions",
    default: []
  )
  static let autoPersonalDictFeedback = Key<Bool>("auto-personal-dict-feedback", default: true)
  static let lastDictionaryCheckDate = Key<Date?>("last-dictionary-check-date", default: nil)

  // MARK: - Statistics & Updates
  static let statisticsEnabled = Key<Bool>("statistics-enabled", default: true)
  static let lastFeedbackWeekId = Key<String>("last-feedback-week-id", default: "")
  static let autoBackupOnUpgrade = Key<Bool>("auto-backup-on-upgrade", default: true)
  static let lastUpdateCheckDate = Key<Date?>("last-update-check-date", default: nil)
  static let autoUpdateEnabled = Key<Bool>("auto-update-enabled", default: true)
  static let pendingUpdateSuccessHUDVersion = Key<String>(
    "pending-update-success-hud-version",
    default: ""
  )
}
