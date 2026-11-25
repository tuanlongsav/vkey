//
//  ToggleHUDWindow.swift
//  vkey
//
//  HUD overlay shown when the input mode toggles between VI and EN.
//  Backed by shared `FloatingHUDPanel` + `ToggleHUDView`.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
final class ToggleHUDWindow {
  static let shared = ToggleHUDWindow()

  private let hudPanel = FloatingHUDPanel<ToggleHUDView>()
  private let viewModel = ToggleHUDViewModel()

  private init() {}

  /// Hiển thị HUD thông báo trạng thái bật/tắt Tiếng Việt.
  func show(isEnabled: Bool, duration: TimeInterval = 1.0) {
    guard Defaults[.hudEnabled] else { return }

    viewModel.isEnabled = isEnabled
    viewModel.backgroundStrength = FloatingHUDPanel<ToggleHUDView>.clampedBackgroundStrength(
      Defaults[.hudOpacityPercent]
    )
    viewModel.appeared = false

    let contentSize = Self.contentSize(
      theme: Defaults[.uiTheme],
      typingMethod: Defaults[.typingMethod],
      newStyleTonePlacement: Defaults[.newStyleTonePlacement],
      modifierHotkey: Defaults[.modifierOnlyToggleHotkey]
    )

    hudPanel.present(
      rootView: ToggleHUDView(viewModel: viewModel),
      contentSize: contentSize,
      yOffset: -120,
      fadeInDuration: 0.12,
      autoHideAfter: duration,
      fadeOutDuration: 0.25
    )

    DispatchQueue.main.async { [viewModel] in
      withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
        viewModel.appeared = true
      }
    }
  }

  /// Ẩn ngay (marketing export — bỏ animation).
  func hideImmediately() {
    hudPanel.hideImmediately()
  }

  /// Đo kích thước thủ công — dùng max(VI, EN) để toggle không lệch.
  nonisolated static func contentSize(
    theme: UITheme,
    typingMethod: TypingMethods,
    newStyleTonePlacement: Bool,
    modifierHotkey: Int
  ) -> CGSize {
    _ = theme
    let hotkeyGlyphs = modifierHotkey != 0 ? formatModifierMask(modifierHotkey).map { String($0) } : []
    let keycapRowWidth: CGFloat = hotkeyGlyphs.isEmpty
      ? 0
      : CGFloat(hotkeyGlyphs.count) * 44 + CGFloat(hotkeyGlyphs.count - 1) * 6

    let titleFont = hudTitleNSFont(17)
    let subtitleFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    let viSubtitle = "\(typingMethod.rawValue) · \(newStyleTonePlacement ? "Kiểu mới" : "Kiểu cũ")"
    let enSubtitle = "vkey tạm tắt"

    let textColumnWidth = max(
      FloatingHUDPanel<ToggleHUDView>.measureText("Tiếng Việt", font: titleFont).width,
      FloatingHUDPanel<ToggleHUDView>.measureText("English", font: titleFont).width,
      FloatingHUDPanel<ToggleHUDView>.measureText(viSubtitle, font: subtitleFont).width,
      FloatingHUDPanel<ToggleHUDView>.measureText(enSubtitle, font: subtitleFont).width
    )
    let flagWidth: CGFloat = 48
    let spacing: CGFloat = 14
    let innerWidth = flagWidth + spacing + textColumnWidth
      + (keycapRowWidth > 0 ? spacing + keycapRowWidth : 0)
    let titleHeight = FloatingHUDPanel<ToggleHUDView>.measureText("Tiếng Việt", font: titleFont).height
    let subtitleHeight = FloatingHUDPanel<ToggleHUDView>.measureText(viSubtitle, font: subtitleFont).height
    let innerHeight = max(36, titleHeight + 4 + subtitleHeight)
    return CGSize(
      width: ceil(innerWidth + 48 + 8),
      height: ceil(innerHeight + 36)
    )
  }
}
