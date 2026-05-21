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
import Defaults
import SwiftUI

@MainActor
final class PredictionHUDWindow {
  static let shared = PredictionHUDWindow()

  private var panel: NSPanel?
  // 1.9.3: chuyển từ NSHostingView sang NSHostingController. NSHostingView
  // (direct) gửi window constraint update requests qua updateWindowContentSizeExtrema
  // → trong NSPanel borderless không có constraint pipeline đầy đủ → NSException
  // → SIGABRT/SIGTRAP. NSHostingController không tự đẩy constraints lên window,
  // và macOS 13+ sizingOptions=[] disable automatic sizing hoàn toàn.
  // Pattern match ToggleHUDWindow (đã ổn định không crash).
  private var hostingController: NSHostingController<PredictionHUDView>?
  private var hideTimer: Timer?

  // 1.8.2: defensive cleanup — singleton thực chất không bao giờ release,
  // nhưng nếu future refactor đổi sang non-singleton, đảm bảo timer không
  // fire vào freed memory.
  deinit {
    hideTimer?.invalidate()
    hideTimer = nil
    hostingController = nil
  }

  func show(prediction: String) {
    hideTimer?.invalidate()

    let text = "→ \(prediction)   ⇥ Tab"
    // 1.9.1: đọc Defaults 1 lần ở show(), pass vào view qua init. Tránh
    // @Default trong View struct gây re-render → hosting view request
    // window resize → NSException crash (xảy ra ở v1.9.0).
    let fontSize = max(10, min(20, Defaults[.predictionHUDFontSize]))
    let opacityPct = max(50, min(100, Defaults[.hudOpacityPercent]))
    let view = PredictionHUDView(
      text: text,
      fontSize: fontSize,
      opacity: Double(opacityPct) / 100.0
    )
    let panel = ensurePanel()

    // 1.9.3: tạo NSHostingController mới mỗi lần show (match ToggleHUD pattern).
    // sizingOptions = [] để controller KHÔNG tự propose window size → fix crash
    // NSHostingView.updateWindowContentSizeExtremaIfNecessary trong borderless
    // NSPanel.
    let controller = NSHostingController(rootView: view)
    if #available(macOS 13.0, *) {
      controller.sizingOptions = []
    }
    hostingController = controller
    panel.contentViewController = controller

    // Lấy fittingSize SAU khi controller attached vào panel.
    let fitSize = controller.view.fittingSize
    panel.setContentSize(fitSize)

    // Position panel — re-align top theo logic cũ (HUD ở TRÊN caret).
    let originFrame = targetFrame(forText: text)
    let actualOrigin = NSPoint(
      x: originFrame.origin.x,
      y: originFrame.origin.y + originFrame.height - fitSize.height
    )
    panel.setFrameOrigin(actualOrigin)
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
    // 1.9.3: thêm `.fullSizeContentView` cho NSHostingController fill panel.
    let p = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 36),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    p.isFloatingPanel = true
    p.level = .floating
    p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    // 1.9.4: bổ sung theo Apple docs cho transparent window:
    //   window.isOpaque = false
    //   window.backgroundColor = .clear
    // PredictionHUDWindow trước v1.9.4 thiếu `isOpaque = false` → nền không
    // trong suốt hẳn dù SwiftUI dùng .ultraThinMaterial.
    p.isOpaque = false
    p.backgroundColor = .clear
    p.hasShadow = false  // SwiftUI vẽ shadow riêng (.shadow modifier)
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

      // 1.8.1: offset = N dòng văn bản (user-configurable trong Settings).
      // lineHeight ước lượng từ caret.height (AX parametric trả height của
      // 1 character ≈ line height). Floor 16px nếu API trả 0/giá trị bất
      // thường. Default N = 4 dòng.
      let lineHeight = max(caret.height, 16)
      let offsetLines = CGFloat(max(1, min(10, Defaults[.predictionHUDLineOffset])))
      let separation = lineHeight * offsetLines

      // Default: HUD trên caret line, cách `separation` px.
      let axTopY = caret.minY
      var hudCocoaBottomY = mainHeight - axTopY + separation - height

      // Flip xuống dưới nếu HUD top edge vượt screen.maxY.
      let hudCocoaTopY = hudCocoaBottomY + height
      if hudCocoaTopY > screen.frame.maxY - 8 {
        let axBottomY = caret.maxY
        hudCocoaBottomY = mainHeight - axBottomY - separation - height
      }

      // Clamp để HUD không out-of-bounds (vd offset lớn + caret cuối screen).
      hudCocoaBottomY = max(
        screen.frame.minY + 8,
        min(hudCocoaBottomY, screen.frame.maxY - height - 8)
      )

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
  // 1.9.1: pass qua init thay vì @Default trong struct — tránh crash
  // NSHostingView khi Defaults change trigger re-render + animated resize.
  let fontSize: Int
  let opacity: Double

  var body: some View {
    Text(text)
      // 1.9.4: font weight medium → semibold để chữ đậm rõ trên material
      // background. Default size 16 (thay 13). User feedback "chữ quá bé,
      // không rõ".
      .font(.system(size: CGFloat(fontSize), weight: .semibold, design: .rounded))
      .foregroundStyle(.primary)
      // 1.9.4: thêm subtle text shadow giúp đọc trên material blur — tăng
      // contrast khi nền sau editor sáng/tối lẫn lộn.
      .shadow(color: .black.opacity(0.15), radius: 0.5, x: 0, y: 0.5)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.6)
      )
      .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
      .opacity(opacity)
  }
}
