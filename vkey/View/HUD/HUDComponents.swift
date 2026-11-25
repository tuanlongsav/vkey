//
//  HUDComponents.swift
//  vkey
//
//  Shared HUD primitives: `HUDMetrics`, `Keycap`, `HUDFlag`, and glass/tonal
//  background recipes (backed by unified `VK` tokens & `HUDBackdrop`).
//

import AppKit
import SwiftUI

// MARK: - HUD metrics

enum HUDMetrics {
  /// Đệm trong suốt quanh content của HUD để shadow lớn không bị cắt vuông theo bounds NSPanel.
  static let shadowMargin: CGFloat = 64
}

// MARK: - Keycap

struct Keycap: View {
  enum Size {
    case md

    var height: CGFloat { 28 }
    var minWidth: CGFloat { 28 }
    var horizontalPadding: CGFloat { 8 }
    var fontSize: CGFloat { 12 }
    var radius: CGFloat { 8 }
  }

  let label: String
  let size: Size

  init(_ label: String, size: Size = .md) {
    self.label = label
    self.size = size
  }

  var body: some View {
    Text(label)
      .font(.system(size: size.fontSize, weight: .semibold))
      .foregroundStyle(Color.white.opacity(0.92))
      .frame(minWidth: size.minWidth, minHeight: size.height)
      .padding(.horizontal, size.horizontalPadding)
      .background(
        LinearGradient(
          colors: [
            Color.white.opacity(0.28),
            Color.white.opacity(0.07),
          ],
          startPoint: .top, endPoint: .bottom
        ),
        in: RoundedRectangle(cornerRadius: size.radius, style: .continuous)
      )
      .background(
        Color.black.opacity(0.18),
        in: RoundedRectangle(cornerRadius: size.radius, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: size.radius, style: .continuous)
          .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
      )
      .compositingGroup()
      .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 1)
  }
}

// MARK: - HUDFlag

struct HUDFlag: View {
  let isVietnamese: Bool

  init(_ isVietnamese: Bool) {
    self.isVietnamese = isVietnamese
  }

  var body: some View {
    Image(isVietnamese ? "vn-flag" : "us-flag")
      .resizable()
      .interpolation(.high)
      .aspectRatio(contentMode: .fill)
      .frame(width: 48, height: 36)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        LinearGradient(
          colors: [Color.white.opacity(0.40), Color.white.opacity(0)],
          startPoint: .top, endPoint: .bottom
        )
        .frame(height: 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .allowsHitTesting(false)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
      )
      .compositingGroup()
      .shadow(color: Color.black.opacity(0.30), radius: 8, x: 0, y: 2)
  }
}

// MARK: - Background modifiers

extension View {
  func refractiveGlassBackground(radius: CGFloat, scrimOpacity: Double) -> some View {
    self.modifier(RefractiveGlassBackground(radius: radius, scrimOpacity: scrimOpacity))
  }

  func tonalScrimBackground(radius: CGFloat, scrimOpacity: Double) -> some View {
    self.modifier(TonalScrimBackground(radius: radius, scrimOpacity: scrimOpacity))
  }
}

private struct RefractiveGlassBackground: ViewModifier {
  let radius: CGFloat
  let scrimOpacity: Double

  func body(content: Content) -> some View {
    content
      .background(
        ZStack {
          RadialGradient(
            colors: [
              VK.Palette.red500.opacity(VK.HUD.refractiveStrength * 0.6),
              .clear,
            ],
            center: .bottomLeading, startRadius: 0, endRadius: 160
          )
          RadialGradient(
            colors: [
              VK.Palette.info.opacity(0.06),
              .clear,
            ],
            center: .topTrailing, startRadius: 0, endRadius: 160
          )
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
      )
      .background(
        ZStack {
          LinearGradient(
            colors: [
              Color.white.opacity(0.16),
              Color.white.opacity(0.02),
              Color.black.opacity(0.18),
            ],
            startPoint: .top, endPoint: .bottom
          )
          RadialGradient(
            colors: [Color.white.opacity(0.28), .clear],
            center: .top, startRadius: 0, endRadius: 200
          )
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
      )
      .background(
        VK.HUD.glassScrim.opacity(scrimOpacity),
        in: RoundedRectangle(cornerRadius: radius, style: .continuous)
      )
      .background(HUDBackdrop(cornerRadius: radius))
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.18),
                Color.white.opacity(0.06),
              ],
              startPoint: .top, endPoint: .bottom
            ),
            lineWidth: 1.2
          )
      )
      .compositingGroup()
      .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 12)
      .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
  }
}

private struct TonalScrimBackground: ViewModifier {
  let radius: CGFloat
  let scrimOpacity: Double

  func body(content: Content) -> some View {
    content
      .background(
        LinearGradient(
          colors: [
            Color.white.opacity(0.06),
            Color.white.opacity(0.0),
          ],
          startPoint: .top, endPoint: .center
        )
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
      )
      .background(
        VK.Palette.ink500.opacity(scrimOpacity),
        in: RoundedRectangle(cornerRadius: radius, style: .continuous)
      )
      .background(HUDBackdrop(cornerRadius: radius))
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
      )
      .compositingGroup()
      .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
  }
}
