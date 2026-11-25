//
//  WindowCoordinator.swift
//  vkey
//
//  Điều phối cửa sổ (Onboarding, Upgrade, Donate, Settings autosave),
//  chuyển đổi activation policy `.regular` ↔ `.accessory`, và helper hiện modal nổi.
//

import AppKit
import Foundation
import SwiftUI

final class WindowCoordinator {

  private weak var onboardingWindow: NSWindow?
  private weak var upgradeWindow: NSWindow?
  private weak var donateWindow: NSWindow?

  init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowWillClose(_:)),
      name: NSWindow.willCloseNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: NSWindow.didBecomeKeyNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Shared Modal & Policy Helpers

  /// Chuẩn bị app `.accessory` để hiện dialog modal (Sparkle / NSAlert):
  /// chuyển sang `.regular`, chờ `delay` cho WindowServer settle, kích hoạt app rồi chạy `work`.
  static func presentFloatingModal(
    delay: TimeInterval = 0.25,
    work: @escaping () -> Void
  ) {
    NSApp.setActivationPolicy(.regular)
    if delay > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        NSApp.activate(ignoringOtherApps: true)
        work()
      }
    } else {
      NSApp.activate(ignoringOtherApps: true)
      work()
    }
  }

  /// Hạ lại `.accessory` (ẩn khỏi Dock / Cmd-Tab) nếu không còn cửa sổ thường nào đang hiện.
  static func restoreAccessoryPolicyIfNeeded(excluding closing: NSWindow? = nil) {
    let stillOpen = NSApp.windows.contains { win in
      win !== closing && win.isVisible && win.canBecomeKey && !(win is NSPanel)
    }
    if !stillOpen {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  // MARK: - Window Presentation

  private func bringToFront(_ window: NSWindow?) -> Bool {
    guard let window, window.isVisible else { return false }
    NSApp.setActivationPolicy(.regular)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    return true
  }

  func openOnboarding(appState: AppState) {
    if bringToFront(onboardingWindow) { return }
    NSApp.setActivationPolicy(.regular)
    let contentView = OnboardingView().environmentObject(appState)
    let windowController = OnboardingWindowController()
    windowController.contentViewController = NSHostingController(rootView: contentView)
    windowController.showWindow(nil)
    onboardingWindow = windowController.window
    NSApp.activate(ignoringOtherApps: true)
  }

  func openUpgradeNewVersion(appState: AppState) {
    if bringToFront(upgradeWindow) { return }
    NSApp.setActivationPolicy(.regular)
    let contentView = UpgradeAppView().environmentObject(appState)
    let windowController = OnboardingWindowController()
    windowController.contentViewController = NSHostingController(rootView: contentView)
    windowController.showWindow(nil)
    upgradeWindow = windowController.window
    NSApp.activate(ignoringOtherApps: true)
  }

  func openDonate() {
    if bringToFront(donateWindow) { return }
    NSApp.setActivationPolicy(.regular)
    let contentView = DonateView()
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.center()
    window.title = "Ủng hộ tác giả"
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.contentViewController = NSHostingController(rootView: contentView)

    let windowController = NSWindowController(window: window)
    windowController.showWindow(nil)
    donateWindow = window
    NSApp.activate(ignoringOtherApps: true)
  }

  func closeOnboardingWindows() {
    NSApp.windows
      .filter { $0.title == "vkey - Cài Đặt" }
      .forEach { $0.close() }
    Self.restoreAccessoryPolicyIfNeeded()
  }

  // MARK: - NSWindow Notifications

  @objc private func windowDidBecomeKey(_ note: Notification) {
    guard let win = note.object as? NSWindow else { return }
    let isSettingsWindow =
      win.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
      || win.title.localizedCaseInsensitiveContains("settings")
      || win.title.localizedCaseInsensitiveContains("cài đặt")
    guard isSettingsWindow else { return }
    if win.frameAutosaveName.isEmpty {
      win.setFrameAutosaveName("VkeySettingsWindow.v178")
    }
  }

  @objc private func windowWillClose(_ note: Notification) {
    guard let closing = note.object as? NSWindow else { return }
    DispatchQueue.main.async {
      Self.restoreAccessoryPolicyIfNeeded(excluding: closing)
    }
  }
}
