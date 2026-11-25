//
//  VKDesign.swift
//  vkey — Unified "Tonal" design system tokens (palette, semantic colors, radii,
//  density, spacing, typography, HUD constants, motion).
//

import AppKit
import Defaults
import SwiftUI

// MARK: - Dynamic & Hex Color Helpers

extension Color {
  /// Resolve `lightVK` ở light mode, `darkVK` ở dark mode (AppKit-backed).
  init(lightVK: Color, darkVK: Color) {
    self = Color(nsColor: NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      return NSColor(isDark ? darkVK : lightVK)
    })
  }

  /// Hex (#RRGGBB hoặc #RRGGBBAA).
  init(vkHex hex: String) {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    let r, g, b, a: Double
    if s.count == 8 {
      r = Double((v >> 24) & 0xFF) / 255
      g = Double((v >> 16) & 0xFF) / 255
      b = Double((v >> 8) & 0xFF) / 255
      a = Double(v & 0xFF) / 255
    } else {
      r = Double((v >> 16) & 0xFF) / 255
      g = Double((v >> 8) & 0xFF) / 255
      b = Double(v & 0xFF) / 255
      a = 1
    }
    self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}

// MARK: - HUD Display NSFont (shared between measurement and rendering)

/// Font tiêu đề HUD dùng CHUNG cho cả đo panel (`ToggleHUDWindow.contentSize`)
/// lẫn render (`ToggleHUDView`). Ưu tiên `NotoSansDisplay` nhúng kèm; fallback SF Rounded bold.
func hudTitleNSFont(_ size: CGFloat) -> NSFont {
  let base: NSFont
  if let noto = NSFont(name: "NotoSansDisplay", size: size) {
    base = noto
  } else if let roundedDesc = NSFont.systemFont(ofSize: size, weight: .regular)
    .fontDescriptor.withDesign(.rounded),
    let rounded = NSFont(descriptor: roundedDesc, size: size)
  {
    base = rounded
  } else {
    base = NSFont.systemFont(ofSize: size, weight: .regular)
  }
  let boldDesc = base.fontDescriptor.withSymbolicTraits(.bold)
  return NSFont(descriptor: boldDesc, size: size) ?? base
}

// MARK: - Namespace

enum VK {

  /// Cấu hình của theme đang chọn (cached để tránh giải mã JSON lặp khi render).
  static var theme: ThemeConfig { themeCache.value }

  private static let themeCache = DefaultsDerivedCache<ThemeConfig>(.uiTheme, .themeConfigs) {
    let current = Defaults[.uiTheme]
    return Defaults[.themeConfigs][current.rawValue] ?? ThemeConfig.defaultFor(current)
  }

  /// Theme Neural AI đang bật?
  static var isNeural: Bool { Defaults[.uiTheme] == .neural }

  /// Hệ số glow Neural (`0.25 + clarity * 1.05`).
  static var glowK: Double { 0.25 + theme.clarity * 1.05 }

  // MARK: Palette (ramp gốc)

  enum Palette {
    typealias Color = SwiftUI.Color
    static let red500 = Color(vkHex: "#E04434")

    static let gold300 = Color(vkHex: "#FAD37A")
    static let gold500 = Color(vkHex: "#E5AE1C")

    static let paper0   = Color(vkHex: "#FFFFFF")
    static let paper50  = Color(vkHex: "#FAF8F4")
    static let paper100 = Color(vkHex: "#F2EFE8")
    static let paper200 = Color(vkHex: "#E6E1D6")
    static let paper300 = Color(vkHex: "#D2CCBC")

    static let ink100 = Color(vkHex: "#4B4F58")
    static let ink200 = Color(vkHex: "#353841")
    static let ink300 = Color(vkHex: "#24272E")
    static let ink400 = Color(vkHex: "#1A1C22")
    static let ink500 = Color(vkHex: "#131519")
    static let ink600 = Color(vkHex: "#0E0F12")

    static let success = Color(vkHex: "#2BB673")
    static let warning = Color(vkHex: "#E5AE1C")
    static let danger  = Color(vkHex: "#D9344A")
    static let info    = Color(vkHex: "#2D89E5")
  }

  // MARK: HUD Constants (folded from legacy VKeyDesign)

  enum HUD {
    /// Liquid Glass primary panel scrim.
    static let glassScrim = SwiftUI.Color(vkHex: "#14161C")
    /// Refractive corner tint strength (24% red bottom-left).
    static let refractiveStrength: Double = 0.24
  }

  // MARK: Semantic Colors (adaptive light/dark)

  enum Color {
    typealias C = SwiftUI.Color

