//
//  ToggleHUDView.swift
//  vkey
//
//  SwiftUI View & ViewModel cho Toggle HUD (chuyển chế độ VI/EN).
//

import Defaults
import SwiftUI

final class ToggleHUDViewModel: ObservableObject {
  @Published var isEnabled: Bool = true
  @Published var backgroundStrength: Double = 0.75
  @Published var appeared: Bool = true
}

struct ToggleHUDView: View {
  @ObservedObject var viewModel: ToggleHUDViewModel
  @Default(.typingMethod) private var typingMethod
  @Default(.newStyleTonePlacement) private var newStyleTonePlacement
  @Default(.modifierOnlyToggleHotkey) private var modifierOnlyToggleHotkey
  @Default(.uiTheme) private var uiTheme

  var body: some View {
    applyThemeBackground(to: hudCore)
      .scaleEffect(viewModel.appeared ? 1 : 0.94)
      .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.isEnabled)
      .padding(HUDMetrics.shadowMargin)
  }

  private var hudCore: some View {
    HStack(alignment: .center, spacing: 14) {
      HUDFlag(viewModel.isEnabled)
        .contentTransition(.symbolEffect(.replace))

      VStack(alignment: .leading, spacing: 4) {
        Text(viewModel.isEnabled ? "Tiếng Việt" : "English")
          .font(Font(hudTitleNSFont(17) as CTFont))
          .foregroundStyle(titleColor)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)

        Text(subTitle)
          .font(.system(size: 12, weight: .regular))
          .foregroundStyle(subtitleColor)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
      }

      if !hotkeyGlyphs.isEmpty {
        HStack(spacing: 6) {
          ForEach(hotkeyGlyphs, id: \.self) { glyph in Keycap(glyph, size: .md) }
        }
      }
    }
    .padding(.vertical, 18)
    .padding(.horizontal, 24)
  }

  @ViewBuilder
  private func applyThemeBackground(to content: some View) -> some View {
    switch uiTheme {
    case .tonal:
      content.tonalScrimBackground(radius: 20, scrimOpacity: tonalScrimOpacity)
    case .glass:
      content.refractiveGlassBackground(radius: 20, scrimOpacity: tonalScrimOpacity)
    case .neural:
      content
        .background(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(vkHex: "#0F0F18").opacity(0.88)))
        .background(HUDBackdrop(cornerRadius: 20))
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(VK.Color.brandGradient, lineWidth: 1).opacity(0.65))
        .compositingGroup()
        .shadow(color: VK.Color.glow.opacity(0.45 * VK.glowK), radius: 26, x: 0, y: 10)
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 14)
    }
  }

  private var titleColor: Color {
    switch uiTheme {
    case .tonal:  return .white
    case .glass:  return .primary
    case .neural: return Color(vkHex: "#ECECF7")
    }
  }

  private var subtitleColor: Color {
    switch uiTheme {
    case .tonal:  return Color.white.opacity(0.65)
    case .glass:  return .secondary
    case .neural: return Color(vkHex: "#ECECF7").opacity(0.6)
    }
  }

  private var subTitle: String {
    if viewModel.isEnabled {
      let style = newStyleTonePlacement ? "Kiểu mới" : "Kiểu cũ"
      return "\(typingMethod.rawValue) · \(style)"
    } else {
      return "vkey tạm tắt"
    }
  }

  private var hotkeyGlyphs: [String] {
    let raw = modifierOnlyToggleHotkey
    guard raw != 0 else { return [] }
    return formatModifierMask(raw).map { String($0) }
  }

  private var tonalScrimOpacity: Double {
    0.32 + 0.30 * viewModel.backgroundStrength
  }
}
