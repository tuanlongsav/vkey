//
//  HUDTheme.swift
//  vkey
//
//  2.0 (A3): Theme & glassmorphism cho HUD/Toolbar/Popup.
//
//  Đọc cài đặt từ Defaults và cung cấp:
//  - `material`: SwiftUI material cho background (clear/regular/thick/heavy)
//  - `scrimOpacity`: lớp đen overlay để tăng contrast text
//  - `accentColor`: màu nhấn tuỳ chọn (override accent mặc định macOS)
//  - `effectiveColorScheme`: ép light/dark hoặc theo system
//
//  Cập nhật từ ToggleHUDWindow, PredictionHUDWindow, FloatingToolbarWindow.
//

import AppKit
import Defaults
import SwiftUI

/// Cấu hình HUD theme — resolved từ user defaults tại thời điểm gọi.
/// Snapshot 1 lần để tránh re-render khi defaults thay đổi (giống pattern
/// PredictionHUDView 1.9.1+ — không dùng @Default trong struct).
struct HUDTheme {
  let style: HUDThemeStyle
  let blurIntensity: Int   // 0..100
  let accentColor: Color?  // nil = dùng default accent
  let baseOpacity: Double  // 0..1, từ hudOpacityPercent

  static func current() -> HUDTheme {
    HUDTheme(
      style: Defaults[.hudThemeStyle],
      blurIntensity: max(0, min(100, Defaults[.hudBlurIntensity])),
      accentColor: parseHex(Defaults[.hudAccentColorHex]),
      baseOpacity: Double(max(30, min(100, Defaults[.hudOpacityPercent]))) / 100.0
    )
  }

  /// Chuyển `blurIntensity` thành SwiftUI Material.
  /// 0..25  → ultraThinMaterial (gần trong suốt)
  /// 25..60 → thinMaterial
  /// 60..85 → regularMaterial
  /// 85..100→ thickMaterial
  /// Khi `style == .glass`, force lên thick để tối đa hiệu ứng kính.
  @available(macOS 12.0, *)
  var material: Material {
    if style == .glass {
      return .thickMaterial
    }
    switch blurIntensity {
    case ..<25: return .ultraThinMaterial
    case ..<60: return .thinMaterial
    case ..<85: return .regularMaterial
    default: return .thickMaterial
    }
  }

  /// Lớp scrim đen overlay — tăng contrast text khi nền sau editor sáng/tối lẫn lộn.
  /// Tính theo dark/light của hệ thống đã resolved + base opacity.
  func scrimOpacity(for colorScheme: ColorScheme) -> Double {
    let isDark = (resolvedScheme(systemScheme: colorScheme) == .dark)
    let base = isDark ? 0.10 : 0.03
    let range = isDark ? 0.16 : 0.07
    return base + range * baseOpacity
  }

  func strokeOpacity(for colorScheme: ColorScheme) -> Double {
    resolvedScheme(systemScheme: colorScheme) == .dark ? 0.18 : 0.28
  }

  /// Trả về colorScheme effective theo theme style. `.auto` → theo system.
  func resolvedScheme(systemScheme: ColorScheme) -> ColorScheme {
    switch style {
    case .auto, .glass: return systemScheme
    case .light: return .light
    case .dark: return .dark
    }
  }

  /// SwiftUI accent color — nếu user đã set hex hợp lệ, dùng nó; nếu không,
  /// trả về `.accentColor` mặc định macOS.
  var resolvedAccentColor: Color {
    accentColor ?? .accentColor
  }

  // MARK: - Helpers

  /// Parse hex string `#RRGGBB` hoặc `RRGGBB`. Trả về nil nếu format sai.
  static func parseHex(_ hex: String) -> Color? {
    var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("#") { trimmed.removeFirst() }
    guard trimmed.count == 6,
          let value = UInt32(trimmed, radix: 16)
    else { return nil }
    let r = Double((value >> 16) & 0xFF) / 255.0
    let g = Double((value >> 8) & 0xFF) / 255.0
    let b = Double(value & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
  }
}

/// 2.0 (A3): SwiftUI modifier áp dụng HUD theme background — dùng cho mọi
/// HUD/Toolbar/Popup để có style thống nhất.
struct HUDThemeBackground: ViewModifier {
  let theme: HUDTheme
  let cornerRadius: CGFloat
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .background(
        Color.black.opacity(theme.scrimOpacity(for: colorScheme)),
        in: RoundedRectangle(cornerRadius: cornerRadius)
      )
      .background(theme.material, in: RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .strokeBorder(
            Color.white.opacity(theme.strokeOpacity(for: colorScheme)),
            lineWidth: 0.6
          )
      )
      .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
      .preferredColorScheme(theme.style == .auto || theme.style == .glass ? nil : (theme.style == .dark ? .dark : .light))
  }
}

extension View {
  /// Áp dụng background HUD theme. 2.0 (A3).
  func hudThemeBackground(_ theme: HUDTheme, cornerRadius: CGFloat = 16) -> some View {
    modifier(HUDThemeBackground(theme: theme, cornerRadius: cornerRadius))
  }
}
