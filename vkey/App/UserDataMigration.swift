//
//  UserDataMigration.swift
//  vkey
//
//  Backup & restore of user data — Defaults, macros, personal dictionaries,
//  per-app overrides, and (optionally) the rolling usage statistics.
//  Introduced in 1.5.0 to support the user's request:
//
//      "Khi cập nhật ứng dụng cũng sẽ yêu cầu lưu trữ dữ liệu cá nhân,
//       phiên bản mới sẽ tự lấy dữ liệu có sẵn hoặc nhập lại dữ liệu cũ
//       để tiếp tục sử dụng."
//
//  Design notes:
//
//  1. UserDefaults already survives app reinstalls as long as the bundle ID
//     stays the same. So in most cases nothing is lost on upgrade. The
//     export file is for two distinct use cases:
//       (a) machine-to-machine transfer (user gets a new Mac)
//       (b) recovery after a destructive reset / a major schema migration
//           where Defaults keys could be renamed or removed.
//
//  2. The export is a single self-contained JSON file with explicit field
//     names — no NSKeyedArchiver, no plist. Easy to inspect / sanitise / hand-
//     edit. Schema-versioned so a future vkey 2.x can still read it.
//
//  3. On every launch we check `Defaults[.currentVersion]` against the
//     running app's `CFBundleShortVersionString`. If they differ AND
//     `Defaults[.autoBackupOnUpgrade]` is on, the user is prompted to
//     export their data before we stamp the new version into Defaults.
//

import AppKit
import Defaults
import Foundation
import os.log

private let log = OSLog(subsystem: "dev.longht.vkey", category: "Migration")

// MARK: - Export shape

/// Schema-versioned snapshot of every piece of user-mutable state.
/// `schemaVersion` is bumped only when older readers can no longer make
/// sense of newer files; additive fields go through optional decoding.
struct UserDataExport: Codable {
  let schemaVersion: Int
  let exportedAt: Date
  let appVersion: String      // CFBundleShortVersionString at export time
  let appBuild: String        // CFBundleVersion at export time

  // Engine + UI preferences
  let typingMethod: String?            // "Telex" / "VNI"
  let newStyleTonePlacement: Bool?
  let autoTypoCorrection: Bool?
  let allowedZWJF: Bool?
  let hudEnabled: Bool?
  let modifierOnlyToggleHotkey: Int?
  let modifierOnlyTextToolsHotkey: Int?

  // Smart Switch
  let smartSwitchEnabled: Bool?
  let smartSwitchApps: [String]?
  let perAppOverride: [String: String]?

  // Spell check + suggestion
  let spellCheckEnabled: Bool?
  let spellCheckInSentenceEnabled: Bool?
  let englishAutoRestoreEnabled: Bool?
  let restorePolicy: String?           // raw value
  let suggestionEnabled: Bool?
  let autoApplyHighConfidenceSuggestion: Bool?
  let useEnVnReference: Bool?

  // Personal dictionary
  let personalDictionaryEnabled: Bool?
  let userAllowWords: [String]?
  let userKeepWords: [String]?
  let userDenyWords: [String]?

  // Macros
  let macros: [MacroSeed]?
  let macroEnabled: Bool?           // 1.5.3+
  let macrosSeeded: Bool?           // 1.5.3+
  let defaultMacrosVersion: Int?    // 1.5.5+

  // Theme (1.5.3+)
  let appTheme: String?             // AppTheme raw value
  let uiTheme: String?
  let accentColorChoice: String?
  let appearanceMode: String?
  let themeConfigs: [String: ThemeConfig]?

  // 1.5.5+: auto-feedback toggle for performWeeklyFeedback.
  let autoPersonalDictFeedback: Bool?

  // 1.7.6+: full settings backup — bổ sung 9 fields trước đây bị bỏ sót.
  let wordPredictionEnabled: Bool?
  let wordPredictionExcludedApps: [String]?
  let predictionHUDLineOffset: Int?
  let predictionHUDFontSize: Int?
  let predictionMaxWords: Int?
  let hudOpacityPercent: Int?
  let appSmartSwitchConfigs: [String: AppSmartSwitchConfig]?  // 1.7.0+ per-app 3-state
  let translationHUDEnabled: Bool?
  let translationHUDDurationMs: Double?
  let programmingMode: Bool?
  let quickConfigPreset: Int?
  let autoCapitalizeEnabled: Bool?
  let nonLatinIMEAutoDisable: Bool?
  let windowTitleRules: [WindowTitleRule]?
  let freeMarkModeEnabled: Bool?
  let cgEventRaceHardeningEnabled: Bool?
  let cgEventFlushDelayMs: Int?
  let clipboardHistoryEnabled: Bool?
  let clipboardHistoryCapacity: Int?
  let clipboardHistoryContentMode: String?
  let clipboardHistoryMaxEntryMegabytes: Int?
  let userBigrams: [String: [String: Int]]?
  let userTrigrams: [String: [String: Int]]?
  let statisticsEnabled: Bool?
  let autoBackupOnUpgrade: Bool?

  // Statistics — 1.7.6+: full WeekBucketExport (raw frequency tables, streaks,
  // phrases, per-app language). File backup v1 chỉ có UsageSummary (top 10%
  // summary). Decode backward-compat ở init(from:) bên dưới.
  let statistics: [WeekBucketExport]?

  static let currentSchemaVersion = 2  // 1.7.6+: bumped vì statistics đổi shape

