//
//  NoticeHUDWindow.swift
//  vkey
//
//  HUD thông báo ngắn giữa màn hình (cảnh báo, cập nhật hoàn tất…).
//  Backed by shared `FloatingHUDPanel` + `NoticeHUDView`.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
final class NoticeHUDWindow {
  static let shared = NoticeHUDWindow()

  enum Style {
    case warning
    case success
  }

  private let hudPanel = FloatingHUDPanel<NoticeHUDView>()

  private init() {}

  func show(
    message: String,
    title: String = "Cảnh báo",
    style: Style = .warning,
    duration: TimeInterval = 3.2
  ) {
    let backgroundStrength = FloatingHUDPanel<NoticeHUDView>.clampedBackgroundStrength(
      Defaults[.hudOpacityPercent]
    )
    let view = NoticeHUDView(
      title: title,
      message: message,
      style: style,
      backgroundStrength: backgroundStrength,
      uiTheme: Defaults[.uiTheme]
    )
    let contentSize = Self.contentSize(title: title, message: message)
    hudPanel.present(
      rootView: view,
      contentSize: contentSize,
      yOffset: -80,
      autoHideAfter: duration
    )
  }

  func hide() {
    hudPanel.hideImmediately()
  }

  nonisolated static func contentSize(title: String, message: String) -> CGSize {
    let titleFont = NSFont.systemFont(ofSize: 15, weight: .bold)
    let bodyFont = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
    let maxTextWidth: CGFloat = 300
    let titleSize = FloatingHUDPanel<NoticeHUDView>.measureText(
      title, font: titleFont, maxWidth: maxTextWidth)
    let bodySize = FloatingHUDPanel<NoticeHUDView>.measureText(
      message, font: bodyFont, maxWidth: maxTextWidth)
    let textWidth = max(titleSize.width, bodySize.width)
    let textHeight = titleSize.height + 6 + bodySize.height
    return CGSize(
      width: min(380, max(260, ceil(textWidth + 72))),
      height: max(64, ceil(textHeight + 38))
    )
  }
}
