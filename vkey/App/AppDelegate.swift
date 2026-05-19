import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI

extension Notification.Name {
  static let vkeyOnboardingDidComplete = Notification.Name("vkeyOnboardingDidComplete")
}

// AppDelegate manages the application lifecycle and background services
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

  @Published var appState = AppState()
  @Published var isTrusted = false

  /// Polling timer for Accessibility-permission grant. Stored so we can
  /// invalidate it on max-retry or app termination.
  private var trustCheckTimer: Timer?
  private var trustCheckRetries = 0
  /// Stop polling after ~60s — beyond that the user almost certainly hasn't
  /// granted permission (or never will in this session). A one-time NSAlert
  /// then guides them to System Settings.
  private let maxTrustCheckRetries = 30

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
    
    // Periodically check trust status if not trusted. Capped at
    // `maxTrustCheckRetries` to avoid polling forever (e.g. when the user
    // permanently denies Accessibility). After the cap, an NSAlert nudges
    // them to System Settings → Privacy & Security → Accessibility.
    if !isTrusted {
      trustCheckRetries = 0
      trustCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
        [weak self] timer in
        guard let self else {
          timer.invalidate()
          return
        }
        self.checkTrustStatus()
        if self.isTrusted {
          timer.invalidate()
          self.trustCheckTimer = nil
          self.setupTrustedSession()
          return
        }
        self.trustCheckRetries += 1
        if self.trustCheckRetries >= self.maxTrustCheckRetries {
          timer.invalidate()
          self.trustCheckTimer = nil
          self.showAccessibilityHelpAlert()
        }
      }
    }
    
    // Check for updates silently on launch
    Updater.checkForUpdates(manual: false)

    // Check for dictionary updates on launch
    LexiconManager.shared.checkAndPromptForDictionaryUpdate()

    // 1.5.0: run the weekly stats → personal-dictionary feedback loop, but at
    // most once per ISO week. The summary is computed regardless; promotion
    // logic inside `performWeeklyFeedback` is itself idempotent.
    runWeeklyFeedbackIfDue()

    // 1.5.0: prompt for a personal-data backup the first launch after a
    // version upgrade (gated by Defaults[.autoBackupOnUpgrade]).
    UserDataMigration.handleVersionChange()
  }

  /// Gate `performWeeklyFeedback()` so it fires once per ISO week even if
  /// the user opens the app several times. We track the last-run week id in
  /// `Defaults[.lastFeedbackWeekId]`.
  private func runWeeklyFeedbackIfDue() {
    let cal = Calendar(identifier: .iso8601)
    let now = Date()
    let weekId = String(format: "%04d-W%02d",
                        cal.component(.yearForWeekOfYear, from: now),
                        cal.component(.weekOfYear, from: now))
    guard Defaults[.lastFeedbackWeekId] != weekId else { return }
    // Run on a background queue so we don't delay app launch.
    DispatchQueue.global(qos: .utility).async {
      _ = UsageStatistics.shared.performWeeklyFeedback()
      DispatchQueue.main.async {
        Defaults[.lastFeedbackWeekId] = weekId
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

  // Opens donate window
  @objc func openDonate() {
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
    trustCheckTimer?.invalidate()
    trustCheckTimer = nil
    LexiconManager.shared.cancelInFlightDownloads()
    appState.eventHook.destroy()
  }

  /// Shown after the trust polling loop has given up. The alert links the
  /// user to System Settings so they can grant Accessibility manually, and
  /// offers a "Try again" path that restarts polling.
  private func showAccessibilityHelpAlert() {
    let alert = NSAlert()
    alert.messageText = "vkey cần quyền Trợ năng (Accessibility)"
    alert.informativeText = """
    vkey cần được cấp quyền Accessibility để có thể chuyển ký tự bạn gõ \
    thành tiếng Việt. Vui lòng mở:

    System Settings → Privacy & Security → Accessibility

    rồi bật toggle cho vkey. Sau đó nhấn "Thử lại" để vkey tiếp tục.
    """
    alert.addButton(withTitle: "Mở Cài đặt")
    alert.addButton(withTitle: "Thử lại")
    alert.addButton(withTitle: "Để sau")
    alert.alertStyle = .warning

    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    switch alert.runModal() {
    case .alertFirstButtonReturn:
      // Open the Accessibility pane directly. URL accepted by macOS 13+.
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      ) {
        NSWorkspace.shared.open(url)
      }
      restartTrustCheckLoop()
    case .alertSecondButtonReturn:
      restartTrustCheckLoop()
    default:
      break
    }
  }

  private func restartTrustCheckLoop() {
    trustCheckRetries = 0
    trustCheckTimer?.invalidate()
    trustCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
      [weak self] timer in
      guard let self else {
        timer.invalidate()
        return
      }
      self.checkTrustStatus()
      if self.isTrusted {
        timer.invalidate()
        self.trustCheckTimer = nil
        self.setupTrustedSession()
        return
      }
      self.trustCheckRetries += 1
      if self.trustCheckRetries >= self.maxTrustCheckRetries {
        timer.invalidate()
        self.trustCheckTimer = nil
        self.showAccessibilityHelpAlert()
      }
    }
  }
}
