//
//  PredictionHUDWindow.swift
//  vkey
//
//  HUD nổi hiển thị từ đoán tiếp theo (1.6.0+). Cấu trúc theo
//  `ToggleHUDWindow.swift` existing — NSPanel + SwiftUI hosting view
//  với `.ultraThinMaterial` glass background.
//
//  Vị trí: cố gắng đặt gần caret qua Accessibility API (focused element
//  position). Nếu AX fail (Electron / Java / Wine), fallback bottom-center.
//
//  Auto-dismiss sau 3 giây hoặc khi user gõ phím khác (`hide()` được
//  gọi explicit từ InputProcessor).
//

import AppKit
import SwiftUI

@MainActor
final class PredictionHUDWindow {
  static let shared = PredictionHUDWindow()

  private var panel: NSPanel?
  private var hostingView: NSHostingView<PredictionHUDView>?
  private var hideTimer: Timer?

  func show(prediction: String) {
    hideTimer?.invalidate()

    let text = "→ \(prediction)   ⇥ Tab"
    let view = PredictionHUDView(text: text)
    let panel = ensurePanel()

    if let hosting = hostingView {
      hosting.rootView = view
    } else {
      let hosting = NSHostingView(rootView: view)
      hostingView = hosting
      panel.contentView = hosting
    }

    panel.setFrame(targetFrame(forText: text), display: true, animate: false)
    panel.orderFrontRegardless()

    // Auto-dismiss sau 3 giây.
    hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.hide() }
    }
  }

  func hide() {
    hideTimer?.invalidate()
    hideTimer = nil
    panel?.orderOut(nil)
  }

  // MARK: - Internal

  private func ensurePanel() -> NSPanel {
    if let p = panel { return p }
    let p = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 36),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    p.isFloatingPanel = true
    p.level = .floating
    p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    p.backgroundColor = .clear
    p.hasShadow = false
    p.isMovable = false
    p.becomesKeyOnlyIfNeeded = true
    panel = p
    return p
  }

  /// Cố gắng đặt HUD ngay TRÊN dòng caret của focused text element qua AX.
  /// 1.7.7: đổi từ dưới (cũ) lên trên — user feedback rằng HUD dưới che cursor.
  /// Fallback: bottom-center của main screen.
  private func targetFrame(forText text: String) -> NSRect {
    let width = max(160, CGFloat(text.count) * 9 + 40)
    let height: CGFloat = 36

    if let caret = focusedElementCaretRect() {
      let screen = NSScreen.main?.frame ?? .zero
      // AX coordinates use top-down Y. Convert to AppKit (bottom-up):
      // HUD nằm TRÊN caret line: top edge của HUD ngay sát top của text
      // element (caret.minY trong AX = top edge), với 4pt margin.
      let axY = caret.minY  // top of caret element in AX (top-down)
      let appKitY = screen.height - axY + 4  // HUD bottom = AX top + margin
      return NSRect(
        x: max(8, min(caret.minX, screen.width - width - 8)),
        y: appKitY,
        width: width,
        height: height
      )
    }

    // Fallback: bottom-center của main screen.
    let screen = NSScreen.main?.visibleFrame ?? .zero
    return NSRect(
      x: screen.midX - width / 2,
      y: screen.minY + 80,
      width: width,
      height: height
    )
  }

  /// Lấy bounding rect của focused UI element qua AX. Trả nil nếu app
  /// không expose AX hoặc không có focused element.
  private func focusedElementCaretRect() -> CGRect? {
    let systemWide = AXUIElementCreateSystemWide()
    var focused: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(
      systemWide,
      kAXFocusedUIElementAttribute as CFString,
      &focused
    )
    guard err == .success, let element = focused else { return nil }
    // swiftlint:disable:next force_cast
    let axElement = element as! AXUIElement

    // Get position + size attributes.
    var posValue: CFTypeRef?
    var sizeValue: CFTypeRef?
    AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &posValue)
    AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &sizeValue)
    guard let posValue = posValue, let sizeValue = sizeValue else { return nil }

    var pos = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(posValue as! AXValue, .cgPoint, &pos)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

    return CGRect(origin: pos, size: size)
  }
}

struct PredictionHUDView: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 13, weight: .medium, design: .rounded))
      .foregroundStyle(.primary)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
      )
      .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
  }
}
