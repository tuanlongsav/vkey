//
//  NoticeHUDView.swift
//  vkey
//
//  SwiftUI View & high-contrast palette cho Notice HUD (cảnh báo / cập nhật hoàn tất).
//

import SwiftUI

private struct NoticeHUDPalette {
  let accent: Color
  let accentDeep: Color
  let scrim: Color
  let scrimGlass: Color
  let titleText: Color
  let bodyText: Color
  let iconHalo: Color
  let iconName: String

  static let warning = NoticeHUDPalette(
    accent: Color(vkHex: "#FFB020"),
    accentDeep: Color(vkHex: "#E58A00"),
    scrim: Color(vkHex: "#1C1008").opacity(0.94),
    scrimGlass: Color(vkHex: "#241408").opacity(0.90),
    titleText: Color(vkHex: "#FFD878"),
    bodyText: Color(vkHex: "#FFF4E8"),
    iconHalo: Color(vkHex: "#FF9500").opacity(0.35),
    iconName: "exclamationmark.triangle.fill"
  )

  static let success = NoticeHUDPalette(
    accent: Color(vkHex: "#3DDC84"),
    accentDeep: Color(vkHex: "#22B86A"),
    scrim: Color(vkHex: "#081810").opacity(0.94),
    scrimGlass: Color(vkHex: "#0C2018").opacity(0.90),
    titleText: Color(vkHex: "#B8FFD8"),
    bodyText: Color(vkHex: "#E8FFF2"),
    iconHalo: Color(vkHex: "#34C759").opacity(0.35),
    iconName: "checkmark.circle.fill"
  )

  static func forStyle(_ style: NoticeHUDWindow.Style) -> NoticeHUDPalette {
    switch style {
    case .warning: return .warning
    case .success: return .success
    }
  }
}

struct NoticeHUDView: View {
  let title: String
  let message: String
  let style: NoticeHUDWindow.Style
  let backgroundStrength: Double
  let uiTheme: UITheme

  private var palette: NoticeHUDPalette { NoticeHUDPalette.forStyle(style) }
  private var scrimStrength: Double { 0.55 + 0.45 * backgroundStrength }

  var body: some View {
    Group {
      switch uiTheme {
      case .glass:  glassBody
      case .neural: neuralBody
      case .tonal:  tonalBody
      }
    }
    .padding(HUDMetrics.shadowMargin)
  }

  private var warningContent: some View {
    HStack(alignment: .top, spacing: 14) {
      ZStack {
        Circle()
          .fill(palette.iconHalo)
          .frame(width: 40, height: 40)
        Circle()
          .strokeBorder(palette.accent.opacity(0.55), lineWidth: 1.5)
          .frame(width: 40, height: 40)
        Image(systemName: palette.iconName)
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(
            LinearGradient(
              colors: [palette.accent, palette.accentDeep],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .shadow(color: palette.accent.opacity(0.6), radius: 4, y: 1)
      }
      .padding(.top, 1)

      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(VK.Font.hudDisplay(15, weight: .bold))
          .foregroundStyle(palette.titleText)
          .tracking(0.2)
        Text(message)
          .font(.system(size: 13.5, weight: .semibold, design: .rounded))
          .foregroundStyle(palette.bodyText)
          .multilineTextAlignment(.leading)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 18)
    .frame(maxWidth: 380)
  }

  private var tonalBody: some View {
    warningContent
      .background {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(palette.scrim.opacity(scrimStrength))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(palette.accent, lineWidth: 2)
      }
      .compositingGroup()
      .shadow(color: palette.accent.opacity(0.35), radius: 18, y: 0)
      .shadow(color: .black.opacity(0.42), radius: 20, y: 10)
  }

  private var glassBody: some View {
    warningContent
      .background {
        ZStack {
          HUDBackdrop(cornerRadius: 16)
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(palette.scrimGlass.opacity(scrimStrength))
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(palette.accent, lineWidth: 2.5)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
          .padding(1)
      }
      .compositingGroup()
      .shadow(color: palette.accent.opacity(0.50), radius: 22, y: 0)
      .shadow(color: .black.opacity(0.48), radius: 22, y: 12)
  }

  private var neuralBody: some View {
    warningContent
      .background {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(
            Color(vkHex: style == .success ? "#081810" : "#120A06")
              .opacity(0.55 + 0.37 * backgroundStrength))
      }
      .background { HUDBackdrop(cornerRadius: 16) }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [palette.accent, palette.accentDeep],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 2
          )
      }
      .compositingGroup()
      .shadow(color: palette.accent.opacity(0.55 * VK.glowK), radius: 24, y: 0)
      .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
  }
}
