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

enum DictionaryUpdateChannel: String, CaseIterable, Defaults.Serializable {
  case embeddedOnly
  case hybrid
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

  /// Cấu hình nguồn dữ liệu từ điển.
  static let dictionaryUpdateChannel = Key<DictionaryUpdateChannel>(
    "dictionary-update-channel",
    default: .hybrid
  )

  /// Bật tính năng tự động cập nhật từ điển từ GitHub.
  static let dictionaryGitHubUpdateEnabled = Key<Bool>("dictionary-github-update-enabled", default: true)

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

  //            ^            ^         ^                ^
  //           Key          Type   UserDefaults name   Default value
}
