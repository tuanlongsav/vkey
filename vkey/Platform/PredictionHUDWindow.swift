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

  /// Cố gắng đặt HUD sát dòng caret của focused text element.
  /// 1.7.7: HUD ở TRÊN dòng caret (đổi từ dưới, đỡ che cursor).
  /// 1.7.9: dùng AX parametric API để lấy caret bounds CHÍNH XÁC
  /// (thay vì element bounds toàn editor như cũ — multi-line editor caret
  /// ở dòng 5/10 nay đặt đúng dòng đó). Flip xuống dưới nếu HUD vượt top
  /// screen; tự detect screen chứa caret cho multi-display.
  /// Fallback: bottom-center của main screen.
  private func targetFrame(forText text: String) -> NSRect {
    let width = max(160, CGFloat(text.count) * 9 + 40)
    let height: CGFloat = 36

    if let caret = focusedElementCaretRect() {
      // Tìm screen chứa caret (multi-display). AX dùng global top-down,
      // gốc 0,0 ở top-left của main display. NSScreen.frame dùng bottom-up,
      // gốc 0,0 ở bottom-left của main display.
      let mainHeight = NSScreen.main?.frame.height ?? 0
      let cocoaCaretPoint = CGPoint(
        x: caret.midX,
        y: mainHeight - caret.midY
      )
      let targetScreen = NSScreen.screens.first { screen in
        screen.frame.contains(cocoaCaretPoint)
      } ?? NSScreen.main ?? NSScreen.screens.first
      guard let screen = targetScreen else {
        return fallbackFrame(width: width, height: height)
      }

      // Default: HUD trên caret line. axY = caret.minY là top của caret
      // trong AX. Cocoa Y của top-of-HUD = mainHeight - axY - 4.
      // → bottom-of-HUD = mainHeight - axY - 4. NSRect.y là bottom-y.
      // Vì HUD nằm TRÊN caret: HUD top = AX caret top - margin.
      let axTopY = caret.minY
      var hudCocoaBottomY = mainHeight - axTopY + 4 - height
      // → NSRect.y = hudCocoaBottomY (bottom-y of HUD).
      // Wait — đơn giản hoá: NSRect.y là Cocoa y của bottom edge của HUD.
      // Muốn HUD top edge ở mainHeight - axTopY + 4 (Cocoa) =>
      //   bottomY = (mainHeight - axTopY + 4) - height.

      // Flip xuống dưới nếu HUD top edge vượt screen.maxY.
      let hudCocoaTopY = hudCocoaBottomY + height
      if hudCocoaTopY > screen.frame.maxY {
        // Đặt HUD dưới caret: HUD top = mainHeight - axBottomY - 4.
        let axBottomY = caret.maxY
        hudCocoaBottomY = mainHeight - axBottomY - 4 - height
      }

      let x = max(
        screen.frame.minX + 8,
        min(caret.minX, screen.frame.maxX - width - 8)
      )
      return NSRect(x: x, y: hudCocoaBottomY, width: width, height: height)
    }

    return fallbackFrame(width: width, height: height)
  }

  private func fallbackFrame(width: CGFloat, height: CGFloat) -> NSRect {
    let screen = NSScreen.main?.visibleFrame ?? .zero
    return NSRect(
      x: screen.midX - width / 2,
      y: screen.minY + 80,
      width: width,
      height: height
    )
  }

  /// Lấy caret bounds CHÍNH XÁC qua AX parametric API.
  /// 1.7.9: dùng kAXSelectedTextRangeAttribute + kAXBoundsForRangeParameterizedAttribute
  /// thay vì kAXPositionAttribute + kAXSizeAttribute (bounds toàn element).
  /// Fallback: element bounds (cũ) nếu parametric API không support.
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

    // 1.7.9: thử parametric API trước. App như TextEdit, VS Code, Safari
    // support → lấy được pixel-level caret rect.
    if let caretRect = parametricCaretRect(axElement: axElement),
       caretRect.width > 0 || caretRect.height > 0 {
      return caretRect
    }

    // Fallback: element bounds (cũ — multi-line editor có thể sai).
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

  /// 1.7.9: caret bounds chính xác qua AX parametric.
  /// - kAXSelectedTextRangeAttribute → CFRange của selection (length 0 nếu
  ///   chỉ caret thuần).
  /// - kAXBoundsForRangeParameterizedAttribute(range) → CGRect bounds
  ///   pixel của range đó. Range len 0 → trả về rect width 0 ở vị trí caret;
  ///   ta force length=1 để lấy bounds của ký tự kế caret.
  private func parametricCaretRect(axElement: AXUIElement) -> CGRect? {
    var rangeRef: CFTypeRef?
    let rangeErr = AXUIElementCopyAttributeValue(
      axElement,
      kAXSelectedTextRangeAttribute as CFString,
      &rangeRef
    )
    guard rangeErr == .success, let rangeValue = rangeRef else { return nil }

    var range = CFRange(location: 0, length: 0)
    AXValueGetValue(rangeValue as! AXValue, .cfRange, &range)
    if range.length == 0 {
      range.length = 1  // ép lấy bounds của 1 char để parametric API trả về rect non-zero
    }

    guard let rangeAXValue = AXValueCreate(.cfRange, &range) else { return nil }
    var boundsRef: CFTypeRef?
    let boundsErr = AXUIElementCopyParameterizedAttributeValue(
      axElement,
      kAXBoundsForRangeParameterizedAttribute as CFString,
      rangeAXValue,
      &boundsRef
    )
    guard boundsErr == .success, let boundsValue = boundsRef else { return nil }

    var rect = CGRect.zero
    AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect)
    return rect
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
