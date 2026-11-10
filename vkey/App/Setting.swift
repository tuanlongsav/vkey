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
import os
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

  /// Trạng thái này có bật gõ tiếng Việt không. `englishMode` và `disabled`
  /// đều là "không" — với đường gõ phím hai trạng thái đó như nhau.
  var enablesVietnamese: Bool { self == .vietnameseMode }
}

/// Nguồn gốc cài đặt — phân biệt user thủ công vs auto-learn từ stats.
enum AppSmartSwitchSource: String, CaseIterable, Codable, Defaults.Serializable {
  case user        // 👤 User set thủ công (override auto-learn)
  case autoLearn   // 🤖 Do "Tự học từ Thống kê" ghi (trước 4.35 còn tự ghi mỗi ngày)

  var displayName: String {
    switch self {
    case .user: return "Người dùng đặt"
    case .autoLearn: return "Tự động học"
    }
  }
}

/// Cách gửi phím do NGƯỜI DÙNG chọn cho một app, đè lên bảng dựng sẵn
/// `EventSimulator.appStrategies`. Không có mục "tự động": app không nằm trong
/// `Defaults[.appSendingModes]` là tự động.
///
/// Có để người dùng tự chữa một app rớt/lặp chữ mà không chờ bản mới — cách Gõ
/// Nhanh, Caffee và ibus-bamboo đều làm. Thay cho ô "độ trễ" của quy tắc theo
/// tiêu đề cửa sổ (đã gỡ ở 4.35).
enum AppSendingMode: String, CaseIterable, Codable, Defaults.Serializable {
  /// Backspace và chữ thay đi liền nhau, không nghỉ. Nhanh nhất.
  case fast
  /// Nghỉ một nhịp giữa các backspace rồi mới gửi chữ thay.
  case paced
  /// Từng backspace, từng ký tự một, có nghỉ. Chậm nhất, tương thích nhất.
  case stepByStep

