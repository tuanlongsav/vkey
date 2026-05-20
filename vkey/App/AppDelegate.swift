import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI
import UserNotifications

extension Notification.Name {
  static let vkeyOnboardingDidComplete = Notification.Name("vkeyOnboardingDidComplete")
}

// AppDelegate manages the application lifecycle and background services
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate {

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

    // 1.6.0: setup UN center delegate + xin permission cho update banner.
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound]
    ) { _, _ in
      // Ignore errors — user can grant later via System Settings.
      // Sparkle's own dialog vẫn là backup nếu user reject banner.
    }

    // 1.5.5: seed/migrate bộ macro mặc định. Idempotent — chỉ chạy migration
    // 1 lần khi user lên version mới. Chi tiết trong `DefaultMacros.swift`.
    seedDefaultMacrosIfNeeded()

    // 1.7.0: migrate smartSwitchApps (list) → appSmartSwitchConfigs (3-state map).
    // Idempotent — chỉ chạy nếu configs đang rỗng.
    AppState.migrateSmartSwitchTo3State()

    // 1.7.0: chạy auto-learn Smart Switch nếu chưa chạy tuần này.
    runSmartSwitchAutoLearnIfDue()

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
    // 1.6.1: nhận biết Settings NSWindow khi vừa được tạo bởi SwiftUI
    // Settings scene → áp resizable + min size + autosave frame. SwiftUI
    // không expose customization cho Settings scene nên phải hook qua AppKit.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: NSWindow.didBecomeKeyNotification,
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

  /// 1.7.2+: Gate auto-learn Smart Switch chạy 1 lần/NGÀY (đổi từ 1 lần/tuần).
  /// Combined với threshold ≥1 ngày dataset → user thấy auto-learn phản hồi
  /// trong vòng 1-2 ngày sau khi gõ đủ data.
  private func runSmartSwitchAutoLearnIfDue() {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.calendar = Calendar(identifier: .iso8601)
    let today = fmt.string(from: Date())
    guard Defaults[.lastSmartSwitchAutoLearnDate] != today else { return }
    DispatchQueue.global(qos: .utility).async { [weak self] in
      let suggestions = UsageStatistics.shared.computeSmartSwitchAutoLearn()
      DispatchQueue.main.async {
        self?.appState.applySmartSwitchAutoLearn(suggestions)
        Defaults[.lastSmartSwitchAutoLearnDate] = today
      }
    }
  }

  /// Gate `performWeeklyFeedback()` so it fires once per ISO week even if
  /// the user opens the app several times. We track the last-run week id in
  /// `Defaults[.lastFeedbackWeekId]`.
  private func runWeeklyFeedbackIfDue() {
    // 1.5.5+: gate trên toggle "Học hành vi từ Thống kê" trong tab Chính tả.
    guard Defaults[.autoPersonalDictFeedback] else { return }

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

  /// 1.7.6: Settings window resize do SwiftUI xử lý qua modifier
  /// `.windowResizability(.contentMinSize)` trên Settings scene
  /// ([vkeyApp.swift](vkey/vkeyApp.swift)). AppDelegate chỉ chịu trách
  /// nhiệm gắn frame autosave + dọn các key cũ trong NSUserDefaults.
  @objc func windowDidBecomeKey(_ note: Notification) {
    guard let win = note.object as? NSWindow else { return }
    // Settings window có title "vkey Settings" (English locale) hoặc local
    // hoá. Match qua identifier "com_apple_SwiftUI_Settings_window" cho
    // robust cross-locale.
    let isSettingsWindow =
      win.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
      || win.title.localizedCaseInsensitiveContains("settings")
      || win.title.localizedCaseInsensitiveContains("cài đặt")
    guard isSettingsWindow else { return }
    // Idempotent — chỉ gắn autosave name 1 lần.
    if win.frameAutosaveName.isEmpty {
      // Dọn key autosave cũ để tránh tích luỹ orphan trong NSUserDefaults.
      let legacyAutosaveKeys = [
        "NSWindow Frame VkeySettingsWindow",
        "NSWindow Frame VkeySettingsWindow.v174",
        "NSWindow Frame VkeySettingsWindow.v175",
        "NSWindow Frame VkeySettingsWindow.v176",
        "NSWindow Frame VkeySettingsWindow.v177",
      ]
      for key in legacyAutosaveKeys {
        UserDefaults.standard.removeObject(forKey: key)
      }
      win.setFrameAutosaveName("VkeySettingsWindow.v178")
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
    // 1.6.0: ensure stats persist trước khi exit (vd Sparkle restart sau
    // install). Bình thường scheduleFlush debounce 10s, nhưng terminate
    // race không thể đợi.
    UsageStatistics.shared.flushSynchronously()
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
      // Open the Accessibility pane directly. URL accepted by macOS 14+.
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

  // MARK: - UNUserNotificationCenterDelegate (1.6.0+)

  /// Khi app đang foreground và banner update tới, hiển thị banner luôn
  /// (mặc định macOS suppress notification của foreground app).
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  /// User click banner → mở Sparkle dialog với option Install Update.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier.hasPrefix("vkey-update-") {
      // Trigger Sparkle manual check → dialog Install.
      Updater.checkForUpdates(manual: true)
    }
    completionHandler()
  }

  /// Seed / migrate bộ macro mặc định. Idempotent — chạy mỗi launch nhưng
  /// chỉ thực thi khi `Defaults[.defaultMacrosVersion] < 2`. Migration v1→v2:
  /// - User mới chưa từng seed: seed `DefaultMacros.allDefaults` (34 entries).
  /// - User 1.5.3/1.5.4 đã seed 19 entries cũ: dọn entries bỏ + rename + add
  ///   entries mới còn thiếu. Tôn trọng entry user đã sửa (chỉ migrate khi
  ///   tuple (from, to) vẫn giữ nguyên bản default cũ).
  private func seedDefaultMacrosIfNeeded() {
    let currentSeedVersion = Defaults[.defaultMacrosVersion]

    // Already at v2 → done.
    if currentSeedVersion >= 2 { return }

    // First-launch ever (1.5.0+): nothing seeded yet.
    if !Defaults[.macrosSeeded] && Defaults[.macros].isEmpty {
      Defaults[.macros] = DefaultMacros.allDefaults
      Defaults[.macrosSeeded] = true
      Defaults[.defaultMacrosVersion] = 2
      return
    }

    // Migrate v1 (1.5.3/1.5.4 seed) → v2 (1.5.5 seed).
    var macros = Defaults[.macros]

    // 1) Remove obsolete seeds — chỉ nếu user chưa sửa (cả `from` và `to`
    //    vẫn khớp với default cũ).
    for entry in DefaultMacros.obsoleteSeedsV1 {
      macros.removeAll { $0.from == entry.from && $0.to == entry.to }
    }

    // 2) Rename seeds — chỉ nếu tuple (oldFrom, oldTo) vẫn nguyên bản.
    for rule in DefaultMacros.renamedSeedsV1ToV2 {
      if let idx = macros.firstIndex(where: { $0.from == rule.oldFrom && $0.to == rule.oldTo }) {
        macros[idx] = Macro(from: rule.newFrom, to: rule.newTo)
      }
    }

    // 3) Add new entries user chưa có. 1.5.7: dedupe theo cả `from`
    //    lẫn `to` — nếu user đã tự đặt macro với `to` giống default
    //    (vd `vietnam → Việt Nam` thay vì `vn → Việt Nam`), không thêm
    //    bản default nữa để tránh duplicate `to`.
    let existingFroms = Set(macros.map { $0.from })
    let existingTos = Set(macros.map { $0.to })
    for newMacro in DefaultMacros.allDefaults {
      if existingFroms.contains(newMacro.from) { continue }
      if existingTos.contains(newMacro.to)     { continue }
      macros.append(newMacro)
    }

    Defaults[.macros] = macros
    Defaults[.defaultMacrosVersion] = 2
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
