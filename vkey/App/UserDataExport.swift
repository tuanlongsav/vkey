//
//  UserDataExport.swift
//  vkey
//
//  Schema-versioned JSON snapshot of user-mutable vkey state.
//  Uses synthesized Codable across all ~38 optional fields while preserving
//  backward-compatible v1/v2 statistics decoding via `StatisticsExportPayload`.
//

import Foundation

/// Wrapper handling v2 `[WeekBucketExport]` and legacy v1 `[UsageSummary]` statistics
/// arrays, while throwing `dataCorrupted` if a non-null `statistics` field is malformed.
struct StatisticsExportPayload: Codable {
  let buckets: [WeekBucketExport]

  init(_ buckets: [WeekBucketExport]) {
    self.buckets = buckets
  }

  init(from decoder: Decoder) throws {
    let single = try decoder.singleValueContainer()
    if let v2 = try? single.decode([WeekBucketExport].self) {
      self.buckets = v2
    } else if let v1 = try? single.decode([UsageSummary].self) {
      self.buckets = v1.map { WeekBucket(fromLegacySummary: $0) }
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Khối 'statistics' có trong file nhưng không đọc được (sai định dạng)."
        )
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var single = encoder.singleValueContainer()
    try single.encode(buckets)
  }
}

/// Schema-versioned snapshot of every piece of user-mutable state.
struct UserDataExport: Codable {
  static let currentSchemaVersion = 2

  private var _schemaVersion: Int?
  private var _exportedAt: Date?
  private var _appVersion: String?
  private var _appBuild: String?

  var schemaVersion: Int { _schemaVersion ?? 1 }
  var exportedAt: Date { _exportedAt ?? Date() }
  var appVersion: String { _appVersion ?? "" }
  var appBuild: String { _appBuild ?? "" }

  // Engine + UI preferences
  var typingMethod: String?
  var newStyleTonePlacement: Bool?
  var autoTypoCorrection: Bool?
  var allowedZWJF: Bool?
  var hudEnabled: Bool?
  var modifierOnlyToggleHotkey: Int?

  // Smart Switch
  var smartSwitchEnabled: Bool?
  var smartSwitchApps: [String]?

  // Spell check + suggestion
  var spellCheckEnabled: Bool?
  var englishAutoRestoreEnabled: Bool?
  var restorePolicy: String?
  var suggestionEnabled: Bool?
  var autoApplyHighConfidenceSuggestion: Bool?
  var useEnVnReference: Bool?

  // Personal dictionary
  var personalDictionaryEnabled: Bool?
  var userAllowWords: [String]?
  var userKeepWords: [String]?
  var userDenyWords: [String]?

  // Macros
  var macros: [MacroSeed]?
  var macroEnabled: Bool?
  var macrosSeeded: Bool?
  var defaultMacrosVersion: Int?

  // Theme
  var uiTheme: String?
  var appearanceMode: String?
  var themeConfigs: [String: ThemeConfig]?

  // Weekly feedback & settings (1.5.5+ / 1.7.6+ / 3.23+ / 4.35+)
  var autoPersonalDictFeedback: Bool?
  var hudOpacityPercent: Int?
  var appSmartSwitchConfigs: [String: AppSmartSwitchConfig]?
  var appSendingModes: [String: String]?
  var autoCapitalizeEnabled: Bool?
  var nonLatinIMEAutoDisable: Bool?
  var freeMarkModeEnabled: Bool?
  var statisticsEnabled: Bool?
  var autoBackupOnUpgrade: Bool?
  var autoUpdateEnabled: Bool?

  private var _statistics: StatisticsExportPayload?
  var statistics: [WeekBucketExport]? { _statistics?.buckets }

