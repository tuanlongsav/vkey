//
//  VKWindowConfigurator.swift
//  vkey — Cấu hình chrome cửa sổ Cài đặt (titlebar trong suốt, nền theo theme).
//

import AppKit
import SwiftUI

struct VKWindowConfigurator: NSViewRepresentable {
  var theme: UITheme

  func makeNSView(context: Context) -> VKWindowHook {
    let v = VKWindowHook()
    v.theme = theme
    return v
  }

  func updateNSView(_ nsView: VKWindowHook, context: Context) {
    nsView.theme = theme
  }
}

final class VKWindowHook: NSView {
  var theme: UITheme = .tonal { didSet { scheduleApply() } }
  private var keyObserver: NSObjectProtocol?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let o = keyObserver { NotificationCenter.default.removeObserver(o); keyObserver = nil }
    guard let w = window else { return }
    keyObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification, object: w, queue: .main
    ) { [weak self] _ in self?.scheduleApply() }
    scheduleApply()
  }

  deinit {
    if let o = keyObserver { NotificationCenter.default.removeObserver(o) }
  }

  private func scheduleApply() {
    guard window != nil else { return }
    let t = theme
    for delay in [0.0, 0.25, 1.0] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        Self.configure(self?.window, theme: t)
      }
    }
  }

  private static func configure(_ window: NSWindow?, theme: UITheme) {
    guard let window else { return }
    if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
    if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
    if let toolbar = window.toolbar, toolbar.isVisible { toolbar.isVisible = false }
    if !window.styleMask.contains(.fullSizeContentView) {
      window.styleMask.insert(.fullSizeContentView)
    }
    switch theme {
    case .glass:
      if window.isOpaque { window.isOpaque = false }
      window.backgroundColor = .clear
    case .neural:
      if !window.isOpaque { window.isOpaque = true }
      window.backgroundColor = NSColor(name: nil) { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
          ? NSColor(srgbRed: 0x0B / 255, green: 0x0B / 255, blue: 0x14 / 255, alpha: 1)
          : NSColor(srgbRed: 0xF4 / 255, green: 0xF3 / 255, blue: 0xFB / 255, alpha: 1)
      }
    case .tonal:
      if !window.isOpaque { window.isOpaque = true }
      window.backgroundColor = NSColor(name: nil) { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
          ? NSColor(srgbRed: 0x13 / 255, green: 0x15 / 255, blue: 0x19 / 255, alpha: 1)
          : NSColor(srgbRed: 0xFA / 255, green: 0xF8 / 255, blue: 0xF4 / 255, alpha: 1)
      }
    }
  }
}
