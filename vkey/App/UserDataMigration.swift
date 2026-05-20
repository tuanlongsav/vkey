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

  // 1.5.5+: auto-feedback toggle for performWeeklyFeedback.
  let autoPersonalDictFeedback: Bool?

  // 1.7.6+: full settings backup — bổ sung 9 fields trước đây bị bỏ sót.
  let wordPredictionEnabled: Bool?
  let appSmartSwitchConfigs: [String: AppSmartSwitchConfig]?  // 1.7.0+ per-app 3-state
  let translationHUDEnabled: Bool?
  let translationHUDDurationMs: Double?
  let programmingMode: Bool?
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
    case hudEnabled, modifierOnlyToggleHotkey
    case smartSwitchEnabled, smartSwitchApps, perAppOverride
    case spellCheckEnabled, spellCheckInSentenceEnabled, englishAutoRestoreEnabled
    case restorePolicy, suggestionEnabled, autoApplyHighConfidenceSuggestion
    case useEnVnReference
    case personalDictionaryEnabled, userAllowWords, userKeepWords, userDenyWords
    case macros, macroEnabled, macrosSeeded, defaultMacrosVersion
    case appTheme, autoPersonalDictFeedback
    case wordPredictionEnabled, appSmartSwitchConfigs
    case translationHUDEnabled, translationHUDDurationMs, programmingMode
    case userBigrams, userTrigrams, statisticsEnabled, autoBackupOnUpgrade
    case statistics
  }

  init(
    schemaVersion: Int, exportedAt: Date, appVersion: String, appBuild: String,
    typingMethod: String?, newStyleTonePlacement: Bool?, autoTypoCorrection: Bool?,
    allowedZWJF: Bool?, hudEnabled: Bool?, modifierOnlyToggleHotkey: Int?,
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
    autoPersonalDictFeedback: Bool?,
    wordPredictionEnabled: Bool? = nil,
    appSmartSwitchConfigs: [String: AppSmartSwitchConfig]? = nil,
    translationHUDEnabled: Bool? = nil,
    translationHUDDurationMs: Double? = nil,
    programmingMode: Bool? = nil,
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
    self.autoPersonalDictFeedback = autoPersonalDictFeedback
    self.wordPredictionEnabled = wordPredictionEnabled
    self.appSmartSwitchConfigs = appSmartSwitchConfigs
    self.translationHUDEnabled = translationHUDEnabled
    self.translationHUDDurationMs = translationHUDDurationMs
    self.programmingMode = programmingMode
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
    self.autoPersonalDictFeedback = try c.decodeIfPresent(Bool.self, forKey: .autoPersonalDictFeedback)
    // 1.7.6+ fields — optional cho file v1.x cũ.
    self.wordPredictionEnabled = try c.decodeIfPresent(Bool.self, forKey: .wordPredictionEnabled)
    self.appSmartSwitchConfigs = try c.decodeIfPresent([String: AppSmartSwitchConfig].self,
                                                      forKey: .appSmartSwitchConfigs)
    self.translationHUDEnabled = try c.decodeIfPresent(Bool.self, forKey: .translationHUDEnabled)
    self.translationHUDDurationMs = try c.decodeIfPresent(Double.self, forKey: .translationHUDDurationMs)
    self.programmingMode = try c.decodeIfPresent(Bool.self, forKey: .programmingMode)
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

      appTheme: Defaults[.appTheme].rawValue,

      autoPersonalDictFeedback: Defaults[.autoPersonalDictFeedback],

      // 1.7.6+: full settings backup
      wordPredictionEnabled: Defaults[.wordPredictionEnabled],
      appSmartSwitchConfigs: Defaults[.appSmartSwitchConfigs],
      translationHUDEnabled: Defaults[.translationHUDEnabled],
      translationHUDDurationMs: Defaults[.translationHUDDurationMs],
      programmingMode: Defaults[.programmingMode],
      userBigrams: Defaults[.userBigrams],
      userTrigrams: Defaults[.userTrigrams],
      statisticsEnabled: Defaults[.statisticsEnabled],
      autoBackupOnUpgrade: Defaults[.autoBackupOnUpgrade],

      statistics: includeStatistics ? UsageStatistics.shared.allWeekBucketsForExport() : nil
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

    // Macros — keyed by `from` for de-dup
    if let importMacros = export.macros {
      var current = Defaults[.macros]
      let existing = Set(current.map { $0.from })
      var added = 0
      for seed in importMacros {
        if seed.from.isEmpty { continue }
        if existing.contains(seed.from) && !replaceLists { continue }
        current.append(Macro(from: seed.from, to: seed.to))
        added += 1
      }
      if added > 0 {
        Defaults[.macros] = current
        changes.append("Macros: +\(added)")
      }
    }
    applyScalar(.macroEnabled, export.macroEnabled, label: "Bật macro")
    applyScalar(.macrosSeeded, export.macrosSeeded, label: "Macro đã seed")
    applyScalar(.defaultMacrosVersion, export.defaultMacrosVersion,
                label: "Default macros version")

    // Theme (1.5.3+)
    if let raw = export.appTheme,
       let parsed = AppTheme(rawValue: raw),
       Defaults[.appTheme] != parsed {
      Defaults[.appTheme] = parsed
      changes.append("Giao diện ← \(raw)")
    }

    // 1.5.5+: auto-feedback toggle
    applyScalar(.autoPersonalDictFeedback, export.autoPersonalDictFeedback,
                label: "Tự động cập nhật từ điển cá nhân")

    // 1.7.6+: previously-missing scalar settings
    applyScalar(.wordPredictionEnabled, export.wordPredictionEnabled,
                label: "Đoán từ tiếp theo")
    applyScalar(.translationHUDEnabled, export.translationHUDEnabled,
                label: "HUD dịch")
    applyScalar(.translationHUDDurationMs, export.translationHUDDurationMs,
                label: "Thời lượng HUD dịch (ms)")
    applyScalar(.programmingMode, export.programmingMode,
                label: "Chế độ lập trình")
    applyScalar(.statisticsEnabled, export.statisticsEnabled,
                label: "Bật thống kê")
    applyScalar(.autoBackupOnUpgrade, export.autoBackupOnUpgrade,
                label: "Tự sao lưu khi cập nhật")

    // 1.7.6+: per-app Smart Switch configs (critical — 1.7.0+ 3-state).
    if let configs = export.appSmartSwitchConfigs {
      if replaceLists {
        if Defaults[.appSmartSwitchConfigs] != configs {
          Defaults[.appSmartSwitchConfigs] = configs
          changes.append("Smart Switch per-app: \(configs.count) (overwrite)")
        }
      } else {
        var current = Defaults[.appSmartSwitchConfigs]
        var added = 0
        for (key, value) in configs where current[key] == nil {
          current[key] = value
          added += 1
        }
        if added > 0 {
          Defaults[.appSmartSwitchConfigs] = current
          changes.append("Smart Switch per-app: +\(added)")
        }
      }
    }

    // 1.7.6+: bigram/trigram (prediction learning data) — merge: cộng counts.
    if let bigrams = export.userBigrams {
      if replaceLists {
        if Defaults[.userBigrams] != bigrams {
          Defaults[.userBigrams] = bigrams
          changes.append("Bigram dự đoán: \(bigrams.count) (overwrite)")
        }
      } else {
        var current = Defaults[.userBigrams]
        var added = 0
        for (prev, nextMap) in bigrams {
          var existingNext = current[prev] ?? [:]
          for (next, count) in nextMap {
            if existingNext[next] == nil {
              existingNext[next] = count
              added += 1
            }
          }
          current[prev] = existingNext
        }
        if added > 0 {
          Defaults[.userBigrams] = current
          changes.append("Bigram dự đoán: +\(added)")
        }
      }
    }
    if let trigrams = export.userTrigrams {
      if replaceLists {
        if Defaults[.userTrigrams] != trigrams {
          Defaults[.userTrigrams] = trigrams
          changes.append("Trigram dự đoán: \(trigrams.count) (overwrite)")
        }
      } else {
        var current = Defaults[.userTrigrams]
        var added = 0
        for (prev, nextMap) in trigrams {
          var existingNext = current[prev] ?? [:]
          for (next, count) in nextMap {
            if existingNext[next] == nil {
              existingNext[next] = count
              added += 1
            }
          }
          current[prev] = existingNext
        }
        if added > 0 {
          Defaults[.userTrigrams] = current
          changes.append("Trigram dự đoán: +\(added)")
        }
      }
    }

    // 1.7.6+: stats restoration. Trước đây bỏ qua hoàn toàn → tab Thống kê
    // hiện 0 sau import. Match weekId hiện tại → load thành in-memory
    // counters; tuần cũ → ghi file `<weekId>.json`.
    if let stats = export.statistics, !stats.isEmpty {
      let restored = UsageStatistics.shared.restoreFromBackup(stats)
      if restored > 0 {
        changes.append("Thống kê: khôi phục \(restored) tuần")
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
    return true
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
    var current = Defaults[key]
    var added = 0
    for (k, v) in value where current[k] == nil {
      current[k] = v
      added += 1
    }
    if added > 0 {
      Defaults[key] = current
      changes.append("\(label): +\(added)")
    }
  }
}