  // MARK: - Backward-compat decode
  // File backup v1 (schemaVersion=1) có statistics: [UsageSummary]. Decode
  // failover: thử [WeekBucketExport] trước, fallback [UsageSummary] → bridge
  // sang WeekBucketExport (lossy: raw maps rỗng, chỉ giữ top words).
  enum CodingKeys: String, CodingKey {
    case schemaVersion, exportedAt, appVersion, appBuild
    case typingMethod, newStyleTonePlacement, autoTypoCorrection, allowedZWJF
    case hudEnabled, modifierOnlyToggleHotkey, modifierOnlyTextToolsHotkey
    case smartSwitchEnabled, smartSwitchApps, perAppOverride
    case spellCheckEnabled, spellCheckInSentenceEnabled, englishAutoRestoreEnabled
    case restorePolicy, suggestionEnabled, autoApplyHighConfidenceSuggestion
    case useEnVnReference
    case personalDictionaryEnabled, userAllowWords, userKeepWords, userDenyWords
    case macros, macroEnabled, macrosSeeded, defaultMacrosVersion
    case appTheme, uiTheme, accentColorChoice, appearanceMode, themeConfigs
    case autoPersonalDictFeedback
    case wordPredictionEnabled, wordPredictionExcludedApps, predictionHUDLineOffset, predictionHUDFontSize
    case predictionMaxWords
    case hudOpacityPercent, appSmartSwitchConfigs
    case translationHUDEnabled, translationHUDDurationMs, programmingMode
    case quickConfigPreset, autoCapitalizeEnabled, nonLatinIMEAutoDisable
    case windowTitleRules, freeMarkModeEnabled, cgEventRaceHardeningEnabled
    case cgEventFlushDelayMs
    case clipboardHistoryEnabled, clipboardHistoryCapacity, clipboardHistoryContentMode
    case clipboardHistoryMaxEntryMegabytes
    case userBigrams, userTrigrams, statisticsEnabled, autoBackupOnUpgrade
    case statistics
  }

