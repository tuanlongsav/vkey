//
//  AppState.swift
//  vkey
//
//  Created by KhanhIceTea on 20/02/2024.
//

import Cocoa
import Combine
import Defaults
import Foundation
import KeyboardShortcuts
import os.log

private let appLog = OSLog(subsystem: "dev.longht.vkey", category: "AppState")

class AppState: ObservableObject {

  /// When true, the next `enabled` mutation skips persistence into `appModes`.
  private var skipPersistAppMode = false
  public var smartSwitchActive = false
  public var enabledBeforeSmartSwitch = false
  private var skipHUDNotification = true

  /// Callback hiển thị Toggle HUD (do `AppDelegate` gắn để `AppState` không phụ thuộc trực tiếp vào tầng HUD).
  var onToggleHUD: ((Bool) -> Void)?

  // 2.0 (B2): theo dõi non-Latin IME để tự động disable vkey.
  private let inputSourceMonitor = InputSourceMonitor()
  public private(set) var nonLatinIMEActive = false
  private var enabledBeforeNonLatinIME = false

  @Published public var enabled = false {
    didSet {
      if !skipPersistAppMode {
        self.appModes[self.activeAppName] = enabled
      }
      self.eventHook.setEnabled(enabled)

      if !skipHUDNotification, let onToggleHUD {
        let current = self.enabled
        DispatchQueue.main.async {
          onToggleHUD(current)
        }
      }
    }
  }

  @Published public var typingMethod: TypingMethods {
    didSet {
      self.inputProcessor.changeTypingMethod(newMethod: typingMethod)
      Defaults[.typingMethod] = typingMethod
    }
  }

  @Published public var allowedZWJF: Bool {
    didSet {
      Defaults[.allowedZWJF] = allowedZWJF
    }
  }

  @Published public var secureInputActive = false
  @Published public var secureInputHolderName: String?
  @Published public var remoteDesktopStandAside = false

  /// App mà người dùng vừa tự đổi V/E; Smart Switch tôn trọng tới khi chuyển app khác.
  public private(set) var manualModeBundleId: String?

  public var inputProcessor: InputProcessor
  public var eventHook: EventHook
  @Published public var appModes: [String: Bool] = [:]
  @Published public var activeAppName = "Unknown"
  public var bundleId: String

  private let focusTracker = FocusContextTracker()

  public var currentFocusedBundleId: String? {
    focusTracker.currentFocusedBundleId
  }

  public var currentFocusedFieldKind: Focused.FieldKind {
    focusTracker.currentFocusedFieldKind
  }

  /// Bản đã giải mã của `Defaults[.appSmartSwitchConfigs]`.
  private let smartSwitchConfigsCache =
    DefaultsDerivedCache<[String: AppSmartSwitchConfig]>(.appSmartSwitchConfigs) {
      Defaults[.appSmartSwitchConfigs]
    }

  init() {
    bundleId = Bundle.main.bundleIdentifier ?? "dev.longht.vkey"

    let defaultMethod = Defaults[.typingMethod]
    typingMethod = defaultMethod
    allowedZWJF = Defaults[.allowedZWJF]

    let processor = InputProcessor(method: defaultMethod)
    inputProcessor = processor
    eventHook = EventHook(inputProcessor: processor)

    focusTracker.onFieldKindChange = { [weak processor] kind in
      processor?.focusedFieldKind = kind
    }

    KeyboardShortcuts.onKeyUp(for: .toggleInputMode) { [weak self] in
      guard let self else { return }
      self.setEnabledByUser(!self.enabled)
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(activeApplicationDidChange),
      name: NSWorkspace.didActivateApplicationNotification, object: nil)

    if let frontmost = NSWorkspace.shared.frontmostApplication,
      let bid = frontmost.bundleIdentifier,
      bid != bundleId
    {
      focusTracker.noteFocusedBundleId(bid)
      focusTracker.refreshAsync()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      self?.skipHUDNotification = false
    }

    inputSourceMonitor.onInputSourceChange = { [weak self] category in
      self?.handleInputSourceCategoryChange(category)
    }
    inputSourceMonitor.start()
  }

