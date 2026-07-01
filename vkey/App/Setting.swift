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
import SwiftUI

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

  /// 2.0 (B4): mở Text Conversion Tools menu cho selected text.
  static let openTextConversionMenu = Self("openTextConversionMenu")

  /// Mở menu lịch sử clipboard để chọn mục dán (mặc định ⇧⌘V).
  static let pasteClipboardHistory = Self(
    "pasteClipboardHistory",
    default: KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift])
  )

  // 2.0.1: `toggleFloatingToolbar` đã bị xoá cùng với Floating Toolbar.
}

/// Default modifier-only hotkey cho VI/EN toggle: **Shift + Option** (⇧⌥).
/// 2.0.2 đổi từ Control+Shift (⌃⇧) sang Shift+Option theo user feedback —
/// ⇧⌥ ít xung đột hơn với system shortcuts.
///
/// The bit layout matches both `NSEvent.ModifierFlags` and `CGEventFlags` on
/// macOS, so the same Int value is compared on either side of the event tap.
private let kDefaultModifierOnlyMask: Int =
  Int(NSEvent.ModifierFlags.shift.rawValue) | Int(NSEvent.ModifierFlags.option.rawValue)

/// Default modifier-only hotkey cho Text Tools (B4): **Control + Shift** (⌃⇧).
/// 2.0.2 thêm — mirror cấu trúc của VI/EN toggle. EventHook check thêm mask
/// này để trigger `TextConversionService.shared.openMenu()` khi user nhấn
/// + thả ⌃⇧ không kèm letter key.
private let kDefaultTextToolsMask: Int =
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
/// 2.16: lựa chọn màu accent cho giao diện redesign (5 màu của design).
/// Mã hex resolve trong `VK.Color.accentChoice` (VKDesign).
enum AccentColorChoice: String, CaseIterable, Codable, Defaults.Serializable {
  case red       // #E04434 (mặc định)
  case gold      // #E5AE1C
  case green     // #2BB673
  case blue      // #2D89E5
  case purple    // #8B5CF6

  var hex: String {
    switch self {
    case .red:    return "#E04434"
    case .gold:   return "#E5AE1C"
    case .green:  return "#2BB673"
    case .blue:   return "#2D89E5"
    case .purple: return "#8B5CF6"
    }
  }

  // v4.8: mỗi accent có ramp 5 stop [500,600,700,400,300] để dựng hover/press/
  // pill nhất quán (trước đây accent chỉ có 1 hex → brand600 phải trả trùng 500).
  /// `[500, 600, 700, 400, 300]` (hex, không có '#') — dùng qua `ramp`.
  var ramp: (s500: String, s600: String, s700: String, s400: String, s300: String) {
    switch self {
    case .red:    return ("#E04434", "#C8341F", "#A52817", "#EB6249", "#F18A74")
    case .gold:   return ("#E5AE1C", "#B5860D", "#8A6608", "#F5C645", "#FAD37A")
    case .green:  return ("#2BB673", "#1F9E62", "#17794B", "#4FC98D", "#7FD9AC")
    case .blue:   return ("#2D89E5", "#1E6FC4", "#17559A", "#5AA4EC", "#8FC1F3")
    case .purple: return ("#8B5CF6", "#7440E0", "#5B2FB8", "#A67DF9", "#C3A6FC")
    }
  }
  /// Stop tối hơn cho hover nút primary.
  var hex600: String { ramp.s600 }
  /// Stop tối nhất cho press nút primary.
  var hex700: String { ramp.s700 }
  /// Stop sáng hơn (dùng cho chữ accent trên nền tối).
  var hex400: String { ramp.s400 }
  var hex300: String { ramp.s300 }

  var displayName: String {
    switch self {
    case .red:    return "Đỏ Saigon"
    case .gold:   return "Vàng"
    case .green:  return "Xanh lá"
    case .blue:   return "Xanh dương"
    case .purple: return "Tím"
    }
  }
}

/// 2.16: chế độ sáng/tối cho cửa sổ Settings.
enum AppearanceMode: String, CaseIterable, Defaults.Serializable {
  case auto, light, dark

