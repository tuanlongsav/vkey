//
//  SettingsModels.swift
//  vkey
//
//  Domain models persisted via Defaults (macros, spell restore policy,
//  personal dictionary suggestions, Smart Switch, and per-app sending mode).
//

import Defaults
import Foundation

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

/// Trạng thái Smart Switch per-app.
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

  var enablesVietnamese: Bool { self == .vietnameseMode }
}

/// Nguồn gốc cài đặt — phân biệt user thủ công vs auto-learn từ stats.
enum AppSmartSwitchSource: String, CaseIterable, Codable, Defaults.Serializable {
  case user        // 👤 User set thủ công (override auto-learn)
  case autoLearn   // 🤖 Do "Tự học từ Thống kê" ghi

  var displayName: String {
    switch self {
    case .user: return "Người dùng đặt"
    case .autoLearn: return "Tự động học"
    }
  }
}

/// Cách gửi phím do người dùng chọn cho một app, đè lên bảng dựng sẵn.
enum AppSendingMode: String, CaseIterable, Codable, Defaults.Serializable {
  case fast
  case paced
  case stepByStep

  var label: String {
    switch self {
    case .fast: return "Nhanh"
    case .paced: return "Có nhịp nghỉ"
    case .stepByStep: return "Từng phím"
    }
  }
}

/// Cấu hình Smart Switch per-app. User setting (`source == .user`) luôn ưu tiên hơn `autoLearn`.
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