  init(
    schemaVersion: Int, exportedAt: Date, appVersion: String, appBuild: String,
    typingMethod: String?, newStyleTonePlacement: Bool?, autoTypoCorrection: Bool?,
    allowedZWJF: Bool?, hudEnabled: Bool?, modifierOnlyToggleHotkey: Int?,
    modifierOnlyTextToolsHotkey: Int? = nil,
    smartSwitchEnabled: Bool?, smartSwitchApps: [String]?, perAppOverride: [String: String]?,
    spellCheckEnabled: Bool?, spellCheckInSentenceEnabled: Bool?,
    englishAutoRestoreEnabled: Bool?, restorePolicy: String?,
    suggestionEnabled: Bool?, autoApplyHighConfidenceSuggestion: Bool?,
    useEnVnReference: Bool?,
    personalDictionaryEnabled: Bool?,
    userAllowWords: [String]?, userKeepWords: [String]?, userDenyWords: [String]?,
    macros: [MacroSeed]?,
    macroEnabled: Bool?, macrosSeeded: Bool?, defaultMacrosVersion: Int?,
    appTheme: String?,
    uiTheme: String? = nil,
    accentColorChoice: String? = nil,
    appearanceMode: String? = nil,
    themeConfigs: [String: ThemeConfig]? = nil,
    autoPersonalDictFeedback: Bool?,
    wordPredictionEnabled: Bool? = nil,
    wordPredictionExcludedApps: [String]? = nil,
    predictionHUDLineOffset: Int? = nil,
    predictionHUDFontSize: Int? = nil,
    predictionMaxWords: Int? = nil,
    hudOpacityPercent: Int? = nil,
    appSmartSwitchConfigs: [String: AppSmartSwitchConfig]? = nil,
    translationHUDEnabled: Bool? = nil,
    translationHUDDurationMs: Double? = nil,
    programmingMode: Bool? = nil,
    quickConfigPreset: Int? = nil,
    autoCapitalizeEnabled: Bool? = nil,
    nonLatinIMEAutoDisable: Bool? = nil,
    windowTitleRules: [WindowTitleRule]? = nil,
    freeMarkModeEnabled: Bool? = nil,
    cgEventRaceHardeningEnabled: Bool? = nil,
    cgEventFlushDelayMs: Int? = nil,
    clipboardHistoryEnabled: Bool? = nil,
    clipboardHistoryCapacity: Int? = nil,
    clipboardHistoryContentMode: String? = nil,
    clipboardHistoryMaxEntryMegabytes: Int? = nil,
    userBigrams: [String: [String: Int]]? = nil,
    userTrigrams: [String: [String: Int]]? = nil,
    statisticsEnabled: Bool? = nil,
    autoBackupOnUpgrade: Bool? = nil,
    statistics: [WeekBucketExport]?
  ) {
    self.schemaVersion = schemaVersion
    self.exportedAt = exportedAt
    self.appVersion = appVersion
    self.appBuild = appBuild
    self.typingMethod = typingMethod
    self.newStyleTonePlacement = newStyleTonePlacement
    self.autoTypoCorrection = autoTypoCorrection
    self.allowedZWJF = allowedZWJF
    self.hudEnabled = hudEnabled
    self.modifierOnlyToggleHotkey = modifierOnlyToggleHotkey
    self.modifierOnlyTextToolsHotkey = modifierOnlyTextToolsHotkey
    self.smartSwitchEnabled = smartSwitchEnabled
    self.smartSwitchApps = smartSwitchApps
    self.perAppOverride = perAppOverride
    self.spellCheckEnabled = spellCheckEnabled
    self.spellCheckInSentenceEnabled = spellCheckInSentenceEnabled
    self.englishAutoRestoreEnabled = englishAutoRestoreEnabled
    self.restorePolicy = restorePolicy
    self.suggestionEnabled = suggestionEnabled
    self.autoApplyHighConfidenceSuggestion = autoApplyHighConfidenceSuggestion
    self.useEnVnReference = useEnVnReference
    self.personalDictionaryEnabled = personalDictionaryEnabled
    self.userAllowWords = userAllowWords
    self.userKeepWords = userKeepWords
    self.userDenyWords = userDenyWords
    self.macros = macros
    self.macroEnabled = macroEnabled
    self.macrosSeeded = macrosSeeded
    self.defaultMacrosVersion = defaultMacrosVersion
    self.appTheme = appTheme
    self.uiTheme = uiTheme
    self.accentColorChoice = accentColorChoice
    self.appearanceMode = appearanceMode
    self.themeConfigs = themeConfigs
    self.autoPersonalDictFeedback = autoPersonalDictFeedback
    self.wordPredictionEnabled = wordPredictionEnabled
    self.wordPredictionExcludedApps = wordPredictionExcludedApps
    self.predictionHUDLineOffset = predictionHUDLineOffset
    self.predictionHUDFontSize = predictionHUDFontSize
    self.predictionMaxWords = predictionMaxWords
    self.hudOpacityPercent = hudOpacityPercent
    self.appSmartSwitchConfigs = appSmartSwitchConfigs
    self.translationHUDEnabled = translationHUDEnabled
    self.translationHUDDurationMs = translationHUDDurationMs
    self.programmingMode = programmingMode
    self.quickConfigPreset = quickConfigPreset
    self.autoCapitalizeEnabled = autoCapitalizeEnabled
    self.nonLatinIMEAutoDisable = nonLatinIMEAutoDisable
    self.windowTitleRules = windowTitleRules
    self.freeMarkModeEnabled = freeMarkModeEnabled
    self.cgEventRaceHardeningEnabled = cgEventRaceHardeningEnabled
    self.cgEventFlushDelayMs = cgEventFlushDelayMs
    self.clipboardHistoryEnabled = clipboardHistoryEnabled
    self.clipboardHistoryCapacity = clipboardHistoryCapacity
    self.clipboardHistoryContentMode = clipboardHistoryContentMode
    self.clipboardHistoryMaxEntryMegabytes = clipboardHistoryMaxEntryMegabytes
    self.userBigrams = userBigrams
    self.userTrigrams = userTrigrams
    self.statisticsEnabled = statisticsEnabled
    self.autoBackupOnUpgrade = autoBackupOnUpgrade
    self.statistics = statistics
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    self.exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
    self.appVersion = try c.decodeIfPresent(String.self, forKey: .appVersion) ?? ""
    self.appBuild = try c.decodeIfPresent(String.self, forKey: .appBuild) ?? ""
    self.typingMethod = try c.decodeIfPresent(String.self, forKey: .typingMethod)
    self.newStyleTonePlacement = try c.decodeIfPresent(Bool.self, forKey: .newStyleTonePlacement)
    self.autoTypoCorrection = try c.decodeIfPresent(Bool.self, forKey: .autoTypoCorrection)
    self.allowedZWJF = try c.decodeIfPresent(Bool.self, forKey: .allowedZWJF)
    self.hudEnabled = try c.decodeIfPresent(Bool.self, forKey: .hudEnabled)
    self.modifierOnlyToggleHotkey = try c.decodeIfPresent(Int.self, forKey: .modifierOnlyToggleHotkey)
    self.modifierOnlyTextToolsHotkey = try c.decodeIfPresent(Int.self, forKey: .modifierOnlyTextToolsHotkey)
    self.smartSwitchEnabled = try c.decodeIfPresent(Bool.self, forKey: .smartSwitchEnabled)
    self.smartSwitchApps = try c.decodeIfPresent([String].self, forKey: .smartSwitchApps)
    self.perAppOverride = try c.decodeIfPresent([String: String].self, forKey: .perAppOverride)
    self.spellCheckEnabled = try c.decodeIfPresent(Bool.self, forKey: .spellCheckEnabled)
    self.spellCheckInSentenceEnabled = try c.decodeIfPresent(Bool.self, forKey: .spellCheckInSentenceEnabled)
    self.englishAutoRestoreEnabled = try c.decodeIfPresent(Bool.self, forKey: .englishAutoRestoreEnabled)
    self.restorePolicy = try c.decodeIfPresent(String.self, forKey: .restorePolicy)
    self.suggestionEnabled = try c.decodeIfPresent(Bool.self, forKey: .suggestionEnabled)
    self.autoApplyHighConfidenceSuggestion = try c.decodeIfPresent(Bool.self, forKey: .autoApplyHighConfidenceSuggestion)
    self.useEnVnReference = try c.decodeIfPresent(Bool.self, forKey: .useEnVnReference)
    self.personalDictionaryEnabled = try c.decodeIfPresent(Bool.self, forKey: .personalDictionaryEnabled)
    self.userAllowWords = try c.decodeIfPresent([String].self, forKey: .userAllowWords)
    self.userKeepWords = try c.decodeIfPresent([String].self, forKey: .userKeepWords)
    self.userDenyWords = try c.decodeIfPresent([String].self, forKey: .userDenyWords)
    self.macros = try c.decodeIfPresent([MacroSeed].self, forKey: .macros)
    self.macroEnabled = try c.decodeIfPresent(Bool.self, forKey: .macroEnabled)
    self.macrosSeeded = try c.decodeIfPresent(Bool.self, forKey: .macrosSeeded)
    self.defaultMacrosVersion = try c.decodeIfPresent(Int.self, forKey: .defaultMacrosVersion)
    self.appTheme = try c.decodeIfPresent(String.self, forKey: .appTheme)
    self.uiTheme = try c.decodeIfPresent(String.self, forKey: .uiTheme)
    self.accentColorChoice = try c.decodeIfPresent(String.self, forKey: .accentColorChoice)
    self.appearanceMode = try c.decodeIfPresent(String.self, forKey: .appearanceMode)
    self.themeConfigs = try c.decodeIfPresent([String: ThemeConfig].self, forKey: .themeConfigs)
    self.autoPersonalDictFeedback = try c.decodeIfPresent(Bool.self, forKey: .autoPersonalDictFeedback)
    // 1.7.6+ fields — optional cho file v1.x cũ.
    self.wordPredictionEnabled = try c.decodeIfPresent(Bool.self, forKey: .wordPredictionEnabled)
    self.wordPredictionExcludedApps = try c.decodeIfPresent([String].self, forKey: .wordPredictionExcludedApps)
    self.predictionHUDLineOffset = try c.decodeIfPresent(Int.self, forKey: .predictionHUDLineOffset)
    self.predictionHUDFontSize = try c.decodeIfPresent(Int.self, forKey: .predictionHUDFontSize)
    self.predictionMaxWords = try c.decodeIfPresent(Int.self, forKey: .predictionMaxWords)
    self.hudOpacityPercent = try c.decodeIfPresent(Int.self, forKey: .hudOpacityPercent)
    self.appSmartSwitchConfigs = try c.decodeIfPresent([String: AppSmartSwitchConfig].self,
                                                      forKey: .appSmartSwitchConfigs)
    self.translationHUDEnabled = try c.decodeIfPresent(Bool.self, forKey: .translationHUDEnabled)
    self.translationHUDDurationMs = try c.decodeIfPresent(Double.self, forKey: .translationHUDDurationMs)
    self.programmingMode = try c.decodeIfPresent(Bool.self, forKey: .programmingMode)
    self.quickConfigPreset = try c.decodeIfPresent(Int.self, forKey: .quickConfigPreset)
    self.autoCapitalizeEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoCapitalizeEnabled)
    self.nonLatinIMEAutoDisable = try c.decodeIfPresent(Bool.self, forKey: .nonLatinIMEAutoDisable)
    self.windowTitleRules = try c.decodeIfPresent([WindowTitleRule].self, forKey: .windowTitleRules)
    self.freeMarkModeEnabled = try c.decodeIfPresent(Bool.self, forKey: .freeMarkModeEnabled)
    self.cgEventRaceHardeningEnabled = try c.decodeIfPresent(Bool.self, forKey: .cgEventRaceHardeningEnabled)
    self.cgEventFlushDelayMs = try c.decodeIfPresent(Int.self, forKey: .cgEventFlushDelayMs)
    self.clipboardHistoryEnabled = try c.decodeIfPresent(Bool.self, forKey: .clipboardHistoryEnabled)
    self.clipboardHistoryCapacity = try c.decodeIfPresent(Int.self, forKey: .clipboardHistoryCapacity)
    self.clipboardHistoryContentMode = try c.decodeIfPresent(String.self, forKey: .clipboardHistoryContentMode)
    self.clipboardHistoryMaxEntryMegabytes = try c.decodeIfPresent(Int.self, forKey: .clipboardHistoryMaxEntryMegabytes)
    self.userBigrams = try c.decodeIfPresent([String: [String: Int]].self, forKey: .userBigrams)
    self.userTrigrams = try c.decodeIfPresent([String: [String: Int]].self, forKey: .userTrigrams)
    self.statisticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .statisticsEnabled)
    self.autoBackupOnUpgrade = try c.decodeIfPresent(Bool.self, forKey: .autoBackupOnUpgrade)
    // Statistics — try v2 ([WeekBucketExport]) trước, fallback v1 ([UsageSummary]).
    if let buckets = try? c.decodeIfPresent([WeekBucketExport].self, forKey: .statistics) {
      self.statistics = buckets
    } else if let summaries = try? c.decodeIfPresent([UsageSummary].self, forKey: .statistics) {
      // Bridge v1 → v2: raw maps rỗng, chỉ giữ top words counts.
      self.statistics = summaries.map { s in
        WeekBucketExport(
          weekId: s.weekId, weekEnd: s.weekEnd,
          wordsTotal: s.wordsTotal,
          wordsKeptVietnamese: s.wordsKeptVietnamese,
          wordsRestoredEnglish: s.wordsRestoredEnglish,
          wordsKeptRaw: s.wordsKeptRaw,
          wordsSuggested: s.wordsSuggested,
          smartSwitchFires: s.smartSwitchFires,
          typoCorrectionsApplied: s.typoCorrectionsApplied,
          vnWordCounts: Dictionary(uniqueKeysWithValues: s.topVietnameseWords.map { ($0.word, $0.count) }),
          enWordCounts: Dictionary(uniqueKeysWithValues: s.topEnglishWords.map { ($0.word, $0.count) }),
          appCounts: Dictionary(uniqueKeysWithValues: s.topApps.map { ($0.word, $0.count) }),
          vnKeepStreak: [:], enRestoreStreak: [:],
          vnPhraseCounts2: [:], vnPhraseCounts3: [:],
          appLanguageVnCounts: [:], appLanguageEnCounts: [:], appLanguageDays: [:]
        )
      }
    } else {
      self.statistics = nil
    }
  }
}

