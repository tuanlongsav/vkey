import Cocoa
import Combine
import Foundation
import SwiftUI

extension Notification.Name {
  static let vkeyOnboardingDidComplete = Notification.Name("vkeyOnboardingDidComplete")
}

// AppDelegate manages the application lifecycle and background services
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

  @Published var appState = AppState()
  @Published var isTrusted = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Hide dock icon since we use MenuBarExtra
    NSApp.setActivationPolicy(.accessory)

    // When the Settings (or onboarding) window closes, slide the app back to
    // .accessory so it disappears from Cmd-Tab and the Dock. We only need to
    // be .regular while a real window is on screen — otherwise the menu bar
    // app couldn't accept first-responder events (which is why the
    // KeyboardShortcuts.Recorder fails to capture keystrokes under .accessory).
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowWillClose(_:)),
      name: NSWindow.willCloseNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onboardingDidComplete),
      name: .vkeyOnboardingDidComplete,
      object: nil
    )

    checkTrustStatus()

    if isTrusted {
      // Set up the event tap if the process is trusted
      appState.storeTrustedAppVersion()
      appState.eventHook.setupEventTap(give: appState)

      appState.load()
      appState.setEnabled(set: true)
      appState.registerSwitchFileMonitor()

    } else if appState.isNewAppVersion() {
      openUpgradeNewVersion()
    } else {
      openGuide()
    }
    
    // Periodically check trust status if not trusted
    if !isTrusted {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            self?.checkTrustStatus()
            if self?.isTrusted == true {
                timer.invalidate()
                self?.setupTrustedSession()
            }
        }
    }
  }
  
  func checkTrustStatus() {
      isTrusted = appState.eventHook.isTrusted(prompt: false)
  }
  
  func setupTrustedSession() {
      isTrusted = true
      appState.storeTrustedAppVersion()
      appState.eventHook.setupEventTap(give: appState)
      appState.load()
      appState.setEnabled(set: true)
      appState.registerSwitchFileMonitor()
  }

  @objc func onboardingDidComplete() {
    checkTrustStatus()
    if isTrusted {
      setupTrustedSession()
    }

    closeOnboardingWindows()
  }

  // Opens onboarding guide
  @objc func openGuide() {
    NSApp.setActivationPolicy(.regular)
    let contentView = OnboardingView().environmentObject(appState)
    let windowController = OnboardingWindowController()
    windowController.contentViewController = NSHostingController(rootView: contentView)
    windowController.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  // Opens upgrade guide
  @objc func openUpgradeNewVersion() {
    NSApp.setActivationPolicy(.regular)
    let contentView = UpgradeAppView().environmentObject(appState)
    let windowController = OnboardingWindowController()
    windowController.contentViewController = NSHostingController(rootView: contentView)
    windowController.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func closeOnboardingWindows() {
    NSApp.windows
      .filter { $0.title == "vkey - Cài Đặt" }
      .forEach { $0.close() }

    let hasVisibleWindow = NSApp.windows.contains { window in
      window.isVisible && window.canBecomeKey && !(window is NSPanel)
    }

    if !hasVisibleWindow {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  // Opens settings window
  @objc func openSettings() {
    NSApp.setActivationPolicy(.regular)
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSApp.activate(ignoringOtherApps: true)
    }
  }

  // Called for every NSWindow close. When the last visible regular window is
  // closing, drop activation policy back to .accessory so the app re-hides.
  @objc func windowWillClose(_ note: Notification) {
    guard let closing = note.object as? NSWindow else { return }
    DispatchQueue.main.async {
      let stillOpen = NSApp.windows.contains { win in
        win !== closing && win.isVisible
          && win.canBecomeKey
          && !(win is NSPanel)
      }
      if !stillOpen {
        NSApp.setActivationPolicy(.accessory)
      }
    }
  }

  // Quits the application
  @objc func quitApp() {
    NSApp.terminate(self)
  }

  // Returns true to opt-in to secure coding for state restoration
  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Cleans up before the application terminates
  func applicationWillTerminate(_ aNotification: Notification) {
    appState.eventHook.destroy()
  }
}