  var colorScheme: ColorScheme? {
    switch self {
    case .auto:  return nil
    case .light: return .light
    case .dark:  return .dark
    }
  }
}

/// v2.1.1+: UI theme — diện mạo toàn cục cho app.
/// v2.2.2: thay Sơn Mài bằng Liquid Glass (refractive, glossy macOS Tahoe
/// aesthetic — glass multi-layer + edge highlights + refractive tints).
/// Default `.tonal`.
/// 2.16: theme diện mạo. `.tonal` = mặc định (phẳng, paper/ink); `.glass` =
/// Liquid Glass (trong mờ, blur, specular — macOS Tahoe). User chọn ở tab
/// "Quản lý giao diện".
enum UITheme: String, CaseIterable, Defaults.Serializable {
  case tonal
  case glass
  case neural

  var displayName: String {
    switch self {
    case .tonal:  return "Mặc định"
    case .glass:  return "Liquid Glass"
    case .neural: return "Neural AI"
    }
  }
  var caption: String {
    switch self {
    case .tonal:  return "Phẳng, tương phản rõ — nền giấy ấm / mực sâu."
    case .glass:  return "Trong mờ, blur khúc xạ — kính nổi macOS Tahoe."
    case .neural: return "Aurora + gradient trí tuệ tím → cyan, phong cách AI."
    }
  }
}

/// 2.16: độ bo góc toàn cục — tuỳ chỉnh ở tab Quản lý giao diện.
enum ThemeRadius: String, CaseIterable, Codable, Defaults.Serializable {
  case sharp, medium, round
  var displayName: String {
    switch self {
    case .sharp:  return "Sắc"
    case .medium: return "Vừa"
    case .round:  return "Tròn"
    }
  }
  /// Hệ số nhân lên thang bo góc gốc.
  var scale: CGFloat {
    switch self {
    case .sharp:  return 0.45
    case .medium: return 1.0
    case .round:  return 1.7
    }
  }
}

/// 2.16: mật độ dòng menu cài đặt — gọn / vừa / thoáng.
enum ThemeDensity: String, CaseIterable, Codable, Defaults.Serializable {
  case compact, regular, comfy
  var displayName: String {
    switch self {
    case .compact: return "Gọn"
    case .regular: return "Vừa"
    case .comfy:   return "Thoáng"
    }
  }
  /// Padding dọc mỗi hàng (pt).
  var rowPaddingV: CGFloat {
    switch self {
    case .compact: return 7
    case .regular: return 11
    case .comfy:   return 15
    }
  }
  /// Khoảng cách giữa các section.
  var sectionGap: CGFloat {
    switch self {
    case .compact: return 18
    case .regular: return 24
    case .comfy:   return 30
    }
  }
}

/// 2.16: font chữ giao diện. `.system` = SF; còn lại là font nhúng kèm app.
enum ThemeFont: String, CaseIterable, Codable, Defaults.Serializable {
  case system, beVietnam, inter, notoSans, lora, nunito

  /// Giá trị lạ trong config cũ (vd "carterOne"/"jetBrains" — font đã gỡ)
  /// tự map về `.system` thay vì làm hỏng decode cả ThemeConfig.
  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = ThemeFont(rawValue: raw) ?? .system
  }

  var displayName: String {
    switch self {
    case .system:    return "Hệ thống (SF)"
    case .beVietnam: return "Be Vietnam Pro"
    case .inter:     return "Inter"
    case .notoSans:  return "Noto Sans Display"
    case .lora:      return "Lora (serif)"
    case .nunito:    return "Nunito"
    }
  }
  /// PostScript name của font nhúng; nil = dùng SF system.
  var postScriptName: String? {
    switch self {
    case .system:    return nil
    case .beVietnam: return "BeVietnamPro-Regular"
    case .inter:     return "Inter-Regular"
    case .notoSans:  return "NotoSansDisplay-Regular"
    case .lora:      return "Lora-Regular"
    case .nunito:    return "Nunito-Regular"
    }
  }
}