  var label: String {
    switch self {
    case .fast: return "Nhanh"
    case .paced: return "Có nhịp nghỉ"
    case .stepByStep: return "Từng phím"
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
  // v4.23: GỠ `autoSwitchStrategy` ("auto-switch-strategy"). Nó là công tắc của
  // `TransformationTracker` — cơ chế tự đổi chiến lược gửi phím không bao giờ
  // chạy được (xem MARK InputProcessor). Không có UI, không nằm trong
  // export/import của UserDataMigration, nên gỡ key không phá bản export cũ nào;
  // giá trị đã lưu trong UserDefaults chỉ nằm im. Đừng thêm lại.
  /// Tự động chuyển sang tiếng Anh khi launcher app (Spotlight/Raycast/Alfred…) lên foreground.
  static let smartSwitchEnabled = Key<Bool>("smart-switch-enabled", default: true)
  /// Danh sách các ứng dụng tự động chuyển sang gõ Tiếng Anh khi kích hoạt.
  /// v4.11: bỏ Spotlight. v4.12: default RỖNG — Spotlight + launcher (Raycast/
  /// Alfred/LaunchBar) giờ đều THEO MODE hiện tại của người dùng (không ép
  /// English mặc định); lựa chọn VN/EN do người dùng quyết định, tự thêm app
  /// vào danh sách ép-English qua Settings nếu muốn. Migration dọn config đã
  /// seed: `AppState.migrateSpotlightKeepMode` + `migrateLaunchersKeepMode`.
  static let smartSwitchApps = Key<[String]>("smart-switch-apps", default: [])
  /// v4.11: cờ một lần — đã gỡ Spotlight khỏi Smart Switch (theo-mode) chưa.
  static let didMigrateSpotlightKeepMode =
    Key<Bool>("did-migrate-spotlight-keep-mode", default: false)
  /// v4.12: cờ một lần — đã gỡ launcher (Raycast/Alfred/LaunchBar) khỏi Smart
  /// Switch (theo-mode) chưa.
  static let didMigrateLaunchersKeepMode =
    Key<Bool>("did-migrate-launchers-keep-mode", default: false)
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


  
  /// Tuỳ chọn kiểu đặt dấu: false = Kiểu cũ (hòa, khỏe), true = Kiểu mới (hoà, khoẻ).
  static let newStyleTonePlacement = Key<Bool>("new-style-tone-placement", default: true)

  /// Tự động sửa lỗi gõ nhầm (ví dụ: thfi -> thì, dinjhd -> định)
  static let autoTypoCorrection = Key<Bool>("auto-typo-correction", default: true)

  /// Hiển thị HUD khi chuyển đổi bộ gõ
  static let hudEnabled = Key<Bool>("hud-enabled", default: true)

  /// Bật kiểm tra từ điển/chính tả trước khi auto-restore và gợi ý.
  static let spellCheckEnabled = Key<Bool>("spell-check-enabled", default: true)

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

  /// Bật ghi thống kê sử dụng (chỉ lưu local, không gửi đi đâu).
  static let statisticsEnabled = Key<Bool>("statistics-enabled", default: true)

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

  /// 1.9.0: opacity cho HUD (ToggleHUD và NoticeHUD).
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

  /// Cách gửi phím người dùng chọn theo bundle ID. App không có trong đây dùng
  /// bảng dựng sẵn (`EventSimulator.appStrategies`).
  static let appSendingModes = Key<[String: AppSendingMode]>("app-sending-modes", default: [:])

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


  // MARK: - 2.0 — Track 3: Compatibility & Stability

  /// A6 (2.0): bypass syllable validator để đặt dấu ở vị trí bất kỳ.
  /// Hữu ích cho linguist, tên riêng, tiếng dân tộc. Default off vì
  /// thay đổi hành vi chuẩn xác cho user thông thường.
  static let freeMarkModeEnabled = Key<Bool>("free-mark-mode-enabled", default: false)

}

// MARK: - Cache giá trị suy ra từ Defaults

/// Giá trị dựng từ một hay nhiều key Defaults, dựng lần đầu khi đọc rồi giữ lại
/// cho tới khi một key nguồn đổi.
///
/// Có vì `Defaults[key]` KHÔNG rẻ với giá trị `Codable` (`[Macro]`,
/// `[String: ThemeConfig]`, `[String: AppSmartSwitchConfig]`…): mỗi lần đọc là
/// giải mã JSON lại từng phần tử. Mấy key đó từng bị đọc ở mỗi phím / mỗi từ /
/// mỗi token màu.
///
/// Huỷ bằng KVO của UserDefaults, gọi ĐỒNG BỘ ngay trong lời gán
/// `Defaults[key] = …` (kể cả `Defaults.reset`), nên lần đọc ngay sau đó đã
/// thấy giá trị mới. Hai ngoại lệ: ghi bên trong `Defaults.withoutPropagation`
/// (thư viện nuốt KVO — repo chưa dùng; dùng thì gọi `invalidate()` tay) và
/// ghi từ tiến trình khác (`defaults write`), tới trễ một nhịp. `generation`
/// chặn việc cất một bản dựng từ giá trị cũ khi key đổi giữa lúc đang dựng
/// (KVO chạy trên thread của người ghi).
final class DefaultsDerivedCache<Value: Sendable>: @unchecked Sendable {
  private struct State {
    var generation = 0
    var value: Value?
  }

  private let state = OSAllocatedUnfairLock(initialState: State())
  private let compute: () -> Value
  private var observations: [Defaults.Observation] = []

  init(_ keys: Defaults._AnyKey..., compute: @escaping () -> Value) {
    self.compute = compute
    observations = keys.map { key in
      Defaults.observe(keys: key, options: []) { [weak self] in
        self?.invalidate()
      }
    }
  }

  var value: Value {
    let (generation, cached) = state.withLock { ($0.generation, $0.value) }
    if let cached { return cached }
    let fresh = compute()
    state.withLock {
      if $0.generation == generation { $0.value = fresh }
    }
    return fresh
  }

  func invalidate() {
    state.withLock {
      $0.generation += 1
      $0.value = nil
    }
  }
}
