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

  // Optional statistics snapshot
  let statistics: [UsageSummary]?

  static let currentSchemaVersion = 1
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

      statistics: includeStatistics ? UsageStatistics.shared.allSummariesForExport() : nil
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