  deinit {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  // MARK: - Smart Switch (Unified)

  /// Cấu hình Smart Switch của `bundleId`, tra trên bản đã giải mã sẵn.
  public func smartSwitchConfig(for bundleId: String) -> AppSmartSwitchConfig? {
    smartSwitchConfigsCache.value[bundleId]
  }

  /// Áp một cấu hình Smart Switch đã khớp cho `bundleId`.
  private func applySmartSwitchConfig(
    _ config: AppSmartSwitchConfig,
    for bundleId: String,
    recordFire: Bool
  ) {
    if !smartSwitchActive {
      enabledBeforeSmartSwitch = enabled
      smartSwitchActive = true
      if recordFire {
        UsageStatistics.shared.recordSmartSwitchFire(toApp: bundleId)
      }
    }
    setEnabledWithoutPersist(config.state.enablesVietnamese)
  }

  /// Áp Smart Switch trong event tap cho focused bundle (đã quy chuẩn về app cha).
  public func applySmartSwitchIfNeeded(
    forFocusedBundle rawFocusedBundleId: String,
    frontmostBundle: String?
  ) {
    let focusedBundleId = AppCompatibilityRegistry.canonicalAppBundle(
      focused: rawFocusedBundleId, frontmost: frontmostBundle)
    guard manualModeBundleId != focusedBundleId else { return }

    if let config = smartSwitchConfig(for: focusedBundleId) {
      applySmartSwitchConfig(config, for: focusedBundleId, recordFire: true)
    } else if smartSwitchActive {
      smartSwitchActive = false
      setEnabledWithoutPersist(enabledBeforeSmartSwitch)
    }
  }

  // MARK: - Input Source Monitoring

  private func handleInputSourceCategoryChange(_ category: InputSourceCategory) {
    guard Defaults[.nonLatinIMEAutoDisable] else {
      if nonLatinIMEActive {
        nonLatinIMEActive = false
        setEnabledWithoutPersist(enabledBeforeNonLatinIME)
      }
      return
    }

    switch category {
    case .nonLatin:
      if !nonLatinIMEActive {
        enabledBeforeNonLatinIME = enabled
        nonLatinIMEActive = true
        setEnabledWithoutPersist(false)
        os_log("AppState: non-Latin IME active — vkey disabled", log: appLog, type: .info)
      }
    case .latin, .unknown:
      if nonLatinIMEActive {
        nonLatinIMEActive = false
        setEnabledWithoutPersist(enabledBeforeNonLatinIME)
        os_log(
          "AppState: Latin input source restored — vkey re-enabled to %{public}@",
          log: appLog, type: .info, String(enabledBeforeNonLatinIME))
      }
    }
  }

  // MARK: - Version & Mode Control

  public func isNewAppVersion() -> Bool {
    let storedVersion = Defaults[.currentVersion]
    return storedVersion != "0.1" && Bundle.main.appVersionLong != storedVersion
  }

  public func storeTrustedAppVersion() {
    Defaults[.currentVersion] = Bundle.main.appVersionLong
  }

  public func setTypingMethod(method: TypingMethods) {
    typingMethod = method
  }

  public func setEnabled(set state: Bool) {
    enabled = state
  }

  /// Đổi V/E do người dùng chủ động — ghi nhớ `manualModeBundleId` để Smart Switch tôn trọng.
  public func setEnabledByUser(_ state: Bool) {
    let app = inputProcessor.activeApp
    manualModeBundleId = app.isEmpty ? nil : app
    enabled = state
  }

  @objc func activeApplicationDidChange(notification: Notification) {
    let wasSkippingHUD = skipHUDNotification
    skipHUDNotification = true
    defer { skipHUDNotification = wasSkippingHUD }

    if let activeApp = NSWorkspace.shared.frontmostApplication,
      let appName = activeApp.bundleIdentifier,
      appName != bundleId
    {
      manualModeBundleId = nil
      eventHook.updateRemoteDesktopStandAside(frontmostBundle: appName)

      focusTracker.noteFocusedBundleId(appName)
      focusTracker.refreshAsync()

      activeAppName = appName
      inputProcessor.changeActiveApp(activeAppName)

      if Defaults[.smartSwitchEnabled], let config = smartSwitchConfig(for: appName) {
        applySmartSwitchConfig(config, for: appName, recordFire: false)
        return
      }

      let shouldRestoreBeforeSmartSwitch = smartSwitchActive
      smartSwitchActive = false

      if let appMode = appModes[activeAppName] {
        setEnabled(set: appMode)
      } else if shouldRestoreBeforeSmartSwitch {
        setEnabled(set: enabledBeforeSmartSwitch)
      } else {
        setEnabled(set: enabled)
      }
    }
  }

  // MARK: - Focus Tracking Bridges

  public func noteFocusedBundleId(_ bid: String) {
    focusTracker.noteFocusedBundleId(bid)
  }

  public func syncFocusedContextForKeystroke() {
    focusTracker.syncForKeystroke()
  }

  public func refreshFocusedBundleIdAsync() {
    focusTracker.refreshAsync()
  }

  // MARK: - Migration Bridges (preserve existing test API)

  public static func migrateLegacySmartSwitchApps() {
    StartupMigrations.migrateLegacySmartSwitchApps()
  }

  static func mergingLegacySmartSwitchApps(
    _ legacy: [String], into configs: [String: AppSmartSwitchConfig], now: Date
  ) -> [String: AppSmartSwitchConfig] {
    StartupMigrations.mergingLegacySmartSwitchApps(legacy, into: configs, now: now)
  }

  /// Apply an enabled state change without writing it to per-app memory or showing HUD.
  public func setEnabledWithoutPersist(_ value: Bool) {
    guard enabled != value else { return }
    let wasSkippingHUD = skipHUDNotification
    skipHUDNotification = true
    skipPersistAppMode = true
    enabled = value
    skipPersistAppMode = false
    skipHUDNotification = wasSkippingHUD
  }
}