    static var brand: C    { C(vkHex: VK.theme.accent.hex) }
    static var brand600: C { C(vkHex: VK.theme.accent.hex600) }
    static var brand700: C { C(vkHex: VK.theme.accent.hex700) }
    static var brand400: C { C(vkHex: VK.theme.accent.hex400) }
    static var brand300: C { C(vkHex: VK.theme.accent.hex300) }
    static var brandText: C {
      C(lightVK: C(vkHex: VK.theme.accent.hex600), darkVK: C(vkHex: VK.theme.accent.hex300))
    }
    static var accent: C {
      let base = C(vkHex: VK.theme.accent.hex)
      return C(lightVK: base, darkVK: base.opacity(0.92))
    }

    static func accentSwatch(_ choice: AccentColorChoice) -> C {
      C(vkHex: choice.hex)
    }

    static var brandGradient: LinearGradient {
      if VK.isNeural {
        return LinearGradient(
          colors: [C(vkHex: "#8B5CF6"), C(vkHex: VK.theme.accent.hex), C(vkHex: "#22D3EE")],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      return LinearGradient(colors: [brand, brand], startPoint: .leading, endPoint: .trailing)
    }

    static let glow = C(vkHex: "#7C5CFF")

    private static var neural: Bool { VK.isNeural }

    static var bg: C {
      neural ? C(lightVK: C(vkHex: "#F4F3FB"), darkVK: C(vkHex: "#0B0B14"))
             : C(lightVK: Palette.paper50, darkVK: Palette.ink500)
    }
    static var bgElevated: C {
      neural ? C(lightVK: C(vkHex: "#FFFFFF"), darkVK: C(vkHex: "#16161F"))
             : C(lightVK: Palette.paper0, darkVK: Palette.ink400)
    }
    static var bgSunken: C {
      neural ? C(lightVK: C(vkHex: "#ECECF6"), darkVK: C(vkHex: "#08080F"))
             : C(lightVK: Palette.paper100, darkVK: Palette.ink600)
    }
    static var bgHover: C {
      neural ? C(lightVK: C(vkHex: "#F0EFF9"), darkVK: C(vkHex: "#1A1A26"))
             : C(lightVK: Palette.paper100, darkVK: Palette.ink400)
    }
    static var bgPress: C {
      neural ? C(lightVK: C(vkHex: "#E6E5F2"), darkVK: C(vkHex: "#20202E"))
             : C(lightVK: Palette.paper200, darkVK: Palette.ink300)
    }

    static var fg1: C {
      neural ? C(lightVK: C(vkHex: "#14141F"), darkVK: C(vkHex: "#ECECF7"))
             : C(lightVK: Palette.ink500, darkVK: C(vkHex: "#F2EFE8"))
    }
    static var fg2: C {
      neural ? C(lightVK: C(vkHex: "#4B4B63"), darkVK: C(vkHex: "#ADADC8"))
             : C(lightVK: Palette.ink200, darkVK: C(vkHex: "#C7C3B7"))
    }
    static var fg3: C {
      neural ? C(lightVK: C(vkHex: "#8A8AA6"), darkVK: C(vkHex: "#71718E"))
             : C(lightVK: Palette.ink100, darkVK: C(vkHex: "#9B978B"))
    }
    static var fgMuted: C {
      neural ? C(lightVK: C(vkHex: "#6C6C82"), darkVK: C(vkHex: "#8585A0"))
             : C(lightVK: C(vkHex: "#757058"), darkVK: C(vkHex: "#8A8578"))
    }
    static let fgInverse = C(lightVK: Palette.paper0, darkVK: Palette.ink600)

    static var border1: C {
      neural ? C(lightVK: C(vkHex: "#141432").opacity(0.07), darkVK: C(vkHex: "#FFFFFF").opacity(0.07))
             : C(lightVK: Palette.paper200, darkVK: C(vkHex: "#FFFFFF").opacity(0.08))
    }
    static var border2: C {
      neural ? C(lightVK: C(vkHex: "#141432").opacity(0.10), darkVK: C(vkHex: "#FFFFFF").opacity(0.11))
             : C(lightVK: Palette.paper300, darkVK: C(vkHex: "#FFFFFF").opacity(0.14))
    }

    static let success = Palette.success
    static let warning = Palette.warning
    static let danger  = Palette.danger
    static let info    = Palette.info
    static let gold    = Palette.gold500
    static let ink200  = Palette.ink200

    static let successSoft = C(lightVK: C(vkHex: "#DCF3E7"), darkVK: Palette.success.opacity(0.18))
    static let warningSoft = C(lightVK: C(vkHex: "#FAF1D6"), darkVK: Palette.warning.opacity(0.18))
    static let dangerSoft  = C(lightVK: C(vkHex: "#FBE0E3"), darkVK: Palette.danger.opacity(0.18))
    static let infoSoft    = C(lightVK: C(vkHex: "#DDEBF9"), darkVK: Palette.info.opacity(0.18))

    static let successText = C(lightVK: C(vkHex: "#126B45"), darkVK: C(vkHex: "#7FD9AC"))
    static let warningText = C(lightVK: C(vkHex: "#7E5B07"), darkVK: Palette.gold300)
    static let dangerText  = C(lightVK: C(vkHex: "#8E1F2E"), darkVK: C(vkHex: "#F0909E"))
    static let infoText    = C(lightVK: C(vkHex: "#1A579E"), darkVK: C(vkHex: "#8FC1F3"))

    static func tileAccent(_ base: C) -> C {
      guard VK.Glass.isOn || VK.isNeural else { return base }
      guard let rgb = NSColor(base).usingColorSpace(.sRGB) else { return base }
      let lum = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
      if lum < 0.42 { return fg2 }
      return base
    }
  }

  // MARK: Radii

  enum Radius {
    private static var k: CGFloat { VK.theme.radius.scale }
    static var xs: CGFloat  { max(2, 4 * k) }
    static var sm: CGFloat  { max(3, 6 * k) }
    static var md: CGFloat  { max(4, 10 * k) }
    static var lg: CGFloat  { max(5, 14 * k) }
    static var xl: CGFloat  { max(7, 20 * k) }
    static var xxl: CGFloat { max(9, 28 * k) }
    static let pill: CGFloat = 999

    static func scaled(_ base: CGFloat) -> CGFloat { max(2, base * k) }
  }

  // MARK: Density

  enum Density {
    static var rowV: CGFloat { VK.theme.density.rowPaddingV }
    static var sectionGap: CGFloat { VK.theme.density.sectionGap }
  }

  // MARK: Liquid Glass

  enum Glass {
    typealias C = SwiftUI.Color
    static var isOn: Bool { Defaults[.uiTheme] == .glass }
    static func panel(dark: Bool) -> C {
      let a = max(0.28, 0.80 - VK.theme.clarity * 0.52)
      return dark ? C(.sRGB, red: 30/255, green: 27/255, blue: 33/255, opacity: a)
                  : C(.sRGB, red: 252/255, green: 250/255, blue: 247/255, opacity: a)
    }
    static func card(dark: Bool) -> C {
      let base = dark ? 0.10 : 0.42
      return C.white.opacity(base + (1 - VK.theme.clarity) * 0.16)
    }
    static let edge = C(lightVK: C.white.opacity(0.75), darkVK: C.white.opacity(0.26))
    static let edgeLo = C(lightVK: C.white.opacity(0.32), darkVK: C.white.opacity(0.10))
    static let hairline = C(lightVK: C(vkHex: "#785A46").opacity(0.12), darkVK: C.white.opacity(0.08))
  }

  // MARK: Spacing (4pt base)

  enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40
  }

