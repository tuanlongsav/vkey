//
//  Setting.swift
//  vkey
//
//  Created by KhanhIceTea on 11/3/24.
//

import AppKit
import Defaults
import Foundation
import KeyboardShortcuts

extension Bundle {
  public var appName: String { getInfo("CFBundleName") }
  public var displayName: String { getInfo("CFBundleDisplayName") }
  public var language: String { getInfo("CFBundleDevelopmentRegion") }
  public var identifier: String { getInfo("CFBundleIdentifier") }
  public var copyright: String {
    getInfo("NSHumanReadableCopyright").replacingOccurrences(of: "\\\\n", with: "\n")
  }

  public var appBuild: String { getInfo("CFBundleVersion") }
  public var appVersionLong: String { getInfo("CFBundleShortVersionString") }
  public var appVersionShort: String { getInfo("CFBundleShortVersion") }

  fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}

extension KeyboardShortcuts.Name {
  // No default key+modifier shortcut. The default toggle is the pure-modifier
  // combo ⌃⇧ (configured via Defaults.Keys.modifierOnlyToggleHotkey below) so
  // the user can keep their letter keys free.
  static let toggleInputMode = Self("toggleInputMode")
}

/// Default modifier-only hotkey: Control + Shift.
/// The bit layout matches both `NSEvent.ModifierFlags` and `CGEventFlags` on
/// macOS, so the same Int value is compared on either side of the event tap.
private let kDefaultModifierOnlyMask: Int =
  Int(NSEvent.ModifierFlags.control.rawValue) | Int(NSEvent.ModifierFlags.shift.rawValue)

/// A text-expansion macro: when the user types `from` as a standalone word, vkey replaces
/// it with `to` before the word-ending key reaches the OS.
struct Macro: Codable, Hashable, Identifiable, Defaults.Serializable {
  var from: String
  var to: String
  var id: UUID = UUID()
}

enum RestorePolicy: String, CaseIterable, Defaults.Serializable {
  case vietnameseFirst
  case balanced
  case englishFirst
}

/// Đề xuất pending để bổ sung vào personal dictionary (1.6.0+).
/// Thay thế cho cơ chế auto-promote cũ — giờ chỉ compute đề xuất,
/// user review qua sheet rồi quyết định thêm.
struct PendingDictSuggestion: Codable, Hashable, Identifiable, Defaults.Serializable {
  enum Kind: String, Codable {
    case allow  // gợi ý vào userAllowWords (raw tiếng Anh user gõ nhiều)
    case keep   // gợi ý vào userKeepWords (giữ nguyên tiếng Việt)
  }

  var id: String { kind.rawValue + "_" + word.lowercased() }
  var word: String
  var count: Int
  var kind: Kind
  var suggestedAt: Date
}

// MARK: - Smart Switch 3-state (1.7.0+)

/// Trạng thái Smart Switch per-app. Thay cơ chế list 1-chiều
/// `smartSwitchApps` (chỉ "tắt VN") bằng 3-state rõ ràng.
enum AppSmartSwitchState: String, CaseIterable, Codable, Defaults.Serializable {
  case disabled         // Không sử dụng vkey trong app này (bộ gõ TẮT)
  case vietnameseMode   // Sử dụng vkey, gõ Tiếng Việt
  case englishMode      // Sử dụng vkey, gõ Tiếng Anh (output passthrough)

  var displayName: String {
    switch self {
    case .disabled: return "Không sử dụng vkey"
    case .vietnameseMode: return "Tiếng Việt"
    case .englishMode: return "Tiếng Anh"
    }
  }

  var shortLabel: String {
    switch self {
    case .disabled: return "Tắt"
    case .vietnameseMode: return "🇻🇳 VN"
    case .englishMode: return "🇺🇸 EN"
    }
  }
}

/// Nguồn gốc cài đặt — phân biệt user thủ công vs auto-learn từ stats.
enum AppSmartSwitchSource: String, CaseIterable, Codable, Defaults.Serializable {
  case user        // 👤 User set thủ công (override auto-learn)
  case autoLearn   // 🤖 Auto-learn từ stats per-app language ratio