/// 2.16: cấu hình chi tiết LƯU THEO TỪNG THEME (font, bo góc, mật độ, độ trong).
/// Đổi theme sẽ khôi phục đúng cấu hình của theme đó.
struct ThemeConfig: Codable, Defaults.Serializable, Equatable {
  var font: ThemeFont
  var radius: ThemeRadius
  var density: ThemeDensity
  var clarity: Double          // Liquid Glass: độ trong suốt · Neural: cường độ phát sáng
  var accent: AccentColorChoice = .red   // màu nhấn per-theme

  static let tonalDefault  = ThemeConfig(font: .system, radius: .medium, density: .regular, clarity: 0.5, accent: .red)
  static let glassDefault  = ThemeConfig(font: .system, radius: .round, density: .regular, clarity: 0.55, accent: .red)
  static let neuralDefault = ThemeConfig(font: .system, radius: .medium, density: .regular, clarity: 0.45, accent: .purple)

  static func defaultFor(_ theme: UITheme) -> ThemeConfig {
    switch theme {
    case .tonal:  return tonalDefault
    case .glass:  return glassDefault
    case .neural: return neuralDefault
    }
  }
}

/// Chuẩn hoá bundle ID để so sánh/lưu (trim + lowercase).
func normalizedBundleIdentifier(_ raw: String) -> String {
  raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

extension Defaults.Keys {
  /// v2.1.1: UI theme toàn cục. Switch không cần restart — HUD/Settings/icon
  /// đều đọc qua `Defaults.observe(.uiTheme)`.
  static let uiTheme = Key<UITheme>("ui-theme", default: .tonal)

  /// 2.16: màu accent (brand) cho giao diện redesign — user chọn 1 trong 5.
  static let accentColorChoice = Key<AccentColorChoice>("accent-color-choice", default: .red)

  /// 2.16: chế độ sáng/tối cho cửa sổ Settings — auto theo hệ thống / sáng / tối.
  static let appearanceMode = Key<AppearanceMode>("appearance-mode", default: .auto)

  /// 2.16: cấu hình tuỳ chỉnh theo từng theme (font/bo góc/mật độ/độ trong).
  static let themeConfigs = Key<[String: ThemeConfig]>("theme-configs", default: [
    UITheme.tonal.rawValue: .tonalDefault,
    UITheme.glass.rawValue: .glassDefault,
    UITheme.neural.rawValue: .neuralDefault,
  ])

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
  /// Tổ hợp modifier-only (vd Shift+Option, Control+Shift) dùng để chuyển
  /// đổi VI/EN. 0 = không dùng. Bit layout giống NSEvent.ModifierFlags
  /// (.shift=0x20000, .control=0x40000, .option=0x80000…).
  /// Default 2.0.2: ⇧⌥ (Shift+Option). Trước đó (1.x–2.0.1): ⌃⇧.
  static let modifierOnlyToggleHotkey = Key<Int>(
    "modifier-only-toggle-hotkey",
    default: kDefaultModifierOnlyMask
  )

  /// 2.0.2 (J3): tổ hợp modifier-only dùng để mở Text Tools menu (B4).
  /// 0 = tắt. Default: ⌃⇧ (Control+Shift). EventHook check trên cùng path
  /// với `modifierOnlyToggleHotkey` — trigger khi user nhấn + thả mask này
  /// không kèm letter/punct key. Nếu mask trùng với toggle hotkey, toggle
  /// thắng (check trước trong event handler).
  static let modifierOnlyTextToolsHotkey = Key<Int>(
    "modifier-only-text-tools-hotkey",
    default: kDefaultTextToolsMask
  )

  /// Modifier-only override cho phím mở menu lịch sử clipboard (0 = dùng key+modifier).
  static let clipboardHistoryModifierOnlyHotkey = Key<Int>(
    "clipboard-history-modifier-only-hotkey",
    default: 0
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

  /// Tự động tải và cài bản mới im lặng qua Sparkle (3.23+).
  /// Tắt → chỉ kiểm tra/cài thủ công từ menu bar.
  static let autoUpdateEnabled = Key<Bool>("auto-update-enabled", default: true)

  /// Phiên bản hiển thị HUD "cập nhật hoàn tất" sau khi Sparkle relaunch.
  static let pendingUpdateSuccessHUDVersion = Key<String>(
    "pending-update-success-hud-version",
    default: ""
  )

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

  /// Bundle ID các app không chạy đoán từ (HUD + Tab chấp nhận).
  static let wordPredictionExcludedApps = Key<[String]>(
    "word-prediction-excluded-apps",
    default: []
  )

  /// Số từ tối đa trong gợi ý đoán (1–3). Mặc định 2 — gợi ý cụm ngắn
  /// thay vì chỉ một từ đơn.
  static let predictionMaxWords = Key<Int>("prediction-max-words", default: 2)

  /// 1.8.1: số dòng văn bản cách giữa HUD prediction và caret line.
  /// Range 1-10. Default 4 (cân bằng giữa nhìn rõ và không che nội dung).
  /// Trước 1.8.1 HUD chỉ cách caret 4px — quá gần, hay che dòng đang gõ.
  static let predictionHUDLineOffset = Key<Int>("prediction-hud-line-offset", default: 4)

  /// 1.9.0: font size cho text trong PredictionHUD.
  /// 1.9.4: default 13 → 16, range 10-20 → 12-24. User feedback v1.9.3 chữ
  /// quá bé, khó đọc trên material background. Font weight cũng tăng
  /// medium → semibold trong View (đậm hơn).
  static let predictionHUDFontSize = Key<Int>("prediction-hud-font-size", default: 16)

  /// 1.9.0: opacity cho HUD (cả PredictionHUD và ToggleHUD).
  /// 1.9.4: default 100 → 75, range 50-100 → 30-100. User feedback ToggleHUD
  /// cần trong suốt hơn. User mới install sẽ thấy 75% — có thể chỉnh xuống
  /// 30% (rất trong suốt) hoặc lên 100% (đậm hẳn). User existing với value
  /// đã set giữ nguyên (Defaults default chỉ apply lần đầu).
  static let hudOpacityPercent = Key<Int>("hud-opacity-percent", default: 75)

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

  /// 1.9.1: preset cấu hình nhanh tính năng. 0=Người dùng (custom),
  /// 1=Cơ bản, 2=Trung bình, 3=Cao. Khi user select preset → batch update
  /// các toggle theo mapping ở SettingView. Khi user edit individual
  /// toggle → tự revert sang .custom.
  static let quickConfigPreset = Key<Int>("quick-config-preset", default: 0)

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

  //            ^            ^         ^                ^
  //           Key          Type   UserDefaults name   Default value

  // MARK: - 2.0 — Track 1: Foundation & Quick Wins

  /// A5 (2.0): viết hoa chữ đầu sau Enter, hoặc sau `.` `!` `?` kèm space.
  /// Không viết hoa ngay sau dấu câu (domain, số thập phân, viết tắt).
  static let autoCapitalizeEnabled = Key<Bool>("auto-capitalize-enabled", default: true)

  /// B2 (2.0): tự động disable vkey khi user chuyển input source sang
  /// non-Latin IME (Japanese / Chinese / Korean / Arabic …). Khi user
  /// quay về Latin input source, restore state trước đó qua Smart Switch.
  /// Theo dõi qua `kTISNotifySelectedKeyboardInputSourceChanged`.
  static let nonLatinIMEAutoDisable = Key<Bool>(
    "non-latin-ime-auto-disable",
    default: true
  )

  // MARK: - 2.0 — Track 2: UX Modern Layer
  //
  // 2.0.1: `floatingToolbarEnabled`, `hudThemeStyle`, `hudBlurIntensity`,
  // `hudAccentColorHex` đã bị xoá. Floating Toolbar không còn tính năng,
  // HUDThemeSection chưa wire vào HUD thực — gây nhầm lẫn user. Dùng
  // `hudOpacityPercent` (1.9.0) cho điều chỉnh HUD đang hoạt động.

  // 2.0.2 (J1): xoá `predictionTopN` — multi-candidate UI bị bỏ.

  /// B1 (2.0): danh sách rules theo bundle ID + window title regex để
  /// override hành vi vkey per-context (vd Google Docs delay 50ms,
  /// Notion tắt prediction). Settings UI ở tab "Rules".
  static let windowTitleRules = Key<[WindowTitleRule]>("window-title-rules", default: [])

  // MARK: - 2.0 — Track 3: Compatibility & Stability

  /// A6 (2.0): bypass syllable validator để đặt dấu ở vị trí bất kỳ.
  /// Hữu ích cho linguist, tên riêng, tiếng dân tộc. Default off vì
  /// thay đổi hành vi chuẩn xác cho user thông thường.
  static let freeMarkModeEnabled = Key<Bool>("free-mark-mode-enabled", default: false)

  /// C4 (2.0): bật race-condition hardening cho CGEvent tap. Re-entry
  /// guards, pending-event queue khi đang flush. Default on — tăng độ
  /// ổn định trong Spotlight/Chrome/Arc overlays.
  static let cgEventRaceHardeningEnabled = Key<Bool>(
    "cgevent-race-hardening-enabled",
    default: true
  )

  /// C4 (2.0): adaptive delay (ms) khi flush event tới một số app
  /// nhạy cảm. Map theo bundle ID trong Window Title Rules; key này
  /// là default fallback.
  static let cgEventFlushDelayMs = Key<Int>("cgevent-flush-delay-ms", default: 0)

  /// Bật lịch sử clipboard: ⌘C lưu; phím tắt (mặc định ⇧⌘V) mở menu chọn.
  static let clipboardHistoryEnabled = Key<Bool>("clipboard-history-enabled", default: false)

  /// Số mục clipboard tối đa giữ trong RAM (3–50).
  static let clipboardHistoryCapacity = Key<Int>("clipboard-history-capacity", default: 10)

  /// Chỉ văn bản hoặc cả tệp (file URL) khi lưu lịch sử.
  static let clipboardHistoryContentMode = Key<ClipboardHistoryContentMode>(
    "clipboard-history-content-mode",
    default: .textOnly
  )

  /// Dung lượng tối đa mỗi mục lịch sử clipboard (MB, 1–200). Mặc định 10 MB.
  static let clipboardHistoryMaxEntryMegabytes = Key<Int>(
    "clipboard-history-max-entry-megabytes",
    default: 10
  )
}

// MARK: - 2.0 — Window Title Rule types
//
// 2.0.1: `enum HUDThemeStyle` đã được xoá cùng HUDThemeSection.

/// B1 (2.0): rule cho per-context behavior. Áp dụng theo bundle ID
/// (prefix match) cộng window title regex. Nếu cả hai match → áp dụng
/// các override trong rule.
///
/// Ranking: rule có cả `bundleIdPrefix` + `titleRegex` thắng rule chỉ có
/// `bundleIdPrefix`. Rules được lưu theo thứ tự — rule đầu tiên match
/// trước thắng (cho phép user override bằng cách kéo lên trên).
struct WindowTitleRule: Codable, Hashable, Identifiable, Defaults.Serializable {
  var id: UUID = UUID()
  var name: String = ""

  /// Bundle ID prefix (vd "com.google.Chrome"). Empty = match mọi app.
  var bundleIdPrefix: String = ""

  /// Regex matching window title. Empty = match mọi title.
  var titleRegex: String = ""

  /// Override Smart Switch state khi rule match. nil = không override.
  var overrideState: AppSmartSwitchState? = nil

  /// Force tắt word prediction trong context này.
  var disablePrediction: Bool = false

  /// Force tắt spell check trong context này.
  var disableSpellCheck: Bool = false

  /// Adaptive delay (ms) khi flush event (C4) — vd Google Docs cần 50ms.
  /// 0 = dùng default (`cgEventFlushDelayMs`).
  var flushDelayMs: Int = 0

  /// Enable for user to disable rule temporarily without deleting.
  var enabled: Bool = true
}

