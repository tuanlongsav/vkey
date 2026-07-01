//
//  VKDesign.swift
//  vkey — "Tonal" design system (redesign 2.16)
//
//  Single source of truth cho màu, bo góc, spacing và type của UI mới.
//  Port từ design handoff `DesignTokens.swift` + colors_and_type.css.
//  Font: SF system hoặc font nhúng theo Defaults.themeFont — kích cỡ
//  và weight bám theo design tokens.
//
//  Dùng:
//    Text("vkey").font(.vk(.h3)).foregroundStyle(VK.Color.fg1)
//    RoundedRectangle(cornerRadius: VK.Radius.md).fill(VK.Color.bgElevated)
//    Toggle("", isOn: $on).tint(VK.Color.brand)
//

import AppKit
import Defaults
import SwiftUI

// MARK: - Dynamic color helper

extension Color {
  /// Resolve `light` ở light mode, `dark` ở dark mode (AppKit-backed).
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

// MARK: - Namespace

enum VK {

  /// Cấu hình của theme đang chọn (font/bo góc/mật độ/độ trong) — đọc per-theme.
  static var theme: ThemeConfig {
    let key = Defaults[.uiTheme].rawValue
    return Defaults[.themeConfigs][key] ?? ThemeConfig.defaultFor(Defaults[.uiTheme])
  }

  /// Theme Neural AI đang bật?
  static var isNeural: Bool { Defaults[.uiTheme] == .neural }

  /// Hệ số glow Neural (ai.css: k = 0.25 + glow/100 * 1.05) — clarity đóng vai
  /// trò "Cường độ phát sáng" khi theme = neural.
  static var glowK: Double { 0.25 + theme.clarity * 1.05 }

  // MARK: Palette (ramp gốc — ưu tiên dùng token semantic `Color` bên dưới)
  enum Palette {
    typealias Color = SwiftUI.Color
    static let red50  = Color(vkHex: "#FEF1EE")
    static let red100 = Color(vkHex: "#FCDED7")
    static let red200 = Color(vkHex: "#F8B6A6")
    static let red300 = Color(vkHex: "#F18A74")
    static let red400 = Color(vkHex: "#EB6249")
    static let red500 = Color(vkHex: "#E04434")   // primary
    static let red600 = Color(vkHex: "#C8341F")
    static let red700 = Color(vkHex: "#A52817")
    static let red800 = Color(vkHex: "#7E1F12")
    static let red900 = Color(vkHex: "#561811")

    static let gold300 = Color(vkHex: "#FAD37A")
    static let gold400 = Color(vkHex: "#F5C645")
    static let gold500 = Color(vkHex: "#E5AE1C")
    static let gold600 = Color(vkHex: "#B5860D")

    static let paper0   = Color(vkHex: "#FFFFFF")
    static let paper50  = Color(vkHex: "#FAF8F4")
    static let paper100 = Color(vkHex: "#F2EFE8")
    static let paper200 = Color(vkHex: "#E6E1D6")
    static let paper300 = Color(vkHex: "#D2CCBC")
    static let paper400 = Color(vkHex: "#A8A293")
    static let paper500 = Color(vkHex: "#7C7768")

    static let ink50  = Color(vkHex: "#6A6E78")
    static let ink100 = Color(vkHex: "#4B4F58")
    static let ink200 = Color(vkHex: "#353841")
    static let ink300 = Color(vkHex: "#24272E")
    static let ink400 = Color(vkHex: "#1A1C22")
    static let ink500 = Color(vkHex: "#131519")
    static let ink600 = Color(vkHex: "#0E0F12")
    static let ink700 = Color(vkHex: "#08090B")

    static let success = Color(vkHex: "#2BB673")
    static let warning = Color(vkHex: "#E5AE1C")
    static let danger  = Color(vkHex: "#D9344A")
    static let info    = Color(vkHex: "#2D89E5")
  }