// MARK: - Migration namespace

enum UserDataMigration {

  // MARK: Export

  /// Build a `UserDataExport` from the running app's current state.
  static func currentExport(includeStatistics: Bool = true) -> UserDataExport {
    let ngrams = NGramStore.shared.snapshot()
    return UserDataExport(
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
      modifierOnlyTextToolsHotkey: Defaults[.modifierOnlyTextToolsHotkey],

      smartSwitchEnabled: Defaults[.smartSwitchEnabled],
      smartSwitchApps: Defaults[.smartSwitchApps],
      perAppOverride: Defaults[.perAppOverride],

      spellCheckEnabled: Defaults[.spellCheckEnabled],
      spellCheckInSentenceEnabled: Defaults[.spellCheckInSentenceEnabled],
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

      appTheme: nil, // 2.16: AppTheme đã xoá — giữ field để backup cũ vẫn decode
      uiTheme: Defaults[.uiTheme].rawValue,
      accentColorChoice: Defaults[.accentColorChoice].rawValue,
      appearanceMode: Defaults[.appearanceMode].rawValue,
      themeConfigs: Defaults[.themeConfigs],

      autoPersonalDictFeedback: Defaults[.autoPersonalDictFeedback],

      // 1.7.6+: full settings backup
      wordPredictionEnabled: Defaults[.wordPredictionEnabled],
      wordPredictionExcludedApps: Defaults[.wordPredictionExcludedApps],
      predictionHUDLineOffset: Defaults[.predictionHUDLineOffset],
      predictionHUDFontSize: Defaults[.predictionHUDFontSize],
      predictionMaxWords: Defaults[.predictionMaxWords],
      hudOpacityPercent: Defaults[.hudOpacityPercent],
      appSmartSwitchConfigs: Defaults[.appSmartSwitchConfigs],
      translationHUDEnabled: Defaults[.translationHUDEnabled],
      translationHUDDurationMs: Defaults[.translationHUDDurationMs],
      programmingMode: Defaults[.programmingMode],
      quickConfigPreset: Defaults[.quickConfigPreset],
      autoCapitalizeEnabled: Defaults[.autoCapitalizeEnabled],
      nonLatinIMEAutoDisable: Defaults[.nonLatinIMEAutoDisable],
      windowTitleRules: Defaults[.windowTitleRules],
      freeMarkModeEnabled: Defaults[.freeMarkModeEnabled],
      cgEventRaceHardeningEnabled: Defaults[.cgEventRaceHardeningEnabled],
      cgEventFlushDelayMs: Defaults[.cgEventFlushDelayMs],
      clipboardHistoryEnabled: Defaults[.clipboardHistoryEnabled],
      clipboardHistoryCapacity: Defaults[.clipboardHistoryCapacity],
      clipboardHistoryContentMode: Defaults[.clipboardHistoryContentMode].rawValue,
      clipboardHistoryMaxEntryMegabytes: Defaults[.clipboardHistoryMaxEntryMegabytes],
      userBigrams: ngrams.bigrams,
      userTrigrams: ngrams.trigrams,
      statisticsEnabled: Defaults[.statisticsEnabled],
      autoBackupOnUpgrade: Defaults[.autoBackupOnUpgrade],

      // 1.9.0: tôn trọng `statisticsEnabled` — không export stats data nếu
      // user đã tắt. Trước v1.9 export anyway → user gặp privacy gap khi
      // chia sẻ backup file (stats vẫn còn dù user nghĩ đã tắt).
      statistics: (includeStatistics && Defaults[.statisticsEnabled])
        ? UsageStatistics.shared.allWeekBucketsForExport() : nil
    )
  }

