//
//  VKBackdrops.swift
//  vkey
//
//  Nền cửa sổ theo theme (`VKGlassBackdrop`, `VKNeuralBackdrop`) và swatch tròn
//  đại diện theme (`VKThemeSwatch`) dùng chung giữa Menu Bar & Settings.
//

import SwiftUI

/// Kính thật cho Liquid Glass: blur những gì nằm sau cửa sổ + lớp tint theo clarity.
struct VKGlassBackdrop: View {
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    ZStack {
      VKVisualEffect(material: .hudWindow, blending: .behindWindow)
      Rectangle().fill(VK.Glass.panel(dark: scheme == .dark))
    }
  }
}

/// Nền Neural AI: không gian tối/lavender + 4 đốm aurora blur mạnh theo glow slider.
struct VKNeuralBackdrop: View {
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let k = VK.glowK
    let dark = scheme == .dark
    ZStack {
      if dark {
        LinearGradient(
          colors: [Color(vkHex: "#0B0B14"), Color(vkHex: "#08080F"), Color(vkHex: "#060609")],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      } else {
        LinearGradient(
          colors: [Color(vkHex: "#F4F3FB"), Color(vkHex: "#ECECF6"), Color(vkHex: "#E6E8F4")],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      GeometryReader { geo in
        let w = geo.size.width, h = geo.size.height
        ZStack {
          Circle().fill(Color(vkHex: "#8B5CF6").opacity(0.42 * k))
            .frame(width: w * 0.55).blur(radius: 70)
            .position(x: w * 0.22, y: h * 0.24)
          Circle().fill(Color(vkHex: "#22D3EE").opacity(0.32 * k))
            .frame(width: w * 0.45).blur(radius: 70)
            .position(x: w * 0.80, y: h * 0.28)
          Circle().fill(Color(vkHex: "#EC4899").opacity(0.24 * k))
            .frame(width: w * 0.50).blur(radius: 80)
            .position(x: w * 0.62, y: h * 0.84)
          Circle().fill(Color(vkHex: "#6366F1").opacity(0.34 * k))
            .frame(width: w * 0.50).blur(radius: 80)
            .position(x: w * 0.16, y: h * 0.78)
        }
        .opacity(dark ? 0.78 : 0.9)
      }
    }
  }
}

/// Swatch tròn đại diện theme: Tonal (mực+đỏ), Glass (kính trắng mờ), Neural (gradient tím–cyan).
struct VKThemeSwatch: View {
  let theme: UITheme
  var size: CGFloat = 14

  var body: some View {
    switch theme {
    case .neural:
      Circle()
        .fill(LinearGradient(
          colors: [Color(vkHex: "#8B5CF6"), Color(vkHex: "#22D3EE")],
          startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(width: size, height: size)
    case .glass:
      Circle()
        .fill(Color.white.opacity(0.22))
        .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
        .frame(width: size, height: size)
    case .tonal:
      Circle()
        .fill(LinearGradient(
          colors: [VK.Palette.ink400, VK.Palette.red500],
          startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(width: size, height: size)
    }
  }
}