  // MARK: Semantic colors (tự light/dark)
  enum Color {
    typealias C = SwiftUI.Color

    /// 2.16: brand = màu accent của theme đang chọn (lưu per-theme).
    static var brand: SwiftUI.Color { C(vkHex: VK.theme.accent.hex) }
    /// v4.8: 600/700 lấy đúng stop ramp của accent (hover/press). Trước đây
    /// `brand600` trả TRÙNG brand500 nên hover/press không đổi màu.
    static var brand600: SwiftUI.Color { C(vkHex: VK.theme.accent.hex600) }
    static var brand700: SwiftUI.Color { C(vkHex: VK.theme.accent.hex700) }
    static var brand400: SwiftUI.Color { C(vkHex: VK.theme.accent.hex400) }
    static var brand300: SwiftUI.Color { C(vkHex: VK.theme.accent.hex300) }
    /// Accent DÙNG LÀM CHỮ: 600 trên nền sáng / 300 trên nền tối (a11y).
    static var brandText: SwiftUI.Color {
      C(lightVK: C(vkHex: VK.theme.accent.hex600), darkVK: C(vkHex: VK.theme.accent.hex300))
    }
    static var accent: SwiftUI.Color {
      let base = C(vkHex: VK.theme.accent.hex)
      return C(lightVK: base, darkVK: base.opacity(0.92))
    }

    /// Màu accent theo 1 choice cụ thể (cho swatch chọn màu).
    static func accentSwatch(_ choice: AccentColorChoice) -> SwiftUI.Color {
      C(vkHex: choice.hex)
    }

