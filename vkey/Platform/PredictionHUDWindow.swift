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

  /// 2.0.2 (J1): chỉ hiển thị top-1 prediction. Multi-candidate UI đã bị
  /// xoá do digit selection (1/2/3) dễ nhầm với gõ số trong văn bản.
  func show(prediction: String) {
    guard !prediction.isEmpty else { hide(); return }
    hideTimer?.invalidate()

    // 1.9.1: đọc Defaults 1 lần ở show(), pass vào view qua init. Tránh
    // @Default trong View struct gây re-render → hosting view request
    // window resize → NSException crash (xảy ra ở v1.9.0).
    let fontSize = Self.clampedFontSize(Defaults[.predictionHUDFontSize])
    let backgroundStrength = Self.clampedBackgroundStrength(Defaults[.hudOpacityPercent])
    let contentSize = Self.contentSize(for: "→ \(prediction)   ⇥ Tab", fontSize: fontSize)
    let view = PredictionHUDView(
      prediction: prediction,
      fontSize: fontSize,
      backgroundStrength: backgroundStrength,
      contentSize: contentSize
    )
    let panel = ensurePanel()

    // 1.9.3: tạo NSHostingController mới mỗi lần show (match ToggleHUD pattern).
    // 1.9.6: giữ sizingOptions = [] để chặn SwiftUI tự propose resize window
    // trong borderless NSPanel. Size HUD được tính thủ công bên dưới nên không
    // phụ thuộc fittingSize và không còn bị invisible/size 0.
    let controller = NSHostingController(rootView: view)
    if #available(macOS 13.0, *) {
      controller.sizingOptions = []
    }
    hostingController = controller
    panel.contentViewController = controller

    // Không đọc fittingSize ở đây: với sizingOptions=[] nó có thể trả 0/tiny,
    // còn với preferredContentSize thì SwiftUI có thể tự đẩy resize lên window.
    controller.view.setFrameSize(contentSize)
    panel.setContentSize(contentSize)
    panel.alphaValue = 1

    // Position panel — re-align top theo logic cũ (HUD ở TRÊN caret).
    let originFrame = targetFrame(forContentSize: contentSize)
    panel.setFrameOrigin(originFrame.origin)
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

  nonisolated static func contentSize(for text: String, fontSize: Int) -> CGSize {
    let clampedSize = CGFloat(clampedFontSize(fontSize))
    let font = NSFont.systemFont(ofSize: clampedSize, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let measured = (text as NSString).boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes
    )

    let horizontalPadding: CGFloat = 32
    let verticalPadding: CGFloat = 20
    let shadowAllowance: CGFloat = 16
    return CGSize(
      width: max(160, ceil(measured.width + horizontalPadding + shadowAllowance)),
      height: max(36, ceil(measured.height + verticalPadding + shadowAllowance))
    )
  }

  // 2.0.2 (J1): xoá `candidatesContentSize(candidates:fontSize:)`. Multi-
  // candidate UI bỏ; chỉ dùng `contentSize(for:fontSize:)` cho top-1.

  nonisolated private static func clampedFontSize(_ value: Int) -> Int {
    max(12, min(24, value))
  }

  nonisolated private static func clampedBackgroundStrength(_ value: Int) -> Double {
    Double(max(30, min(100, value))) / 100.0
  }

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
  private func targetFrame(forContentSize contentSize: CGSize) -> NSRect {
    let width = contentSize.width
    let height = contentSize.height

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
    guard CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
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
    guard let pos = cgPoint(from: posValue),
          let size = cgSize(from: sizeValue)
    else { return nil }

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

    guard var range = cfRange(from: rangeValue),
          range.location >= 0
    else { return nil }
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

    return cgRect(from: boundsValue)
  }

  private func axValue(_ value: CFTypeRef?, expectedType: AXValueType) -> AXValue? {
    guard let value = value,
          CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    let axValue = value as! AXValue
    guard AXValueGetType(axValue) == expectedType else { return nil }
    return axValue
  }

  private func cgPoint(from value: CFTypeRef?) -> CGPoint? {
    guard let axValue = axValue(value, expectedType: .cgPoint) else { return nil }
    var point = CGPoint.zero
    guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
    return point
  }

  private func cgSize(from value: CFTypeRef?) -> CGSize? {
    guard let axValue = axValue(value, expectedType: .cgSize) else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
    return size
  }

  private func cgRect(from value: CFTypeRef?) -> CGRect? {
    guard let axValue = axValue(value, expectedType: .cgRect) else { return nil }
    var rect = CGRect.zero
    guard AXValueGetValue(axValue, .cgRect, &rect) else { return nil }
    return rect
  }

  private func cfRange(from value: CFTypeRef?) -> CFRange? {
    guard let axValue = axValue(value, expectedType: .cfRange) else { return nil }
    var range = CFRange(location: 0, length: 0)
    guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
    return range
  }
}

struct PredictionHUDView: View {
  /// 2.0.2 (J1): chỉ 1 prediction. Multi-candidate UI đã xoá.
  let prediction: String
  // 1.9.1: pass qua init thay vì @Default trong struct — tránh crash
  // NSHostingView khi Defaults change trigger re-render + animated resize.
  let fontSize: Int
  let backgroundStrength: Double
  let contentSize: CGSize
  @Environment(\.colorScheme) private var colorScheme

  init(prediction: String, fontSize: Int, backgroundStrength: Double, contentSize: CGSize) {
    self.prediction = prediction
    self.fontSize = fontSize
    self.backgroundStrength = backgroundStrength
    self.contentSize = contentSize
  }

  @Default(.uiTheme) private var uiTheme

  var body: some View {
    Group {
      if uiTheme == .tonal {
        tonalBody
      } else {
        classicBody
      }
    }
    .frame(width: contentSize.width, height: contentSize.height)
  }

  // MARK: - Classic (v2.0.2 look)

  private var classicBody: some View {
    Text("→ \(prediction)   ⇥ Tab")
      .font(.system(size: CGFloat(fontSize), weight: .semibold, design: .rounded))
      .foregroundStyle(.primary)
      .shadow(color: .black.opacity(0.15), radius: 0.5, x: 0, y: 0.5)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        Color.black.opacity(classicScrimOpacity),
        in: RoundedRectangle(cornerRadius: 16)
      )
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(Color.white.opacity(classicStrokeOpacity), lineWidth: 0.6)
      )
      .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
  }

  private var classicScrimOpacity: Double {
    let base = colorScheme == .dark ? 0.10 : 0.03
    let range = colorScheme == .dark ? 0.16 : 0.07
    return base + range * backgroundStrength
  }

  private var classicStrokeOpacity: Double {
    colorScheme == .dark ? 0.18 : 0.28
  }

  // MARK: - Tonal (v2.1.0+)

  private var tonalBody: some View {
    HStack(spacing: 6) {
      Text("→")
        .font(.system(size: CGFloat(fontSize), weight: .heavy, design: .rounded))
        .foregroundStyle(VKeyDesign.red300)
      Text(prediction)
        .font(.system(size: CGFloat(fontSize), weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
      Text("⇥ Tab")
        .font(.system(size: CGFloat(fontSize) * 0.78, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.62))
        .padding(.leading, 4)
    }
    .shadow(color: .black.opacity(0.25), radius: 0.5, x: 0, y: 0.5)
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(
      VKeyDesign.ink500.opacity(tonalScrimOpacity),
      in: RoundedRectangle(cornerRadius: 10)
    )
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
  }

  private var tonalScrimOpacity: Double {
    0.32 + 0.30 * backgroundStrength
  }
}
