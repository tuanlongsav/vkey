//
//  PredictionHUDWindow.swift
//  vkey
//
//  HUD nổi hiển thị từ đoán tiếp theo (1.6.0+).
//
//  v2.4.0 FIX "khoanh vuông mờ":
//  - Window = contentSize + 2×HUDMetrics.predictionShadowMargin — shadow
//    không còn bị cắt phẳng theo mép cửa sổ (shadowAllowance 16pt cũ quá
//    nhỏ so với shadow radius 10–14 + glow Neural radius 14).
//  - Blur nền dùng HUDBackdrop (mask đúng hình) thay .ultraThinMaterial.
//  - ignoresMouseEvents = true — panel to hơn không được chặn click.
//  - Origin bù trừ phần đệm để vị trí THỊ GIÁC của HUD không đổi.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
final class PredictionHUDWindow {
  static let shared = PredictionHUDWindow()

  private var panel: NSPanel?
  private var hostingController: NSHostingController<PredictionHUDView>?
  private var hideTimer: Timer?

  deinit {
    hideTimer?.invalidate()
    hideTimer = nil
    hostingController = nil
  }

  /// Chỉ hiển thị top-1 prediction.
  func show(prediction: String) {
    guard !prediction.isEmpty else { hide(); return }
    hideTimer?.invalidate()

    let fontSize = Self.clampedFontSize(Defaults[.predictionHUDFontSize])
    let backgroundStrength = Self.clampedBackgroundStrength(Defaults[.hudOpacityPercent])
    // contentSize = kích thước THỊ GIÁC của viên HUD (không gồm đệm shadow).
    let contentSize = Self.contentSize(for: "→ \(prediction) ·", fontSize: fontSize)
    let view = PredictionHUDView(
      prediction: prediction,
      fontSize: fontSize,
      backgroundStrength: backgroundStrength,
      contentSize: contentSize
    )
    let panel = ensurePanel()

    let controller = NSHostingController(rootView: view)
    if #available(macOS 13.0, *) {
      controller.sizingOptions = []
    }
    controller.view.wantsLayer = true
    controller.view.layer?.backgroundColor = NSColor.clear.cgColor
    hostingController = controller
    panel.contentViewController = controller

    // v2.4.0: window = content + đệm shadow mỗi phía.
    let margin = HUDMetrics.predictionShadowMargin
    let windowSize = CGSize(
      width: contentSize.width + margin * 2,
      height: contentSize.height + margin * 2
    )
    controller.view.setFrameSize(windowSize)
    panel.setContentSize(windowSize)
    panel.alphaValue = 1

