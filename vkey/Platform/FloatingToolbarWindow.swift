//
//  FloatingToolbarWindow.swift
//  vkey
//
//  2.0 (A1): Floating toolbar nổi tại vị trí cursor — toggle VI/EN, đổi
//  kiểu gõ, mở Free Mark, Text Conversion Tools, Settings.
//
//  Cấu trúc theo PredictionHUDWindow.swift: NSPanel borderless +
//  NSHostingController + SwiftUI view. Mặt khác toolbar CÓ ignore mouse
//  events = false → user click được. Vị trí: cố gắng đặt dưới caret;
//  fallback giữa màn hình.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
final class FloatingToolbarWindow {
  static let shared = FloatingToolbarWindow()

  private var panel: NSPanel?
  private var hostingController: NSHostingController<FloatingToolbarView>?
  private var hideTimer: Timer?

  private init() {}

  // MARK: - Public API

  /// Toggle hiển thị (gọi từ KeyboardShortcuts handler trong AppDelegate).
  func toggle(appState: AppState) {
    if panel?.isVisible == true {
      hide()
    } else {
      show(appState: appState)
    }
  }

  func show(appState: AppState) {
    guard Defaults[.floatingToolbarEnabled] else { return }
    hideTimer?.invalidate()

    let theme = HUDTheme.current()
    let view = FloatingToolbarView(
      appState: appState,
      theme: theme,
      onClose: { [weak self] in
        Task { @MainActor in self?.hide() }
      }
    )
    let controller = NSHostingController(rootView: view)
    if #available(macOS 13.0, *) {
      controller.sizingOptions = []
    }
    hostingController = controller

    let panel = ensurePanel()
    panel.contentViewController = controller

    let fittingSize = controller.view.fittingSize
    let size = CGSize(
      width: max(280, fittingSize.width),
      height: max(56, fittingSize.height)
    )
    controller.view.setFrameSize(size)
    panel.setContentSize(size)

    panel.setFrameOrigin(targetOrigin(for: size))
    panel.alphaValue = 1
    panel.orderFrontRegardless()

    // Auto-hide sau 8 giây nếu user không tương tác (tránh kẹt UI).
    hideTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.hide() }
    }
  }

  func hide() {
    hideTimer?.invalidate()
    hideTimer = nil
    panel?.orderOut(nil)
  }

  // MARK: - Helpers

  private func ensurePanel() -> NSPanel {
    if let p = panel { return p }
    let p = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 300, height: 56),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    p.isFloatingPanel = true
    p.level = .floating
    p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    p.isOpaque = false
    p.backgroundColor = .clear
    p.hasShadow = false
    p.isMovable = true
    p.becomesKeyOnlyIfNeeded = true
    panel = p
    return p
  }

  /// Đặt toolbar gần caret. Fallback: giữa màn hình, hơi dưới center.
  private func targetOrigin(for size: CGSize) -> NSPoint {
    // PredictionHUDWindow đã có logic caret rect via AX. Reuse approach
    // đơn giản hoá: lấy mouse location (cursor) làm reference; trade-off
    // là khi user toggle bằng phím, mouse có thể ở xa caret. User có thể
    // drag panel (isMovable=true) để di chuyển.
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
      ?? NSScreen.main
      ?? NSScreen.screens.first
    guard let screen = screen else { return .zero }
    let x = max(
      screen.frame.minX + 8,
      min(mouse.x - size.width / 2, screen.frame.maxX - size.width - 8)
    )
    // Đặt phía dưới mouse 24 px (không che cursor).
    let y = max(
      screen.frame.minY + 8,
      min(mouse.y - size.height - 24, screen.frame.maxY - size.height - 8)
    )
    return NSPoint(x: x, y: y)
  }
}

// MARK: - SwiftUI View

struct FloatingToolbarView: View {
  @ObservedObject var appState: AppState
  let theme: HUDTheme
  let onClose: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 10) {
      // Toggle VI/EN
      Button {
        appState.setEnabled(set: !appState.enabled)
      } label: {
        Label(appState.enabled ? "VI" : "EN", systemImage: appState.enabled ? "character.bubble.fill" : "keyboard")
          .font(.system(size: 13, weight: .semibold, design: .rounded))
          .foregroundStyle(appState.enabled ? theme.resolvedAccentColor : Color.secondary)
      }
      .buttonStyle(.plain)
      .help("Bật/tắt gõ tiếng Việt")

      Divider().frame(height: 18)

      // Telex / VNI
      Picker("", selection: Binding(
        get: { appState.typingMethod },
        set: { appState.setTypingMethod(method: $0) }
      )) {
        ForEach(TypingMethods.allCases, id: \.self) { method in
          Text(method.rawValue).tag(method)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 110)

      Divider().frame(height: 18)

      // Quick toggles
      Toggle(isOn: Binding(
        get: { Defaults[.freeMarkModeEnabled] },
        set: { Defaults[.freeMarkModeEnabled] = $0 }
      )) {
        Image(systemName: "wand.and.stars")
          .font(.system(size: 12, weight: .semibold))
      }
      .toggleStyle(.button)
      .help("Đặt dấu tự do")

      Toggle(isOn: Binding(
        get: { Defaults[.autoCapitalizeEnabled] },
        set: { Defaults[.autoCapitalizeEnabled] = $0 }
      )) {
        Image(systemName: "textformat.size")
          .font(.system(size: 12, weight: .semibold))
      }
      .toggleStyle(.button)
      .help("Viết hoa đầu câu")

      Spacer(minLength: 4)

      Button {
        TextConversionService.shared.openMenu(near: nil)
      } label: {
        Image(systemName: "textformat")
          .font(.system(size: 13, weight: .semibold))
      }
      .buttonStyle(.plain)
      .help("Mở Text Tools")

      Button {
        onClose()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help("Đóng")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .hudThemeBackground(theme, cornerRadius: 14)
  }
}