  /// SF Symbol name cho UI badge — chỉ áp dụng cho .user.
  /// .autoLearn dùng emoji 🤖 (qua `emojiIcon`) thay SF Symbol để rõ ràng hơn.
  var iconSymbol: String {
    switch self {
    case .user: return "person.fill"
    case .autoLearn: return "cpu"  // legacy fallback, prefer emojiIcon for autoLearn
    }
  }

  /// v1.7.3+: emoji icon cho display (ưu tiên hơn iconSymbol cho autoLearn).
  var emojiIcon: String {
    switch self {
    case .user: return "👤"
    case .autoLearn: return "🤖"
    }
  }

  var displayName: String {
    switch self {
    case .user: return "Người dùng đặt"
    case .autoLearn: return "Tự động học"
    }
  }
}

/// Cấu hình Smart Switch per-app — replace `smartSwitchApps: [String]` từ 1.7.0.
/// User setting (source=.user) LUÔN override auto-learn (source=.autoLearn).
struct AppSmartSwitchConfig: Codable, Hashable, Defaults.Serializable {
  var state: AppSmartSwitchState
  var source: AppSmartSwitchSource
  var lastModified: Date

  init(state: AppSmartSwitchState, source: AppSmartSwitchSource, lastModified: Date = Date()) {
    self.state = state
    self.source = source
    self.lastModified = lastModified
  }
}

/// Giao diện ứng dụng. 3 theme khả dụng:
/// - `.default`: SF Symbol gốc, không hiệu ứng.
/// - `.threeD`: SF Symbol + gradient + shadow + multicolor — "bóng bẩy" 3D.
/// - `.emoji`: thay SF Symbol bằng Unicode emoji tương ứng (vd
///   `gearshape` → ⚙️, `lightbulb` → 💡) — vui tươi, dễ phân biệt.
/// Không ảnh hưởng menu bar state flag (vn-flag/us-flag) và AppIcon.
enum AppTheme: String, CaseIterable, Defaults.Serializable {
  case `default`
  case threeD
  case emoji
}

extension Defaults.Keys {
  static let currentVersion = Key<String>("current-version", default: "0.1")
  static let typingMethod = Key<TypingMethods>("typing-method", default: .Telex)
  static let allowedZWJF = Key<Bool>("allowed-zwjf", default: true)
  static let token = Key<String>("token", default: "")
  static let autoSwitchStrategy = Key<Bool>("auto-switch-strategy", default: true)
  /// Tự động chuyển sang tiếng Anh khi launcher app (Spotlight/Raycast/Alfred…) lên foreground.
  static let smartSwitchEnabled = Key<Bool>("smart-switch-enabled", default: true)
  /// Danh sách các ứng dụng tự động chuyển sang gõ Tiếng Anh khi kích hoạt.
  static let smartSwitchApps = Key<[String]>("smart-switch-apps", default: [
    "com.apple.Spotlight",
    "com.raycast.macos",
    "com.runningwithcrayons.Alfred",
    "com.runningwithcrayons.Alfred-Preferences",
    "com.obdev.LaunchBar",
  ])
  /// Bảng macro thay thế chữ viết tắt → cụm dài.
  static let macros = Key<[Macro]>("macros", default: [])
  /// Bật / Tắt toàn bộ macro engine (không xoá list). Khi tắt, `macros` vẫn
  /// được giữ nguyên — chỉ tạm dừng expansion khi gõ Space/punctuation.
  static let macroEnabled = Key<Bool>("macro-enabled", default: true)
  /// Cờ một lần: app đã seed bộ macro mặc định cho user mới chưa? Khi true,
  /// app không bao giờ re-seed kể cả khi user xoá hết macro.
  static let macrosSeeded = Key<Bool>("macros-seeded", default: false)
  /// Version của bộ default macros đã seed. Tăng mỗi khi đổi danh sách:
  /// - 0 = chưa migrate (user 1.5.0–1.5.2)
  /// - 1 = 19-macro seed (1.5.3 / 1.5.4)
  /// - 2 = 14 office + 8 emoji + 12 symbols (1.5.5+)
  /// Migration trong `AppDelegate.seedDefaultMacrosIfNeeded()` idempotent.
  static let defaultMacrosVersion = Key<Int>("default-macros-version", default: 0)
  /// Tổ hợp modifier-only (vd Shift+Control) dùng để chuyển đổi vi/en.
  /// 0 = không dùng. Bit layout giống NSEvent.ModifierFlags (.shift=0x20000, .control=0x40000…).
  /// Mặc định: ⌃⇧ (Control+Shift).
  static let modifierOnlyToggleHotkey = Key<Int>(
    "modifier-only-toggle-hotkey",
    default: kDefaultModifierOnlyMask
  )
  