  /// Encode an export to JSON. Pretty-printed + sorted keys so backup files
  /// are diffable.
  static func encode(_ export: UserDataExport) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(export)
  }

  /// Write an export to disk atomically.
  static func writeAtomically(to url: URL, export: UserDataExport) throws {
    let data = try encode(export)
    try data.write(to: url, options: .atomic)
  }

  /// Suggested default backup location:
  /// `~/Library/Application Support/vkey/backups/vkey-backup-<version>-<date>.json`.
  static func defaultBackupURL() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let dir = appSupport.appendingPathComponent("vkey/backups", isDirectory: true)
    try? FileManager.default.createDirectory(
      at: dir, withIntermediateDirectories: true, attributes: nil
    )

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let stamp = formatter.string(from: Date())
    let name = "vkey-backup-\(Bundle.main.appVersionLong)-\(stamp).json"
    return dir.appendingPathComponent(name)
  }

  /// 1.9.0: dọn dẹp backup cũ. Giữ ≥5 file gần nhất; xóa file > 30 ngày
  /// nếu vượt 5 file giữ. Gọi từ AppDelegate.applicationDidFinishLaunching
  /// (silent, không cản trở user). Tránh ~/Library/Application Support/vkey/
  /// backups/ tích lũy vô hạn theo thời gian.
  @discardableResult
  static func cleanupOldBackups() -> Int {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let dir = appSupport.appendingPathComponent("vkey/backups", isDirectory: true)

    guard let urls = try? FileManager.default.contentsOfDirectory(
      at: dir,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ).filter({ $0.pathExtension == "json" }) else { return 0 }

    // Sắp xếp theo mod date desc (mới nhất trước).
    let sorted = urls.sorted { a, b in
      let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return da > db
    }

    // Giữ 5 file đầu (mới nhất). Trong số còn lại, xóa nếu > 30 ngày.
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

  // MARK: Import

  /// Decode a file back into a `UserDataExport`. Forward-compatible: unknown
  /// fields are ignored.
  static func loadFrom(_ url: URL) throws -> UserDataExport {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(UserDataExport.self, from: data)
  }

  /// Apply an export to the running app's Defaults. Returns a short list of
  /// human-readable change descriptions so the Settings UI can summarise.
  ///
  /// **Merge policy** — chosen to be safe by default:
  /// - Scalar settings (toggles, pickers) are overwritten unconditionally
  ///   when present in the import.
  /// - List settings (smartSwitchApps, userAllowWords, macros, …) are
  ///   **merged**, not replaced. Existing entries the user added since the
  ///   backup remain. To overwrite, call with `replaceLists: true`.
  @discardableResult
  static func importExport(
    _ export: UserDataExport,
    replaceLists: Bool = false
  ) -> [String] {
    var changes: [String] = []

    func applyScalar<T: Equatable>(_ key: Defaults.Key<T>, _ value: T?, label: String) {
      guard let value = value else { return }
      if Defaults[key] != value {
        Defaults[key] = value
        changes.append("\(label) ← \(value)")
      }
    }

    // Engine + UI
    if let tm = export.typingMethod,
       let parsed = TypingMethods(rawValue: tm),
       Defaults[.typingMethod] != parsed {
      Defaults[.typingMethod] = parsed
      changes.append("Kiểu gõ ← \(tm)")
    }
    applyScalar(.newStyleTonePlacement, export.newStyleTonePlacement, label: "Kiểu đặt dấu (mới)")
    applyScalar(.autoTypoCorrection, export.autoTypoCorrection, label: "Auto typo correction")
    applyScalar(.allowedZWJF, export.allowedZWJF, label: "Phụ âm z, w, j, f")
    applyScalar(.hudEnabled, export.hudEnabled, label: "HUD")
    applyScalar(.modifierOnlyToggleHotkey, export.modifierOnlyToggleHotkey,
                label: "Modifier-only hotkey")
    applyScalar(.modifierOnlyTextToolsHotkey, export.modifierOnlyTextToolsHotkey,
                label: "Text Tools modifier-only hotkey")

    // Smart Switch
    applyScalar(.smartSwitchEnabled, export.smartSwitchEnabled, label: "Smart Switch")
    mergeStringList(.smartSwitchApps, export.smartSwitchApps,
                    replace: replaceLists, label: "Smart Switch apps",
                    into: &changes)
    mergeStringDict(.perAppOverride, export.perAppOverride,
                    replace: replaceLists, label: "Per-app override",
                    into: &changes)

    // Spell check
    applyScalar(.spellCheckEnabled, export.spellCheckEnabled, label: "Kiểm tra chính tả")
    applyScalar(.spellCheckInSentenceEnabled, export.spellCheckInSentenceEnabled,
                label: "Kiểm tra trong câu")
    applyScalar(.englishAutoRestoreEnabled, export.englishAutoRestoreEnabled,
                label: "Auto restore tiếng Anh")
    if let rp = export.restorePolicy, let parsed = RestorePolicy(rawValue: rp),
       Defaults[.restorePolicy] != parsed {
      Defaults[.restorePolicy] = parsed
      changes.append("Chính sách khôi phục ← \(rp)")
    }
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
                    replace: replaceLists, label: "Allow words", into: &changes)
    mergeStringList(.userKeepWords, export.userKeepWords,
                    replace: replaceLists, label: "Keep words", into: &changes)
    mergeStringList(.userDenyWords, export.userDenyWords,
                    replace: replaceLists, label: "Deny words", into: &changes)

    // 1.7.7: macros — "Ghi đè" clear+replace toàn bộ; "Kết hợp" union với
    // imported wins khi trùng `from`. Trước đây bug: replace mode append
    // imported vào existing default (duplicate); merge mode existing wins.
    if let importMacros = export.macros {
      let imported = importMacros
        .filter { !$0.from.isEmpty }
        .map { Macro(from: $0.from, to: $0.to) }
      if replaceLists {
        if Defaults[.macros] != imported {
          Defaults[.macros] = imported
          changes.append("Macros: \(imported.count) (overwrite)")
        }
      } else {
        var current = Defaults[.macros]
        let importedFroms = Set(imported.map { $0.from })
        current.removeAll { importedFroms.contains($0.from) }
        current.append(contentsOf: imported)
        if Defaults[.macros] != current {
          Defaults[.macros] = current
          changes.append("Macros: +\(imported.count) (merge, file ưu tiên)")
        }
      }
    }
    applyScalar(.macroEnabled, export.macroEnabled, label: "Bật macro")
    applyScalar(.macrosSeeded, export.macrosSeeded, label: "Macro đã seed")
    applyScalar(.defaultMacrosVersion, export.defaultMacrosVersion,
                label: "Default macros version")

    // 2.16: AppTheme đã xoá — bỏ qua field appTheme trong backup cũ.
    if let raw = export.uiTheme, let parsed = UITheme(rawValue: raw),
       Defaults[.uiTheme] != parsed {
      Defaults[.uiTheme] = parsed
      changes.append("Theme UI ← \(raw)")
    }
    if let raw = export.accentColorChoice, let parsed = AccentColorChoice(rawValue: raw),
       Defaults[.accentColorChoice] != parsed {
      Defaults[.accentColorChoice] = parsed
      changes.append("Màu nhấn ← \(raw)")
    }
    if let raw = export.appearanceMode, let parsed = AppearanceMode(rawValue: raw),
       Defaults[.appearanceMode] != parsed {
      Defaults[.appearanceMode] = parsed
      changes.append("Chế độ giao diện ← \(raw)")
    }
    applyScalar(.themeConfigs, export.themeConfigs, label: "Cấu hình theme")

    // 1.5.5+: auto-feedback toggle
    applyScalar(.autoPersonalDictFeedback, export.autoPersonalDictFeedback,
                label: "Tự động cập nhật từ điển cá nhân")

    // 1.7.6+: previously-missing scalar settings
    applyScalar(.wordPredictionEnabled, export.wordPredictionEnabled,
                label: "Đoán từ tiếp theo")
    mergeStringList(.wordPredictionExcludedApps, export.wordPredictionExcludedApps,
                    replace: replaceLists, label: "App loại trừ đoán từ", into: &changes)
    applyScalar(.predictionHUDLineOffset, export.predictionHUDLineOffset,
                label: "Khoảng cách HUD dự đoán")
    applyScalar(.predictionHUDFontSize, export.predictionHUDFontSize,
                label: "Cỡ chữ HUD dự đoán")
    applyScalar(.predictionMaxWords, export.predictionMaxWords,
                label: "Số từ gợi ý tối đa")
    applyScalar(.hudOpacityPercent, export.hudOpacityPercent,
                label: "Độ trong suốt HUD")
    applyScalar(.translationHUDEnabled, export.translationHUDEnabled,
                label: "HUD dịch")
    applyScalar(.translationHUDDurationMs, export.translationHUDDurationMs,
                label: "Thời lượng HUD dịch (ms)")
    applyScalar(.programmingMode, export.programmingMode,
                label: "Chế độ lập trình")
    applyScalar(.quickConfigPreset, export.quickConfigPreset,
                label: "Preset cấu hình nhanh")
    applyScalar(.autoCapitalizeEnabled, export.autoCapitalizeEnabled,
                label: "Tự viết hoa đầu câu")
    applyScalar(.nonLatinIMEAutoDisable, export.nonLatinIMEAutoDisable,
                label: "Tự tắt khi dùng IME non-Latin")
    applyScalar(.freeMarkModeEnabled, export.freeMarkModeEnabled,
                label: "Free Mark Mode")
    applyScalar(.cgEventRaceHardeningEnabled, export.cgEventRaceHardeningEnabled,
                label: "CGEvent race hardening")
    applyScalar(.cgEventFlushDelayMs, export.cgEventFlushDelayMs,
                label: "CGEvent flush delay (ms)")
    applyScalar(.clipboardHistoryEnabled, export.clipboardHistoryEnabled,
                label: "Lịch sử clipboard")
    applyScalar(.clipboardHistoryCapacity, export.clipboardHistoryCapacity,
                label: "Số mục lịch sử clipboard")
    applyScalar(.clipboardHistoryMaxEntryMegabytes, export.clipboardHistoryMaxEntryMegabytes,
                label: "Dung lượng tối đa mục clipboard (MB)")
    if let mode = export.clipboardHistoryContentMode,
       let parsed = ClipboardHistoryContentMode(rawValue: mode) {
      if Defaults[.clipboardHistoryContentMode] != parsed {
        Defaults[.clipboardHistoryContentMode] = parsed
        changes.append("Chế độ lịch sử clipboard: \(mode)")
      }
    }
    applyScalar(.statisticsEnabled, export.statisticsEnabled,
                label: "Bật thống kê")
    applyScalar(.autoBackupOnUpgrade, export.autoBackupOnUpgrade,
                label: "Tự sao lưu khi cập nhật")

    mergeWindowTitleRules(export.windowTitleRules,
                          replace: replaceLists, into: &changes)

    // 1.7.6+: per-app Smart Switch configs (critical — 1.7.0+ 3-state).
    // 1.7.7: merge mode đảo sang imported wins (file thắng khi trùng bundle id).
    if let configs = export.appSmartSwitchConfigs {
      if replaceLists {
        if Defaults[.appSmartSwitchConfigs] != configs {
          Defaults[.appSmartSwitchConfigs] = configs
          changes.append("Smart Switch per-app: \(configs.count) (overwrite)")
        }
      } else {
        var current = Defaults[.appSmartSwitchConfigs]
        var changed = 0
        for (key, value) in configs where current[key] != value {
          current[key] = value
          changed += 1
        }
        if changed > 0 {
          Defaults[.appSmartSwitchConfigs] = current
          changes.append("Smart Switch per-app: +\(changed) (merge, file ưu tiên)")
        }
      }
    }

    // 1.7.6+: bigram/trigram (prediction learning data).
    // 1.7.7: merge mode đảo sang imported wins — file thắng khi trùng (prev, next).
    // 1.7.x: storage chuyển sang NGramStore (file-backed), không qua Defaults.
    let importBi = export.userBigrams ?? [:]
    let importTri = export.userTrigrams ?? [:]
    if replaceLists {
      if !importBi.isEmpty || !importTri.isEmpty {
        NGramStore.shared.replaceAll(bigrams: importBi, trigrams: importTri)
        if !importBi.isEmpty { changes.append("Bigram dự đoán: \(importBi.count) (overwrite)") }
        if !importTri.isEmpty { changes.append("Trigram dự đoán: \(importTri.count) (overwrite)") }
      }
    } else if !importBi.isEmpty || !importTri.isEmpty {
      let (biChanged, triChanged) = NGramStore.shared.merge(bigrams: importBi, trigrams: importTri)
      if biChanged > 0 { changes.append("Bigram dự đoán: +\(biChanged) (merge, file ưu tiên)") }
      if triChanged > 0 { changes.append("Trigram dự đoán: +\(triChanged) (merge, file ưu tiên)") }
    }

    // 1.7.6+: stats restoration. Trước đây bỏ qua hoàn toàn → tab Thống kê
    // hiện 0 sau import. Match weekId hiện tại → load thành in-memory
    // counters; tuần cũ → ghi file `<weekId>.json`.
    // 1.7.7: khi "Ghi đè" (replaceLists), xoá sạch stats hiện có trước khi
    // restore — tránh tích luỹ tuần default + tuần imported.
    if let stats = export.statistics, !stats.isEmpty {
      if replaceLists {
        UsageStatistics.shared.clearAll()
      }
      let restored = UsageStatistics.shared.restoreFromBackup(stats)
      if restored > 0 {
        let mode = replaceLists ? "(overwrite)" : "(merge)"
        changes.append("Thống kê: khôi phục \(restored) tuần \(mode)")
      }
    }

    os_log("UserDataMigration: applied import with %d changes",
           log: log, type: .info, changes.count)
    return changes
  }

  // MARK: Version handoff

  /// Called from `applicationDidFinishLaunching`. If the persisted last-seen
  /// version differs from the running version *and* the user has
  /// `autoBackupOnUpgrade` enabled, surface an NSAlert offering to save a
  /// backup file before the new version starts mutating Defaults.
  ///
  /// Returns true if the version stamp was updated (i.e. the user has
  /// accepted the upgrade).
  @discardableResult
  static func handleVersionChange() -> Bool {
    // Dọn rác Defaults keys đã xoá ở 1.5.3 trở đi. Idempotent — gọi nhiều
    // lần không sao. Chạy mọi launch để bao quát cả user mới upgrade.
    UserDefaults.standard.removeObject(forKey: "dictionary-update-channel")
    UserDefaults.standard.removeObject(forKey: "dictionary-github-update-enabled")

    let persisted = Defaults[.currentVersion]
    let running = Bundle.main.appVersionLong
    guard persisted != "0.1", persisted != running else {
      // First launch ever (persisted == "0.1") OR no change — just stamp.
      Defaults[.currentVersion] = running
      return persisted != running
    }

    guard Defaults[.autoBackupOnUpgrade] else {
      Defaults[.currentVersion] = running
      return true
    }

    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.messageText = "vkey đã được cập nhật lên \(running)"
      alert.informativeText = """
      Bạn vừa nâng từ v\(persisted) lên v\(running). Khuyến nghị sao lưu \
      dữ liệu cá nhân (macros, từ điển cá nhân, cấu hình) ngay bây giờ. \
      File sao lưu chỉ lưu trên máy bạn, không gửi đi đâu.
      """
      alert.alertStyle = .informational
      alert.addButton(withTitle: "Sao lưu ngay")
      alert.addButton(withTitle: "Để sau")
      alert.showsSuppressionButton = true
      alert.suppressionButton?.title = "Không hiện lại"
      alert.suppressionButton?.state = .off

      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
      // v3.3: activate ngay sau khi đổi policy hay bị nuốt → alert modal có
      // thể VÔ HÌNH mà vẫn chặn main thread (treo app). Ép cửa sổ alert nổi.
      alert.window.level = .floating
      alert.window.orderFrontRegardless()
      let response = alert.runModal()

      if alert.suppressionButton?.state == .on {
        Defaults[.autoBackupOnUpgrade] = false
      }

      if response == .alertFirstButtonReturn {
        // Save to default location automatically. The user can move it.
        let url = defaultBackupURL()
        do {
          try writeAtomically(to: url, export: currentExport())
          let confirm = NSAlert()
          confirm.messageText = "Đã sao lưu thành công"
          confirm.informativeText = "Đường dẫn: \(url.path)"
          confirm.addButton(withTitle: "Mở thư mục")
          confirm.addButton(withTitle: "Đóng")
          if confirm.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
          }
        } catch {
          let fail = NSAlert()
          fail.messageText = "Sao lưu thất bại"
          fail.informativeText = error.localizedDescription
          fail.alertStyle = .warning
          fail.runModal()
        }
      }

      // Stamp version *after* the prompt path completes — so the user is
      // not silently advanced if they cancelled / errored out.
      Defaults[.currentVersion] = running
    }
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
    guard let value = value else { return }
    if replace {
      if Defaults[key] != value {
        Defaults[key] = value
        changes.append("\(label): \(value.count) (overwrite)")
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

  private static func mergeStringDict(
    _ key: Defaults.Key<[String: String]>,
    _ value: [String: String]?,
    replace: Bool,
    label: String,
    into changes: inout [String]
  ) {
    guard let value = value else { return }
    if replace {
      if Defaults[key] != value {
        Defaults[key] = value
        changes.append("\(label): \(value.count) (overwrite)")
      }
      return
    }
    // 1.7.7: merge mode đảo sang imported wins — file thắng khi trùng key.
    var current = Defaults[key]
    var changed = 0
    for (k, v) in value where current[k] != v {
      current[k] = v
      changed += 1
    }
    if changed > 0 {
      Defaults[key] = current
      changes.append("\(label): +\(changed) (merge, file ưu tiên)")
    }
  }

  private static func mergeWindowTitleRules(
    _ value: [WindowTitleRule]?,
    replace: Bool,
    into changes: inout [String]
  ) {
    guard let value = value else { return }
    if replace {
      if Defaults[.windowTitleRules] != value {
        Defaults[.windowTitleRules] = value
        changes.append("Window Title Rules: \(value.count) (overwrite)")
      }
      return
    }

    var current = Defaults[.windowTitleRules]
    var indexesById: [UUID: Int] = [:]
    for (index, rule) in current.enumerated() {
      indexesById[rule.id] = index
    }

    var changed = 0
    for rule in value {
      if let index = indexesById[rule.id] {
        if current[index] != rule {
          current[index] = rule
          changed += 1
        }
      } else {
        current.append(rule)
        changed += 1
      }
    }

    if changed > 0 {
      Defaults[.windowTitleRules] = current
      changes.append("Window Title Rules: +\(changed) (merge, file ưu tiên)")
    }
  }
}