  // MARK: Typography

  enum TypeStyle {
    case h1, h2, h3, h4, body, bodyLg, small, micro, eyebrow, monoSm, monoMd
  }

  enum Font {
    /// Font sans của theme ở cỡ/đậm tuỳ ý — thay `.system(size:weight:)` trong
    /// Settings & MenuBar để lựa chọn "Phông chữ" có tác dụng nhất quán.
    static func sans(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
      if let name = VK.theme.font.postScriptName {
        return .custom(name, size: size).weight(weight)
      }
      return .system(size: size, weight: weight)
    }

    /// Font display cho HUD (ưu tiên Noto Sans Display nhúng kèm; fallback SF Rounded).
    static func hudDisplay(_ size: CGFloat, weight: SwiftUI.Font.Weight = .heavy) -> SwiftUI.Font {
      if NSFont(name: "NotoSansDisplay", size: size) != nil {
        return SwiftUI.Font.custom("NotoSansDisplay", size: size).weight(weight)
      }
      return .system(size: size, weight: weight, design: .rounded)
    }

    static func style(_ s: TypeStyle) -> SwiftUI.Font {
      let (size, weight): (CGFloat, SwiftUI.Font.Weight)
      switch s {
      case .h1:      (size, weight) = (30, .bold)
      case .h2:      (size, weight) = (22, .semibold)
      case .h3:      (size, weight) = (17, .semibold)
      case .h4:      (size, weight) = (15, .semibold)
      case .body:    (size, weight) = (13.5, .regular)
      case .bodyLg:  (size, weight) = (15, .regular)
      case .small:   (size, weight) = (12.5, .regular)
      case .micro:   (size, weight) = (11, .medium)
      case .eyebrow: (size, weight) = (11, .semibold)
      case .monoSm:  return .system(size: 12, weight: .medium, design: .monospaced)
      case .monoMd:  return .system(size: 13, weight: .medium, design: .monospaced)
      }
      return sans(size, weight)
    }
  }

  // MARK: Motion

  enum Motion {
    static let durFast: Double = 0.12
    static let durBase: Double = 0.18
    static let durSlow: Double = 0.28
    static let easeOut = Animation.timingCurve(0.22, 1, 0.36, 1, duration: durBase)
    static let spring  = Animation.spring(response: 0.34, dampingFraction: 0.7)
  }
}

// MARK: - Sugar

extension SwiftUI.Font {
  static func vk(_ s: VK.TypeStyle) -> SwiftUI.Font { VK.Font.style(s) }
}