  /// Tuỳ chọn kiểu đặt dấu: false = Kiểu cũ (hòa, khỏe), true = Kiểu mới (hoà, khoẻ).
  static let newStyleTonePlacement = Key<Bool>("new-style-tone-placement", default: true)

  /// Tự động sửa lỗi gõ nhầm (ví dụ: thfi -> thì, dinjhd -> định)
  static let autoTypoCorrection = Key<Bool>("auto-typo-correction", default: true)

  /// Hiển thị HUD khi chuyển đổi bộ gõ
  static let hudEnabled = Key<Bool>("hud-enabled", default: true)

  /// Bật kiểm tra từ điển/chính tả trước khi auto-restore và gợi ý.
  static let spellCheckEnabled = Key<Bool>("spell-check-enabled", default: true)

  /// Kiểm tra chính tả đặt trong câu (khi gõ space/punctuation)
  static let spellCheckInSentenceEnabled = Key<Bool>("spell-check-in-sentence-enabled", default: true)

  /// Cho phép tự khôi phục về tiếng Anh khi đầu ra không phải tiếng Việt hợp lệ.
  static let englishAutoRestoreEnabled = Key<Bool>("english-auto-restore-enabled", default: true)

  /// Chính sách xử lý từ mơ hồ giữa tiếng Việt và tiếng Anh.
  static let restorePolicy = Key<RestorePolicy>("restore-policy", default: .vietnameseFirst)

  /// Bật tính năng gợi ý sửa chính tả.
  static let suggestionEnabled = Key<Bool>("suggestion-enabled", default: true)

  /// Tự áp dụng gợi ý có độ tin cậy cao.
  static let autoApplyHighConfidenceSuggestion = Key<Bool>(
    "auto-apply-high-confidence-suggestion",
    default: true
  )

  /// Bật/tắt sử dụng từ điển cá nhân (từ cho phép, ưu tiên giữ, loại bỏ)
  static let personalDictionaryEnabled = Key<Bool>("personal-dictionary-enabled", default: true)

  /// Từ do người dùng thêm vào, luôn coi là hợp lệ.
  static let userAllowWords = Key<[String]>("user-allow-words", default: [])

  /// Từ ưu tiên giữ nguyên dạng tiếng Việt, không auto-restore sang tiếng Anh.
  static let userKeepWords = Key<[String]>("user-keep-words", default: [])

  /// Từ người dùng muốn loại khỏi tập hợp hợp lệ.
  static let userDenyWords = Key<[String]>("user-deny-words", default: [])

  /// Thời điểm cuối cùng kiểm tra cập nhật từ điển từ GitHub.
  static let lastDictionaryCheckDate = Key<Date?>("last-dictionary-check-date", default: nil)

  // MARK: - 1.5.0 — Bilingual reference & new feature gates

  /// Bật tham chiếu Anh-Việt (`en_vn_mapping`) khi `SpellDecisionEngine`
  /// quyết định giữ/khôi phục từ. Tắt thì hành vi y hệt 1.4.x.
  static let useEnVnReference = Key<Bool>("use-en-vn-reference", default: true)

  /// Hiển thị HUD dịch nghĩa Anh→Việt khi user gõ từ tiếng Anh trong chế độ VI.
  static let translationHUDEnabled = Key<Bool>("translation-hud-enabled", default: false)

