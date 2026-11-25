//
//  FloatingHUDPanel.swift
//  vkey
//
//  Lớp nền NSPanel trong suốt nổi trên mọi không gian dùng chung giữa
//  ToggleHUDWindow và NoticeHUDWindow (tạo panel, hosting view, đo chữ,
//  căn giữa màn hình, kẹp độ mờ, fade/auto-hide).
//

import AppKit
import SwiftUI

@MainActor
final class FloatingHUDPanel<Content: View> {
  private var panel: NSPanel?
  private var hostingController: NSHostingController<Content>?
  private var hideTimer: Timer?

  /// Kẹp `hudOpacityPercent` về [30, 100] rồi quy về [0.3, 1.0].
  nonisolated static func clampedBackgroundStrength(_ percent: Int) -> Double {
    Double(max(30, min(100, percent))) / 100.0
  }

  /// Đo kích thước bounding rect của văn bản với font và độ rộng tối đa.
  nonisolated static func measureText(
    _ text: String,
    font: NSFont,
    maxWidth: CGFloat = .greatestFiniteMagnitude
  ) -> CGSize {
    let rect = (text as NSString).boundingRect(
      with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: font]
    )
    return CGSize(width: ceil(rect.width), height: ceil(rect.height))
  }

  /// Tạo hoặc cập nhật root view, đặt kích thước + vị trí (lệch dưới tâm màn hình `yOffset`)
  /// và đưa panel lên trước mà không cướp focus.
  func present(
    rootView: Content,
    contentSize: CGSize,
    yOffset: CGFloat,
    fadeInDuration: TimeInterval = 0,
    autoHideAfter duration: TimeInterval,
    fadeOutDuration: TimeInterval = 0
  ) {
    hideTimer?.invalidate()

    let margin = HUDMetrics.shadowMargin
    let windowSize = CGSize(
      width: contentSize.width + margin * 2,
      height: contentSize.height + margin * 2
    )

    let activePanel = ensurePanel(initialSize: windowSize)

    if let existing = hostingController {
      existing.rootView = rootView
      existing.view.setFrameSize(windowSize)
    } else {
      let controller = NSHostingController(rootView: rootView)
      controller.sizingOptions = []
      controller.view.wantsLayer = true
      controller.view.layer?.backgroundColor = NSColor.clear.cgColor
      controller.view.setFrameSize(windowSize)
      hostingController = controller
      activePanel.contentViewController = controller
    }

    activePanel.setContentSize(windowSize)
    position(activePanel, windowSize: windowSize, yOffset: yOffset)

    if fadeInDuration > 0 {
      activePanel.alphaValue = 0
      activePanel.orderFrontRegardless()
      NSAnimationContext.runAnimationGroup { context in
        context.duration = fadeInDuration
        activePanel.animator().alphaValue = 1
      }
    } else {
      activePanel.alphaValue = 1
      activePanel.orderFrontRegardless()
    }

    hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
      Task { @MainActor in
        if fadeOutDuration > 0 {
          self?.hideWithFade(duration: fadeOutDuration)
        } else {
          self?.hideImmediately()
        }
      }
    }
  }

  func hideImmediately() {
    hideTimer?.invalidate()
    hideTimer = nil
    panel?.orderOut(nil)
  }

  private func hideWithFade(duration: TimeInterval) {
    guard let panel else { return }
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = duration
      panel.animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      Task { @MainActor in self?.panel?.orderOut(nil) }
    })
  }

  private func ensurePanel(initialSize: CGSize) -> NSPanel {
    if let panel { return panel }
    let p = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    p.isFloatingPanel = true
    p.level = .popUpMenu
    p.isOpaque = false
    p.backgroundColor = .clear
    p.hasShadow = false
    p.ignoresMouseEvents = true
    p.isReleasedWhenClosed = false
    p.hidesOnDeactivate = false
    p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    panel = p
    return p
  }

  private func position(_ panel: NSPanel, windowSize: CGSize, yOffset: CGFloat) {
    let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
    guard let screen else { return }
    let frame = screen.visibleFrame
    let x = frame.midX - windowSize.width / 2
    let y = frame.midY - windowSize.height / 2 + yOffset
    panel.setFrameOrigin(NSPoint(x: x, y: y))
  }
}
