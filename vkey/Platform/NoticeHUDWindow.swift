//
//  NoticeHUDWindow.swift
//  vkey
//
//  HUD thông báo ngắn giữa màn hình (cảnh báo clipboard, v.v.).
//  Luôn dùng palette cảnh báo đậm — đọc được kể cả theme Liquid Glass.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
final class NoticeHUDWindow {
  static let shared = NoticeHUDWindow()

  private var panel: NSPanel?
  private var hostingController: NSHostingController<NoticeHUDView>?
  private var hideTimer: Timer?

  private init() {}

  func show(
    message: String,
    title: String = "Cảnh báo",
    duration: TimeInterval = 3.2
  ) {
    hideTimer?.invalidate()

    let backgroundStrength = Double(max(30, min(100, Defaults[.hudOpacityPercent]))) / 100.0
    let view = NoticeHUDView(
      title: title,
      message: message,
      backgroundStrength: backgroundStrength
    )
    let contentSize = Self.contentSize(title: title, message: message)
    let panel = ensurePanel()

    let controller = NSHostingController(rootView: view)
    if #available(macOS 13.0, *) {
      controller.sizingOptions = []
    }
    controller.view.wantsLayer = true
    controller.view.layer?.backgroundColor = NSColor.clear.cgColor
    hostingController = controller
    panel.contentViewController = controller

    let margin = HUDMetrics.shadowMargin
    let windowSize = CGSize(
      width: contentSize.width + margin * 2,
      height: contentSize.height + margin * 2
    )
    controller.view.setFrameSize(windowSize)
    panel.setContentSize(windowSize)
    panel.alphaValue = 1

    let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
    if let screen {
      let frame = screen.visibleFrame
      panel.setFrameOrigin(NSPoint(
        x: frame.midX - windowSize.width / 2,
        y: frame.midY - windowSize.height / 2 - 80
      ))
    }
    panel.orderFrontRegardless()

    hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.hide() }
    }
  }

  func hide() {
    hideTimer?.invalidate()
    hideTimer = nil
    panel?.orderOut(nil)
  }

  nonisolated static func contentSize(title: String, message: String) -> CGSize {
    let titleFont = NSFont.systemFont(ofSize: 15, weight: .bold)
    let bodyFont = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
    let maxTextWidth: CGFloat = 300
    let titleRect = (title as NSString).boundingRect(
      with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: titleFont]
    )
    let bodyRect = (message as NSString).boundingRect(
      with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: bodyFont]
    )
    let textWidth = max(titleRect.width, bodyRect.width)
    let textHeight = titleRect.height + 6 + bodyRect.height
    return CGSize(
      width: min(380, max(260, ceil(textWidth + 72))),
      height: max(64, ceil(textHeight + 38))
    )
  }

  private func ensurePanel() -> NSPanel {
    if let p = panel { return p }
    let p = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 280, height: 64),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    p.isFloatingPanel = true
    p.level = .popUpMenu
    p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    p.isOpaque = false
    p.backgroundColor = .clear
    p.hasShadow = false
    p.ignoresMouseEvents = true
    p.isReleasedWhenClosed = false
    panel = p
    return p
  }
}

// MARK: - Warning palette (theme-independent, high contrast)

private enum NoticeHUDPalette {
  static let amber = Color(vkHex: "#FFB020")
  static let amberDeep = Color(vkHex: "#E58A00")
  static let scrim = Color(vkHex: "#1C1008").opacity(0.94)
  static let scrimGlass = Color(vkHex: "#241408").opacity(0.90)
  static let titleText = Color(vkHex: "#FFD878")
  static let bodyText = Color(vkHex: "#FFF4E8")
  static let iconHalo = Color(vkHex: "#FF9500").opacity(0.35)
}

private struct NoticeHUDView: View {
  let title: String
  let message: String
  let backgroundStrength: Double

  @Default(.uiTheme) private var uiTheme

  /// Đồng bộ với setting độ mờ HUD — nền cảnh báo vẫn đủ tương phản ở mọi mức.
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
          .fill(NoticeHUDPalette.iconHalo)
          .frame(width: 40, height: 40)
        Circle()
          .strokeBorder(NoticeHUDPalette.amber.opacity(0.55), lineWidth: 1.5)
          .frame(width: 40, height: 40)
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(
            LinearGradient(
              colors: [NoticeHUDPalette.amber, NoticeHUDPalette.amberDeep],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .shadow(color: NoticeHUDPalette.amber.opacity(0.6), radius: 4, y: 1)
      }
      .padding(.top, 1)

      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(VKeyDesign.display(15, weight: .bold))
          .foregroundStyle(NoticeHUDPalette.titleText)
          .tracking(0.2)
        Text(message)
          .font(.system(size: 13.5, weight: .semibold, design: .rounded))
          .foregroundStyle(NoticeHUDPalette.bodyText)
          .multilineTextAlignment(.leading)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 18)
    .frame(maxWidth: 380)
  }

  // MARK: - Tonal — nền nâu đậm + viền amber

  private var tonalBody: some View {
    warningContent
      .background {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(NoticeHUDPalette.scrim.opacity(scrimStrength))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(NoticeHUDPalette.amber, lineWidth: 2)
      }
      .compositingGroup()
      .shadow(color: NoticeHUDPalette.amber.opacity(0.35), radius: 18, y: 0)
      .shadow(color: .black.opacity(0.42), radius: 20, y: 10)
  }

  // MARK: - Liquid Glass — lớp đục phủ lên blur để chữ không chìm

  private var glassBody: some View {
    warningContent
      .background {
        ZStack {
          HUDBackdrop(cornerRadius: 16)
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(NoticeHUDPalette.scrimGlass.opacity(scrimStrength))
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(NoticeHUDPalette.amber, lineWidth: 2.5)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
          .padding(1)
      }
      .compositingGroup()
      .shadow(color: NoticeHUDPalette.amber.opacity(0.50), radius: 22, y: 0)
      .shadow(color: .black.opacity(0.48), radius: 22, y: 12)
  }

  // MARK: - Neural — obsidian + viền/viền glow amber

  private var neuralBody: some View {
    warningContent
      .background {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color(vkHex: "#120A06").opacity(0.55 + 0.37 * backgroundStrength))
      }
      .background { HUDBackdrop(cornerRadius: 16) }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [NoticeHUDPalette.amber, NoticeHUDPalette.amberDeep],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 2
          )
      }
      .compositingGroup()
      .shadow(color: NoticeHUDPalette.amber.opacity(0.55 * VK.glowK), radius: 24, y: 0)
      .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
  }
}