  /// Thời gian (ms) HUD dịch nghĩa hiển thị trước khi tự ẩn.
  static let translationHUDDurationMs = Key<Double>("translation-hud-duration-ms", default: 1500)

  /// Programming Mode — tạm dừng VN sau các ký tự code phổ biến ({, (, [, =, :, ;, <).
  /// Mặc định off vì làm thay đổi hành vi gõ trong context đời thường.
  static let programmingMode = Key<Bool>("programming-mode", default: false)

  /// Bật ghi thống kê sử dụng (chỉ lưu local, không gửi đi đâu).
  static let statisticsEnabled = Key<Bool>("statistics-enabled", default: true)

  /// Override per-app kiểu gõ. Key là bundleID, value là một trong:
  /// "auto" (default), "telex", "vni", "off". Phase 5.1.
  static let perAppOverride = Key<[String: String]>("per-app-override", default: [:])

  /// Tuần ISO đã chạy weekly feedback gần nhất (vd "2026-W21"). Dùng để
  /// đảm bảo `performWeeklyFeedback()` chỉ chạy 1 lần mỗi tuần.
  static let lastFeedbackWeekId = Key<String>("last-feedback-week-id", default: "")

  /// Tự động hỏi sao lưu dữ liệu khi phát hiện app cập nhật.
  static let autoBackupOnUpgrade = Key<Bool>("auto-backup-on-upgrade", default: true)

  /// Bật/tắt cơ chế `performWeeklyFeedback` — tự động promote các từ tiếng
  /// Việt / Anh user gõ ≥5 lần/tuần vào personal dictionary (Allow/Keep).
  /// Mặc định bật. User có thể tắt nếu muốn personal dict chỉ chỉnh tay.
  /// Manual button trong tab Thống kê vẫn chạy được bất kể flag này (1.5.5+).
  /// 1.6.0+: KHÔNG còn auto-write nữa — compute pending suggestions thay vì.
  static let autoPersonalDictFeedback = Key<Bool>("auto-personal-dict-feedback", default: true)

  /// Thời điểm cuối cùng app check update (1.6.0+). Throttle background
  /// auto-check thành 1 lần/ngày (kiểm tra lần đầu mỗi ngày, thường vào
  /// sáng khi user mở máy). Manual button "Kiểm tra cập nhật" không bị
  /// throttle.
  static let lastUpdateCheckDate = Key<Date?>("last-update-check-date", default: nil)

  /// Build version của bản update gần nhất đã hiện notification banner
  /// cho user (1.6.0+). Tránh spam: nếu user đã thấy notification về
  /// build N mà chưa update, không hiện lại banner mỗi ngày.
  /// Reset = 0 sẽ enable notification lại.
  static let lastNotifiedUpdateBuild = Key<Int>("last-notified-update-build", default: 0)

  /// Danh sách đề xuất pending — chờ user review qua
  /// `PersonalDictSuggestionSheet` (1.6.0+). Mỗi lần
  /// `performWeeklyFeedback` chạy, app ADD entries mới (dedupe by `id`).
  /// User accept → vào `userAllowWords` / `userKeepWords` + xoá khỏi
  /// pending. User dismiss → xoá khỏi pending.
  static let pendingDictSuggestions = Key<[PendingDictSuggestion]>(
    "pending-dict-suggestions",
    default: []
  )

  /// Word Prediction (1.6.0+, thử nghiệm). Default OFF — opt-in.
  /// Khi bật: sau khi commit 1 từ + space, vkey đoán từ tiếp theo và
  /// hiển thị HUD nổi gần cursor. Nhấn Tab để chấp nhận.
  static let wordPredictionEnabled = Key<Bool>("word-prediction-enabled", default: false)

  /// 1.8.1: số dòng văn bản cách giữa HUD prediction và caret line.
  /// Range 1-10. Default 4 (cân bằng giữa nhìn rõ và không che nội dung).
  /// Trước 1.8.1 HUD chỉ cách caret 4px — quá gần, hay che dòng đang gõ.
  static let predictionHUDLineOffset = Key<Int>("prediction-hud-line-offset", default: 4)