    /// Gradient "trí tuệ" của Neural AI (ai.css --ai-grad): tím #8B5CF6 →
    /// accent (stop giữa) → cyan #22D3EE. Theme khác trả gradient phẳng (1 màu)
    /// để call-site dùng chung không cần rẽ nhánh.
    static var brandGradient: LinearGradient {
      if VK.isNeural {
        return LinearGradient(
          colors: [C(vkHex: "#8B5CF6"), C(vkHex: VK.theme.accent.hex), C(vkHex: "#22D3EE")],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      return LinearGradient(colors: [brand, brand], startPoint: .leading, endPoint: .trailing)
    }

    /// Màu halo violet của Neural (ai.css --ai-glow-rgb 124,92,255).
    static let glow = C(vkHex: "#7C5CFF")

    // Surfaces — Neural AI có bộ màu riêng (ai.css), còn lại paper/ink Tonal.
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

    // Text
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
    /// v4.8 a11y: nâng tương phản đạt AA (cũ #7C7768 / #8A8AA6 dưới 4.5:1).
    static var fgMuted: C {
      neural ? C(lightVK: C(vkHex: "#6C6C82"), darkVK: C(vkHex: "#8585A0"))
             : C(lightVK: C(vkHex: "#757058"), darkVK: C(vkHex: "#8A8578"))
    }
    static let fgInverse = C(lightVK: Palette.paper0, darkVK: Palette.ink600)

    // Borders
    static var border1: C {
      neural ? C(lightVK: C(vkHex: "#141432").opacity(0.07), darkVK: C(vkHex: "#FFFFFF").opacity(0.07))
             : C(lightVK: Palette.paper200, darkVK: C(vkHex: "#FFFFFF").opacity(0.08))
    }
    static var border2: C {
      neural ? C(lightVK: C(vkHex: "#141432").opacity(0.10), darkVK: C(vkHex: "#FFFFFF").opacity(0.11))
             : C(lightVK: Palette.paper300, darkVK: C(vkHex: "#FFFFFF").opacity(0.14))
    }

    // Semantic
    static let success = Palette.success
    static let warning = Palette.warning
    static let danger  = Palette.danger
    static let info    = Palette.info
    static let gold    = Palette.gold500
    static let ink200  = Palette.ink200

    // Soft fills (badge nền)
    static let successSoft = C(lightVK: C(vkHex: "#DCF3E7"), darkVK: Palette.success.opacity(0.18))
    static let warningSoft = C(lightVK: C(vkHex: "#FAF1D6"), darkVK: Palette.warning.opacity(0.18))
    static let dangerSoft  = C(lightVK: C(vkHex: "#FBE0E3"), darkVK: Palette.danger.opacity(0.18))
    static let infoSoft    = C(lightVK: C(vkHex: "#DDEBF9"), darkVK: Palette.info.opacity(0.18))

    // v4.8 a11y: CHỮ badge (đủ tương phản AA trên soft-fill). KHÔNG dùng màu
    // semantic base làm chữ trên nền soft của chính nó — chỉ dùng cho fill/viền/icon.
    static let successText = C(lightVK: C(vkHex: "#126B45"), darkVK: C(vkHex: "#7FD9AC"))
    static let warningText = C(lightVK: C(vkHex: "#7E5B07"), darkVK: Palette.gold300)
    static let dangerText  = C(lightVK: C(vkHex: "#8E1F2E"), darkVK: C(vkHex: "#F0909E"))
    static let infoText    = C(lightVK: C(vkHex: "#1A579E"), darkVK: C(vkHex: "#8FC1F3"))

    /// Màu icon trên tile — remap màu tối tĩnh (ink*) khi Glass/Neural để glyph không bị chìm.
    static func tileAccent(_ base: C) -> C {
      guard VK.Glass.isOn || VK.isNeural else { return base }
      guard let rgb = NSColor(base).usingColorSpace(.sRGB) else { return base }
      let lum = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
      if lum < 0.42 { return fg2 }
      return base
    }
  }

  // MARK: Radii (pt) — 2.16: nhân theo Defaults.themeRadius (sắc/vừa/tròn)
  enum Radius {
    private static var k: CGFloat { VK.theme.radius.scale }
    static var xs: CGFloat  { max(2, 4 * k) }
    static var sm: CGFloat  { max(3, 6 * k) }
    static var md: CGFloat  { max(4, 10 * k) }
    static var lg: CGFloat  { max(5, 14 * k) }
    static var xl: CGFloat  { max(7, 20 * k) }
    static var xxl: CGFloat { max(9, 28 * k) }
    static let pill: CGFloat = 999

    /// v4.8: bo góc tuỳ biến theo cùng hệ số "Sắc/Vừa/Tròn". Giữ nguyên giá trị
    /// gốc ở mức "Vừa" (k=1) nhưng vẫn co/giãn theo theme. Dùng cho các radius
    /// từng hard-code (menu/keycap/icon-tile/HUD) để "Tròn/Sắc" chi phối toàn hệ.
    static func scaled(_ base: CGFloat) -> CGFloat { max(2, base * k) }
  }

  // MARK: Density — 2.16: mật độ dòng menu cài đặt (gọn/vừa/thoáng)
  enum Density {
    static var rowV: CGFloat { VK.theme.density.rowPaddingV }
    static var sectionGap: CGFloat { VK.theme.density.sectionGap }
  }

  // MARK: Liquid Glass — 2.16
  enum Glass {
    typealias C = SwiftUI.Color
    static var isOn: Bool { Defaults[.uiTheme] == .glass }
    /// Màu panel kính, alpha theo độ trong (clarity): 0.80 - clarity*0.52.
    static func panel(dark: Bool) -> C {
      let a = max(0.28, 0.80 - VK.theme.clarity * 0.52)
      return dark ? C(.sRGB, red: 30/255, green: 27/255, blue: 33/255, opacity: a)
                  : C(.sRGB, red: 252/255, green: 250/255, blue: 247/255, opacity: a)
    }
    /// Màu card kính (nhạt hơn panel) — trắng mờ.
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

  // MARK: Tracking (letter-spacing, em) — v4.8. Dùng qua `.vkTracking(_:size:)`.
  enum Tracking {
    static let tight: CGFloat  = -0.02
    static let snug: CGFloat   = -0.01
    static let normal: CGFloat = 0
    static let wide: CGFloat   = 0.06
    static let wider: CGFloat  = 0.14
  }

  // MARK: Leading (line-height multiplier) — v4.8. Dùng qua `.vkLeading(_:size:)`.
  enum Leading {
    static let none: CGFloat    = 1.0
    static let tight: CGFloat   = 1.2
    static let snug: CGFloat    = 1.35
    static let normal: CGFloat  = 1.5
    static let relaxed: CGFloat = 1.6
  }

  // MARK: Typography (SF system — bám size/weight design tokens)
  enum TypeStyle {
    case h1, h2, h3, h4, body, bodyLg, small, micro, eyebrow, monoSm, monoMd
  }

  enum Font {
    /// Font sans của theme ở cỡ/đậm tuỳ ý — DÙNG THAY `.system(size:weight:)`
    /// trong các view redesign để lựa chọn "Phông chữ" có tác dụng thật.
    static func sans(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
      if let name = VK.theme.font.postScriptName {
        return .custom(name, size: size).weight(weight)
      }
      return .system(size: size, weight: weight)
    }

    /// 2.16: font sans đọc từ Defaults.themeFont (SF / Noto Sans / Carter One).
    /// Mono styles luôn giữ SF monospaced.
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
      if let name = VK.theme.font.postScriptName {
        return .custom(name, size: size).weight(weight)
      }
      return .system(size: size, weight: weight)
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

extension View {
  /// v4.8: letter-spacing theo token em (`VK.Tracking`) tại cỡ chữ.
  /// SwiftUI `.tracking` nhận points nên quy đổi `em * size`.
  func vkTracking(_ em: CGFloat, size: CGFloat) -> some View { self.tracking(em * size) }

  /// v4.8: line-height multiplier (`VK.Leading`) → `lineSpacing` xấp xỉ
  /// (line-height mặc định ~1.2·size nên phần thêm = (mult − 1.2)·size).
  func vkLeading(_ mult: CGFloat, size: CGFloat) -> some View {
    self.lineSpacing(max(0, (mult - 1.2) * size))
  }
}

// MARK: - Liquid Glass blur (behind-window VisualEffect)

/// Nền kính mờ (NSVisualEffectView). Dùng làm nền cửa sổ Settings khi theme = glass.
struct VKVisualEffect: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .underWindowBackground
  var blending: NSVisualEffectView.BlendingMode = .behindWindow
  func makeNSView(context: Context) -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.material = material
    v.blendingMode = blending
    v.state = .active
    return v
  }
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blending
  }
}

// MARK: - Card background (glass-aware)

extension View {
  /// Nền card/panel: theme Tonal → đặc (paper/ink); Liquid Glass → kính mờ
  /// trong suốt + viền specular. `corner` mặc định = VK.Radius.lg.
  @ViewBuilder
  func vkCard(corner: CGFloat? = nil) -> some View {
    modifier(VKCardModifier(corner: corner))
  }
}

private struct VKCardModifier: ViewModifier {
  let corner: CGFloat?
  @Environment(\.colorScheme) private var scheme
  func body(content: Content) -> some View {
    let r = corner ?? VK.Radius.lg
    let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
    if VK.Glass.isOn {
      content.background(
        shape.fill(VK.Glass.card(dark: scheme == .dark))
          .background(.ultraThinMaterial, in: shape)
          .overlay(shape.strokeBorder(VK.Glass.edgeLo, lineWidth: 1))
          .overlay(shape.strokeBorder(VK.Glass.edge.opacity(0.5), lineWidth: 0.5)
                    .blendMode(.screen))
      )
    } else {
      content.background(
        shape.fill(VK.Color.bgElevated)
          .overlay(shape.strokeBorder(VK.Color.border1, lineWidth: 1))
      )
    }
  }
}
