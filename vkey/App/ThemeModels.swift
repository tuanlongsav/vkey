//
//  ThemeModels.swift
//  vkey
//
//  Persisted appearance and theme customization models (Tonal / Liquid Glass / Neural).
//

import CoreGraphics
import Defaults
import Foundation

/// Lựa chọn màu accent cho giao diện (5 màu, mỗi màu có ramp 5 stop).
enum AccentColorChoice: String, CaseIterable, Codable, Defaults.Serializable {
  case red       // #E04434 (mặc định)
  case gold      // #E5AE1C
  case green     // #2BB673
  case blue      // #2D89E5
  case purple    // #8B5CF6

  var hex: String { ramp.s500 }

  /// `[500, 600, 700, 400, 300]`
  var ramp: (s500: String, s600: String, s700: String, s400: String, s300: String) {
    switch self {
    case .red:    return ("#E04434", "#C8341F", "#A52817", "#EB6249", "#F18A74")
    case .gold:   return ("#E5AE1C", "#B5860D", "#8A6608", "#F5C645", "#FAD37A")
    case .green:  return ("#2BB673", "#1F9E62", "#17794B", "#4FC98D", "#7FD9AC")
    case .blue:   return ("#2D89E5", "#1E6FC4", "#17559A", "#5AA4EC", "#8FC1F3")
    case .purple: return ("#8B5CF6", "#7440E0", "#5B2FB8", "#A67DF9", "#C3A6FC")
    }
  }

  var hex600: String { ramp.s600 }
  var hex700: String { ramp.s700 }
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

/// Chế độ sáng/tối cho cửa sổ Settings.
enum AppearanceMode: String, CaseIterable, Defaults.Serializable {
  case auto, light, dark
}

/// Theme diện mạo toàn cục của app.
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

/// Độ bo góc toàn cục.
enum ThemeRadius: String, CaseIterable, Codable, Defaults.Serializable {
  case sharp, medium, round

  var displayName: String {
    switch self {
    case .sharp:  return "Sắc"
    case .medium: return "Vừa"
    case .round:  return "Tròn"
    }
  }

  var scale: CGFloat {
    switch self {
    case .sharp:  return 0.45
    case .medium: return 1.0
    case .round:  return 1.7
    }
  }
}

/// Mật độ dòng cài đặt — gọn / vừa / thoáng.
enum ThemeDensity: String, CaseIterable, Codable, Defaults.Serializable {
  case compact, regular, comfy

  var displayName: String {
    switch self {
    case .compact: return "Gọn"
    case .regular: return "Vừa"
    case .comfy:   return "Thoáng"
    }
  }

  var rowPaddingV: CGFloat {
    switch self {
    case .compact: return 7
    case .regular: return 11
    case .comfy:   return 15
    }
  }

  var sectionGap: CGFloat {
    switch self {
    case .compact: return 18
    case .regular: return 24
    case .comfy:   return 30
    }
  }
}

/// Font chữ giao diện. `.system` = SF; còn lại là font nhúng kèm app.
enum ThemeFont: String, CaseIterable, Codable, Defaults.Serializable {
  case system, beVietnam, inter, notoSans, lora, nunito

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

/// Cấu hình chi tiết lưu riêng theo từng theme (font, bo góc, mật độ, độ trong, màu nhấn).
struct ThemeConfig: Codable, Defaults.Serializable, Equatable {
  var font: ThemeFont
  var radius: ThemeRadius
  var density: ThemeDensity
  var clarity: Double
  var accent: AccentColorChoice = .red

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