  enum CodingKeys: String, CodingKey {
    case _schemaVersion = "schemaVersion"
    case _exportedAt = "exportedAt"
    case _appVersion = "appVersion"
    case _appBuild = "appBuild"
    case typingMethod, newStyleTonePlacement, autoTypoCorrection, allowedZWJF
    case hudEnabled, modifierOnlyToggleHotkey
    case smartSwitchEnabled, smartSwitchApps
    case spellCheckEnabled, englishAutoRestoreEnabled
    case restorePolicy, suggestionEnabled, autoApplyHighConfidenceSuggestion
    case useEnVnReference
    case personalDictionaryEnabled, userAllowWords, userKeepWords, userDenyWords
    case macros, macroEnabled, macrosSeeded, defaultMacrosVersion
    case uiTheme, appearanceMode, themeConfigs
    case autoPersonalDictFeedback
    case hudOpacityPercent, appSmartSwitchConfigs, appSendingModes
    case autoCapitalizeEnabled, nonLatinIMEAutoDisable
    case freeMarkModeEnabled
    case statisticsEnabled, autoBackupOnUpgrade
    case autoUpdateEnabled
    case _statistics = "statistics"
  }

  init(
    schemaVersion: Int = UserDataExport.currentSchemaVersion,
    exportedAt: Date = Date(),
    appVersion: String = "",
    appBuild: String = "",
    typingMethod: String? = nil,
    newStyleTonePlacement: Bool? = nil,
    autoTypoCorrection: Bool? = nil,
    allowedZWJF: Bool? = nil,
    hudEnabled: Bool? = nil,
    modifierOnlyToggleHotkey: Int? = nil,
    smartSwitchEnabled: Bool? = nil,
    smartSwitchApps: [String]? = nil,
    spellCheckEnabled: Bool? = nil,
    englishAutoRestoreEnabled: Bool? = nil,
    restorePolicy: String? = nil,
    suggestionEnabled: Bool? = nil,
    autoApplyHighConfidenceSuggestion: Bool? = nil,
    useEnVnReference: Bool? = nil,
    personalDictionaryEnabled: Bool? = nil,
    userAllowWords: [String]? = nil,
    userKeepWords: [String]? = nil,
    userDenyWords: [String]? = nil,
    macros: [MacroSeed]? = nil,
    macroEnabled: Bool? = nil,
    macrosSeeded: Bool? = nil,
    defaultMacrosVersion: Int? = nil,
    uiTheme: String? = nil,
    appearanceMode: String? = nil,
    themeConfigs: [String: ThemeConfig]? = nil,
    autoPersonalDictFeedback: Bool? = nil,
    hudOpacityPercent: Int? = nil,
    appSmartSwitchConfigs: [String: AppSmartSwitchConfig]? = nil,
    appSendingModes: [String: String]? = nil,
    autoCapitalizeEnabled: Bool? = nil,
    nonLatinIMEAutoDisable: Bool? = nil,
    freeMarkModeEnabled: Bool? = nil,
    statisticsEnabled: Bool? = nil,
    autoBackupOnUpgrade: Bool? = nil,
    autoUpdateEnabled: Bool? = nil,
    statistics: [WeekBucketExport]? = nil
  ) {
    self._schemaVersion = schemaVersion
    self._exportedAt = exportedAt
    self._appVersion = appVersion
    self._appBuild = appBuild
    self.typingMethod = typingMethod
    self.newStyleTonePlacement = newStyleTonePlacement
    self.autoTypoCorrection = autoTypoCorrection
    self.allowedZWJF = allowedZWJF
    self.hudEnabled = hudEnabled
    self.modifierOnlyToggleHotkey = modifierOnlyToggleHotkey
    self.smartSwitchEnabled = smartSwitchEnabled
    self.smartSwitchApps = smartSwitchApps
    self.spellCheckEnabled = spellCheckEnabled
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
    self.uiTheme = uiTheme
    self.appearanceMode = appearanceMode
    self.themeConfigs = themeConfigs
    self.autoPersonalDictFeedback = autoPersonalDictFeedback
    self.hudOpacityPercent = hudOpacityPercent
    self.appSmartSwitchConfigs = appSmartSwitchConfigs
    self.appSendingModes = appSendingModes
    self.autoCapitalizeEnabled = autoCapitalizeEnabled
    self.nonLatinIMEAutoDisable = nonLatinIMEAutoDisable
    self.freeMarkModeEnabled = freeMarkModeEnabled
    self.statisticsEnabled = statisticsEnabled
    self.autoBackupOnUpgrade = autoBackupOnUpgrade
    self.autoUpdateEnabled = autoUpdateEnabled
    self._statistics = statistics.map { StatisticsExportPayload($0) }
  }
}