    // Position theo kích thước THỊ GIÁC, rồi bù trừ đệm.
    let originFrame = targetFrame(forContentSize: contentSize)
    panel.setFrameOrigin(NSPoint(
      x: originFrame.origin.x - margin,
      y: originFrame.origin.y - margin
    ))
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
    let verticalPadding: CGFloat = 22
    // v2.4.0: bỏ shadowAllowance — đệm shadow giờ nằm NGOÀI contentSize
    // (HUDMetrics.predictionShadowMargin), không trộn vào kích thước viên.
    let keycapAllowance: CGFloat = 40
    return CGSize(
      width: max(180, ceil(measured.width + horizontalPadding + keycapAllowance)),
      height: max(38, ceil(measured.height + verticalPadding))
    )
  }

  nonisolated private static func clampedFontSize(_ value: Int) -> Int {
    max(12, min(24, value))
  }

  nonisolated private static func clampedBackgroundStrength(_ value: Int) -> Double {
    Double(max(30, min(100, value))) / 100.0
  }

  private func ensurePanel() -> NSPanel {
    if let p = panel { return p }
    let p = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 36),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    p.isFloatingPanel = true
    p.level = .floating
    p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    p.isOpaque = false
    p.backgroundColor = .clear
    p.hasShadow = false  // SwiftUI vẽ shadow riêng (đã có đệm chứa nó)
    p.isMovable = false
    p.becomesKeyOnlyIfNeeded = true
    // v2.4.0: panel rộng hơn (đệm shadow) — tuyệt đối không chặn chuột.
    p.ignoresMouseEvents = true
    panel = p
    return p
  }

  /// Cố gắng đặt HUD sát dòng caret của focused text element.
  private func targetFrame(forContentSize contentSize: CGSize) -> NSRect {
    let lineOffset = Defaults[.predictionHUDLineOffset]
    let screens = NSScreen.screens
    if let caret = focusedElementCaretRect() ?? focusedTextFieldAnchorRect(),
       let frame = Self.computeVisualFrame(
         caretAX: caret,
         contentSize: contentSize,
         lineOffset: lineOffset,
         screens: screens
       ) {
      return frame
    }
    return fallbackFrame(
      width: contentSize.width,
      height: contentSize.height,
      lineOffset: lineOffset,
      screens: screens
    )
  }

  /// Chuẩn hoá caret AX — một số app (Electron chat) trả bounds cả dòng
  /// (width rất lớn) hoặc height bất thường; dùng mép phải làm neo chèn.
  nonisolated static func normalizedCaretRect(_ rect: CGRect) -> CGRect {
    var caret = rect
    if caret.width > 280 {
      let anchorX = max(caret.minX, caret.maxX - 4)
      caret = CGRect(x: anchorX, y: caret.minY, width: 4, height: caret.height)
    }
    if caret.height > 48 {
      caret.size.height = 48
    }
    if caret.height < 8 {
      caret.size.height = 16
    }
    return caret
  }

  /// Tính frame HUD (Cocoa coords, origin bottom-left) sao cho không chồng vùng gõ.
  /// Luôn căn giữa theo bề ngang màn hình; đặt phía trên dòng nhập.
  nonisolated static func computeVisualFrame(
    caretAX: CGRect,
    contentSize: CGSize,
    lineOffset: Int,
    screens: [NSScreen]
  ) -> NSRect? {
    guard
      let screen = screenContainingAXPoint(CGPoint(x: caretAX.midX, y: caretAX.midY), screens: screens)
    else { return nil }
    return computeVisualFrame(
      caretAX: caretAX,
      contentSize: contentSize,
      lineOffset: lineOffset,
      visibleFrame: screen.visibleFrame,
      primaryDisplayHeight: primaryDisplayHeight(screens: screens)
    )
  }

  /// Overload testable — không phụ thuộc NSScreen runtime.
  nonisolated static func computeVisualFrame(
    caretAX: CGRect,
    contentSize: CGSize,
    lineOffset: Int,
    visibleFrame: NSRect,
    primaryDisplayHeight: CGFloat
  ) -> NSRect? {
    let caret = normalizedCaretRect(caretAX)
    let width = contentSize.width
    let height = contentSize.height
    let lineHeight = min(max(caret.height, 16), 48)
    let offsetLines = CGFloat(max(1, min(20, lineOffset)))
    let separation = lineHeight * offsetLines
    let minGap: CGFloat = 8
    let visible = visibleFrame

    let caretTopCocoa = primaryDisplayHeight - caret.minY
    let caretBottomCocoa = primaryDisplayHeight - caret.maxY

    func caretOverlapsHUD(_ hud: NSRect) -> Bool {
      let hudTop = hud.origin.y + hud.size.height
      return hud.origin.y < caretTopCocoa && hudTop > caretBottomCocoa
    }

    func clampY(_ y: CGFloat) -> CGFloat {
      max(visible.minY + 8, min(y, visible.maxY - height - 8))
    }

    func centeredX() -> CGFloat {
      max(visible.minX + 8, min(visible.midX - width / 2, visible.maxX - width - 8))
    }

    // 1) Phía trên caret, căn giữa màn hình (mặc định).
    var aboveBottomY = caretTopCocoa + separation - height
    aboveBottomY = max(aboveBottomY, caretTopCocoa + minGap)
    let aboveFrame = NSRect(
      x: centeredX(),
      y: clampY(aboveBottomY),
      width: width,
      height: height
    )
    if !caretOverlapsHUD(aboveFrame) {
      return aboveFrame
    }

    // 2) Thu offset nếu sát mép trên màn hình — vẫn không hạ xuống dưới caret.
    let tightBottomY = caretTopCocoa + lineHeight * 1.25 - height
    let tightFrame = NSRect(
      x: centeredX(),
      y: clampY(max(tightBottomY, caretTopCocoa + minGap)),
      width: width,
      height: height
    )
    if !caretOverlapsHUD(tightFrame) {
      return tightFrame
    }

    // 3) Không đủ chỗ theo offset — neo sát phía trên caret, vẫn căn giữa.
    let snugFrame = NSRect(
      x: centeredX(),
      y: clampY(caretTopCocoa + minGap),
      width: width,
      height: height
    )
    if !caretOverlapsHUD(snugFrame) {
      return snugFrame
    }

    return nil
  }

  nonisolated private static func primaryDisplayHeight(screens: [NSScreen]) -> CGFloat {
    if let primary = screens.first(where: { $0.frame.origin == .zero }) {
      return primary.frame.height
    }
    return NSScreen.main?.frame.height ?? screens.first?.frame.height ?? 0
  }

  nonisolated private static func screenContainingAXPoint(
    _ axPoint: CGPoint,
    screens: [NSScreen]
  ) -> NSScreen? {
    let primaryHeight = primaryDisplayHeight(screens: screens)
    let cocoaPoint = CGPoint(x: axPoint.x, y: primaryHeight - axPoint.y)
    if let match = screens.first(where: { $0.frame.contains(cocoaPoint) }) {
      return match
    }
    return NSScreen.main ?? screens.first
  }

  private func fallbackFrame(
    width: CGFloat,
    height: CGFloat,
    lineOffset: Int,
    screens: [NSScreen]
  ) -> NSRect {
    let screen = NSScreen.main?.visibleFrame ?? screens.first?.visibleFrame ?? .zero
    let lineHeight: CGFloat = 20
    let offsetLines = CGFloat(max(1, min(20, lineOffset)))
    let separation = lineHeight * offsetLines

    let centeredX = max(
      screen.minX + 8,
      min(screen.midX - width / 2, screen.maxX - width - 8)
    )

    // Ưu tiên neo theo mép dưới ô nhập nếu AX trả được bounds element.
    if let anchor = focusedTextFieldAnchorRect(),
       let frame = Self.computeVisualFrame(
         caretAX: anchor,
         contentSize: CGSize(width: width, height: height),
         lineOffset: lineOffset,
         screens: screens
       ) {
      return frame
    }

    // Fallback cuối: căn giữa ngang, phía trên vùng nhập thường gặp ở đáy màn hình.
    let inputLineY = screen.minY + max(48, screen.height * 0.12)
    let bottomY = inputLineY + separation - height
    return NSRect(
      x: centeredX,
      y: max(screen.minY + 8, bottomY),
      width: width,
      height: height
    )
  }

  /// Khi parametric caret không khả dụng (Electron/Claude desktop), dùng
  /// mép dưới focused text field làm neo — không lấy bounds cả ô làm caret.
  private func focusedTextFieldAnchorRect() -> CGRect? {
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

    guard let position = axPoint(from: axElement, attribute: kAXPositionAttribute as CFString),
          let size = axSize(from: axElement, attribute: kAXSizeAttribute as CFString),
          size.width > 0, size.height > 0
    else { return nil }

    let lineHeight = min(max(size.height * 0.12, 16), 48)
    let anchorX = position.x + size.width / 2
    let anchorY = position.y + size.height - lineHeight
    return CGRect(x: anchorX - 2, y: anchorY, width: 4, height: lineHeight)
  }

  private func axPoint(from element: AXUIElement, attribute: CFString) -> CGPoint? {
    var valueRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
          let value = valueRef,
          CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    let axValue = value as! AXValue
    guard AXValueGetType(axValue) == .cgPoint else { return nil }
    var point = CGPoint.zero
    guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
    return point
  }

  private func axSize(from element: AXUIElement, attribute: CFString) -> CGSize? {
    var valueRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
          let value = valueRef,
          CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    let axValue = value as! AXValue
    guard AXValueGetType(axValue) == .cgSize else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
    return size
  }

  /// Lấy caret bounds CHÍNH XÁC qua AX parametric API.
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

    if let caretRect = parametricCaretRect(axElement: axElement),
       caretRect.width > 0 || caretRect.height > 0 {
      return caretRect
    }

    // Không fallback bounds cả ô text — gây đặt HUD lọt vào giữa vùng gõ
    // (Electron/Claude desktop). Caller dùng fallbackFrame ngoài vùng nhập.
    return nil
  }

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

    // Insertion point: length 0 trước — đúng vị trí con trỏ, không lấy cả ký tự.
    if range.length == 0 {
      if let rangeAXValue = AXValueCreate(.cfRange, &range),
         let rect = boundsForRange(axElement: axElement, rangeAXValue: rangeAXValue),
         rect.width > 0 || rect.height > 0 {
        return rect
      }
      range.length = 1
    }

    guard let rangeAXValue = AXValueCreate(.cfRange, &range) else { return nil }
    return boundsForRange(axElement: axElement, rangeAXValue: rangeAXValue)
  }

  private func boundsForRange(axElement: AXUIElement, rangeAXValue: AXValue) -> CGRect? {
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
  let prediction: String
  let fontSize: Int
  let backgroundStrength: Double
  let contentSize: CGSize

  init(prediction: String, fontSize: Int, backgroundStrength: Double, contentSize: CGSize) {
    self.prediction = prediction
    self.fontSize = fontSize
    self.backgroundStrength = backgroundStrength
    self.contentSize = contentSize
  }

  @Default(.uiTheme) private var uiTheme

  var body: some View {
    Group {
      switch uiTheme {
      case .glass:  glassBody
      case .neural: neuralBody
      case .tonal:  tonalBody
      }
    }
    .frame(width: contentSize.width, height: contentSize.height)
    // v2.4.0: đệm trong suốt chứa shadow — khớp windowSize bên controller.
    .padding(HUDMetrics.predictionShadowMargin)
  }

  // MARK: - Neural AI HUD — pill obsidian + viền gradient + mũi tên gradient

  private var neuralBody: some View {
    HStack(spacing: 6) {
      Text("→")
        .font(.system(size: CGFloat(fontSize), weight: .heavy, design: .rounded))
        .foregroundStyle(VK.Color.brandGradient)
      Text(prediction)
        .font(.system(size: CGFloat(fontSize), weight: .semibold))
        .foregroundStyle(Color(vkHex: "#ECECF7"))
      Text("·")
        .font(.system(size: CGFloat(fontSize), weight: .regular))
        .foregroundStyle(Color(vkHex: "#ECECF7").opacity(0.4))
      Keycap("Tab", size: .sm)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(Capsule().fill(Color(vkHex: "#0F0F18").opacity(0.88)))
    .background(HUDBackdrop()) // v2.4.0
    .overlay(Capsule().strokeBorder(VK.Color.brandGradient, lineWidth: 1).opacity(0.6))
    .compositingGroup()
    .shadow(color: VK.Color.glow.opacity(0.4 * VK.glowK), radius: 14, x: 0, y: 6)
  }

  // MARK: - Liquid Glass HUD — viên kính pill `→ <pred> · Tab`

  private var glassBody: some View {
    HStack(spacing: 6) {
      Text("→")
        .font(.system(size: CGFloat(fontSize), weight: .heavy, design: .rounded))
        .foregroundStyle(VK.Color.brand)
      Text(prediction)
        .font(.system(size: CGFloat(fontSize), weight: .semibold))
        .foregroundStyle(.primary)
      Text("·")
        .font(.system(size: CGFloat(fontSize), weight: .regular))
        .foregroundStyle(.primary.opacity(0.4))
      Keycap("Tab", size: .sm)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(HUDBackdrop()) // v2.4.0
    .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
    // v2.4.0: bỏ .blendMode(.screen) — stroke trắng đậm hơn thay thế
    .overlay(Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5))
    .compositingGroup()
    .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 6)
  }

  // MARK: - Tonal HUD — format `→ <pred> · Tab(keycap)`

  private var tonalBody: some View {
    HStack(spacing: 6) {
      Text("→")
        .font(.system(size: CGFloat(fontSize), weight: .heavy, design: .rounded))
        .foregroundStyle(VKeyDesign.red300)

      Text(prediction)
        .font(.system(size: CGFloat(fontSize), weight: .semibold))
        .foregroundStyle(.white)

      Text("·")
        .font(.system(size: CGFloat(fontSize), weight: .regular))
        .foregroundStyle(Color.white.opacity(0.45))

      Keycap("Tab", size: .sm)
    }
    .shadow(color: .black.opacity(0.25), radius: 0.5, x: 0, y: 0.5)
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(
      VKeyDesign.ink500.opacity(tonalScrimOpacity),
      in: RoundedRectangle(cornerRadius: 10)
    )
    .background(HUDBackdrop(cornerRadius: 10)) // v2.4.0
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    )
    .compositingGroup()
    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
  }

  private var tonalScrimOpacity: Double {
    0.32 + 0.30 * backgroundStrength
  }
}
