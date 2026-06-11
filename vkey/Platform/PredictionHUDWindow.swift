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
    let width = contentSize.width
    let height = contentSize.height

    if let caret = focusedElementCaretRect() {
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

      let lineHeight = max(caret.height, 16)
      let offsetLines = CGFloat(max(1, min(10, Defaults[.predictionHUDLineOffset])))
      let separation = lineHeight * offsetLines

      let axTopY = caret.minY
      var hudCocoaBottomY = mainHeight - axTopY + separation - height

      let caretTopCocoa = mainHeight - axTopY
      let minCaretGap: CGFloat = 6
      hudCocoaBottomY = max(hudCocoaBottomY, caretTopCocoa + minCaretGap)

      let hudCocoaTopY = hudCocoaBottomY + height
      if hudCocoaTopY > screen.frame.maxY - 8 {
        let axBottomY = caret.maxY
        hudCocoaBottomY = mainHeight - axBottomY - separation - height
      }

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

    var posValue: CFTypeRef?
    var sizeValue: CFTypeRef?
    AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &posValue)
    AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &sizeValue)
    guard let pos = cgPoint(from: posValue),
          let size = cgSize(from: sizeValue)
    else { return nil }

    return CGRect(origin: pos, size: size)
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
    if range.length == 0 {
      range.length = 1
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
