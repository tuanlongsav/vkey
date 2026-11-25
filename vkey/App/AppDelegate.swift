import Cocoa
import Defaults
import Foundation
import os.log
import UserNotifications

extension Notification.Name {
  static let vkeyOnboardingDidComplete = Notification.Name("vkeyOnboardingDidComplete")
}

// AppDelegate manages the application lifecycle and coordinates background services.
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate {

  @Published var appState = AppState()
  @Published var isTrusted = false

  private let windowCoordinator = WindowCoordinator()
  private var accessibilityWatchdog: AccessibilityWatchdog?

  func applicationWillFinishLaunching(_ notification: Notification) {
    // vkey ưu tiên tiếng Việt — dialog Sparkle và NSAlert hệ thống lấy chuỗi từ vi.lproj.
    UserDefaults.standard.set(["vi", "en"], forKey: "AppleLanguages")
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    FontRegistration.register()

    #if DEBUG
    if MarketingSnapshotExporter.isRequested {
      NSApp.setActivationPolicy(.regular)
      Task { @MainActor in
        MarketingSnapshotExporter.run(appDelegate: self)
      }
      return
    }
    #endif

    NSApp.setActivationPolicy(.accessory)

    if let img = NSImage(named: "Cficon") {
      NSApplication.shared.applicationIconImage = img
    }

    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

    // Wire Toggle HUD observer outside AppState
    appState.onToggleHUD = { isEnabled in
      ToggleHUDWindow.shared.show(isEnabled: isEnabled)
    }

    StartupMigrations.runAll()
    Focused.setupAXTimeout(0.1)

    DispatchQueue.global(qos: .background).async {
      let deleted = UserDataMigration.cleanupOldBackups()
      if deleted > 0 {
        os_log("AppDelegate: cleaned %{public}d old backup files", log: .default, type: .info, deleted)
      }
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onboardingDidComplete),
      name: .vkeyOnboardingDidComplete,
      object: nil
    )

    let watchdog = AccessibilityWatchdog(
      appState: appState,
      isCurrentlyTrusted: { [weak self] in self?.isTrusted ?? false },
      onTrustStatusChanged: { [weak self] trusted in self?.isTrusted = trusted },
      onBecameTrusted: { [weak self] in self?.setupTrustedSession() }
    )
    self.accessibilityWatchdog = watchdog

    appState.eventHook.onTapSetupFailed = { [weak watchdog] in
      watchdog?.showAccessibilityHelpAlert()
    }

    // Chụp phiên bản lần chạy trước TRƯỚC khi `setupTrustedSession()` ghi đè.
    let versionBeforeLaunch = Defaults[.currentVersion]

    checkTrustStatus()

    if isTrusted {
      setupTrustedSession()
    } else if appState.isNewAppVersion() {
      openUpgradeNewVersion()
    } else {
      openOnboarding()
    }

    if !isTrusted {
      watchdog.restartTrustCheckLoop()
    }

    Updater.configureOnLaunch()
    LexiconManager.shared.checkAndPromptForDictionaryUpdate()
    runWeeklyFeedbackIfDue()
    UserDataMigration.handleVersionChange(previousVersion: versionBeforeLaunch)
  }

  private func runWeeklyFeedbackIfDue() {
    guard Defaults[.autoPersonalDictFeedback] else { return }

    let cal = Calendar(identifier: .iso8601)
    let now = Date()
    let weekId = String(
      format: "%04d-W%02d",
      cal.component(.yearForWeekOfYear, from: now),
      cal.component(.weekOfYear, from: now))
    guard Defaults[.lastFeedbackWeekId] != weekId else { return }

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
    appState.setEnabled(set: true)
    accessibilityWatchdog?.startRevocationWatchdog()
  }

  @objc func onboardingDidComplete() {
    checkTrustStatus()
    if isTrusted {
      setupTrustedSession()
    }
    windowCoordinator.closeOnboardingWindows()
  }

  @objc func openOnboarding() {
    windowCoordinator.openOnboarding(appState: appState)
  }

  @objc func openUpgradeNewVersion() {
    windowCoordinator.openUpgradeNewVersion(appState: appState)
  }

  @objc func openDonate() {
    windowCoordinator.openDonate()
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    accessibilityWatchdog?.stopAll()
    LexiconManager.shared.cancelInFlightDownloads()
    appState.eventHook.destroy()
    UsageStatistics.shared.flushSynchronously()
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier.hasPrefix("vkey-update-") {
      Updater.checkForUpdates(manual: true)
    }
    completionHandler()
  }
}