  /// 1.9.0: font size cho text trong PredictionHUD. Range 10-20, default 13.
  /// User feedback HUD đôi khi quá nhỏ/quá to so với font editor của họ.
  static let predictionHUDFontSize = Key<Int>("prediction-hud-font-size", default: 13)

  /// 1.9.0: opacity cho HUD (cả PredictionHUD và ToggleHUD). Range 50-100
  /// (representing 0.50-1.00). Default 100 (đậm). User có thể giảm để HUD
  /// trong suốt hơn, đỡ "tranh" với nội dung editor.
  static let hudOpacityPercent = Key<Int>("hud-opacity-percent", default: 100)

  // MARK: - 1.7.0 — Smart Switch 3-state per-app config

  /// Cấu hình Smart Switch per-app (1.7.0+) — thay list smartSwitchApps cũ.
  /// Mỗi bundle ID map sang `AppSmartSwitchConfig` (state + source).
  /// Migration: smartSwitchApps cũ → englishMode + source=.user (chạy 1 lần
  /// trong AppDelegate.applicationDidFinishLaunching).
  static let appSmartSwitchConfigs = Key<[String: AppSmartSwitchConfig]>(
    "app-smart-switch-configs",
    default: [:]
  )

  /// Tuần ISO đã chạy auto-learn Smart Switch gần nhất (vd "2026-W21").
  /// Throttle 1 lần/tuần để tránh churn.
  static let lastSmartSwitchAutoLearnWeek = Key<String>("last-smart-switch-auto-learn-week", default: "")

  /// 1.7.2+: gate auto-learn theo NGÀY thay TUẦN. Format ISO date "YYYY-MM-DD".
  /// Threshold mới: ≥1 ngày dataset, ≥5 commit/ngày, ratio ≥75% → daily check.
  static let lastSmartSwitchAutoLearnDate = Key<String>("last-smart-switch-auto-learn-date", default: "")

  /// 1.9.0: Smart Switch auto-learn telemetry — đếm tổng số suggestions
  /// đã sinh ra (mỗi lần user mở sheet "Tự học từ Thống kê") và tổng đã
  /// áp dụng (qua "Áp dụng tất cả"). Hiển thị trong Smart Switch tab để
  /// user verify auto-learn hoạt động.
  static let smartSwitchSuggestionsTotal = Key<Int>("smart-switch-suggestions-total", default: 0)
  static let smartSwitchSuggestionsAccepted = Key<Int>("smart-switch-suggestions-accepted", default: 0)

  /// Bigram counts: previous word → next word → count. Học từ history
  /// user gõ (1.6.0+).
  ///
  /// **Deprecated 1.7.x:** Storage chuyển sang `NGramStore` (file-backed
  /// trong `~/Library/Application Support/vkey/ngram/`) để tránh jank UI
  /// khi dict tăng vài MB. Key này chỉ còn cho migration 1 chiều
  /// (Defaults → NGramStore) và import từ user-data export cũ.
  /// Live read/write phải qua `NGramStore.shared`.
  static let userBigrams = Key<[String: [String: Int]]>("user-bigrams", default: [:])

  /// Trigram counts: "prev2|prev1" → next word → count. Compose key
  /// bằng `|` để giảm nested level (Defaults serializer dễ hơn).
  ///
  /// **Deprecated 1.7.x:** xem ghi chú `userBigrams`.
  static let userTrigrams = Key<[String: [String: Int]]>("user-trigrams", default: [:])

  /// Giao diện ứng dụng — `.threeD` là default mới ở 1.5.4 (gradient +
  /// shadow + multicolor trên SF Symbol). UI picker tạm thời ẩn — sẽ
  /// mở lại khi có bộ artwork bitmap PDF cho `Icons3D/` (designer làm
  /// theo template `Tools/icon-set-templates/`).
  static let appTheme = Key<AppTheme>("app-theme", default: .threeD)

  //            ^            ^         ^                ^
  //           Key          Type   UserDefaults name   Default value
}

