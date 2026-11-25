import ApplicationServices
import Cocoa
import Defaults
import Foundation
import os.log

private let hookLog = OSLog(subsystem: "dev.longht.vkey", category: "EventHook")

// EventHook manages the global CGEvent tap and routes keyboard/mouse events
// through InputProcessor, SecureInputMonitor, RemoteInputPolicy, and ModifierHotkeyTracker.
class EventHook {

  var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  var inputProcessor: InputProcessor
  var processing = false
  weak var appState: AppState?

  /// Tracks how many times the tap has been auto-recovered.
  var tapRecoveryCount = 0

  /// v3.2: cache trạng thái quyền Accessibility — false → passthrough ngay, không gọi AX.
  var trustedCache = true

  private var tapSetupRetries = 0
  var onTapSetupFailed: (() -> Void)?

  /// PID đích của event gần nhất (cache bundle ID để tránh lookup lặp).
  var lastEventTargetPID: pid_t = 0
  var lastEventTargetBundleId: String?

  // MARK: - Extracted Subsystems

  let secureInputMonitor = SecureInputMonitor()
  private var remoteInputPolicy = RemoteInputPolicy()
  private var modifierHotkeyTracker = ModifierHotkeyTracker()

  /// Kết quả `standsAsideForRemoteDesktop` gần nhất (đồng bộ trên main thread).
  private(set) var lastStandsAsideForRemoteDesktop = false

  // MARK: - Compatibility Accessors (for tests & watchdog)

  var secureInputOwnerPID: pid_t? {
    get { secureInputMonitor.ownerPID }
    set { secureInputMonitor.ownerPID = newValue }
  }

  var modifierArmedMask: UInt64 {
    get { modifierHotkeyTracker.armedMask }
    set { modifierHotkeyTracker.armedMask = newValue }
  }

  var modifierKeyUsedDuringArm: Bool {
    get { modifierHotkeyTracker.keyUsedDuringArm }
    set { modifierHotkeyTracker.keyUsedDuringArm = newValue }
  }

  var lastUserInputWasRemote: Bool {
    remoteInputPolicy.lastUserInputWasRemote
  }

  static var remoteDesktopViewerBundles: Set<String> {
    AppCompatibilityRegistry.remoteDesktopViewerBundles
  }

  // MARK: - Init & Lifecycle

  init(inputProcessor: InputProcessor) {
    self.inputProcessor = inputProcessor
    syncHardwareShiftFromSystem()
  }

  deinit {
    destroy()
  }

  /// Đồng bộ trạng thái Shift phần cứng vào `inputProcessor.hardwareShiftDown`.
  func syncHardwareShiftFromSystem() {
    inputProcessor.hardwareShiftDown = RemoteInputPolicy.resyncedShiftState(
      lastInputWasRemote: remoteInputPolicy.lastUserInputWasRemote,
      hidShiftDown: CGEventSource.flagsState(.hidSystemState).contains(.maskShift))
  }

  /// Bật lại tap sau khi hệ thống vô hiệu nó, rồi resync bộ đệm & Shift.
  func recoverTap() {
    guard let eventTap else { return }
    CGEvent.tapEnable(tap: eventTap, enable: true)
    resyncAfterTapGap()
    tapRecoveryCount += 1
  }

  /// Sau khoảng tap tắt: bỏ từ đang gõ dở, huỷ chờ viết hoa, đọc lại Shift phần cứng.
  func resyncAfterTapGap() {
    inputProcessor.newWord()
    inputProcessor.resetSentenceCapitalizeState()
    syncHardwareShiftFromSystem()
  }

  func setEnabled(_ value: Bool) {
    // v4.22: chỉ reset khi trạng thái THẬT SỰ đổi.
    let changed = self.processing != value
    self.processing = value
    if changed { self.inputProcessor.newWord() }
  }

  func isTrusted(prompt: Bool = true) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt as CFBoolean]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }

  func destroy() {
    if let eventTap = eventTap {
      CFMachPortInvalidate(eventTap)
      unregisterEventTap(eventTap)
    }
  }

  /// v3.2: quyền Accessibility bị thu hồi → tháo tap ngay để không kẹt input hệ thống.
  func suspendAfterRevocation() {
    trustedCache = false
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
      unregisterEventTap(eventTap)
    }
  }

  func setupEventTap(give appState: AppState) {
    if eventTap != nil {
      self.appState = appState
      return
    }

    let eventMask =
      (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
      | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventTapCallback,
        userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
      )
    else {
      os_log("Failed to create event tap", log: hookLog, type: .error)
      if tapSetupRetries < 3 {
        tapSetupRetries += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
          self?.setupEventTap(give: appState)
        }
      } else {
        tapSetupRetries = 0
        onTapSetupFailed?()
      }
      return
    }

    tapSetupRetries = 0
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    self.eventTap = eventTap
    self.runLoopSource = runLoopSource
    self.appState = appState
    self.trustedCache = true
    syncHardwareShiftFromSystem()
  }

  func unregisterEventTap(_ eventTap: CFMachPort) {
    if let source = self.runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    }
    self.runLoopSource = nil
    self.eventTap = nil
  }

  // MARK: - Remote Desktop Stand-Aside & Policy Bridges

  @discardableResult
  func updateRemoteDesktopStandAside(frontmostBundle: String?) -> Bool {
    let standsAside = RemoteInputPolicy.standsAsideForRemoteDesktop(
      frontmostBundle: frontmostBundle,
      userState: frontmostBundle.flatMap { appState?.smartSwitchConfig(for: $0)?.state })
    guard lastStandsAsideForRemoteDesktop != standsAside else { return standsAside }
    lastStandsAsideForRemoteDesktop = standsAside
    inputProcessor.newWord()
    inputProcessor.resetSentenceCapitalizeState()
    modifierHotkeyTracker.reset()
    if let appState {
      DispatchQueue.main.async { appState.remoteDesktopStandAside = standsAside }
    }
    return standsAside
  }

  func isUserInput(_ event: CGEvent) -> Bool {
    remoteInputPolicy.isUserInput(event)
  }

  @discardableResult
  func handleModifierOnlyHotkey(
    type: CGEventType,
    currentMods: UInt64,
    modifierTarget: UInt64
  ) -> Bool {
    modifierHotkeyTracker.handle(type: type, currentMods: currentMods, modifierTarget: modifierTarget)
  }

  func reconcileSecureInput(systemFlag: Bool, lockShown: Bool) -> Bool {
    secureInputMonitor.reconcile(systemFlag: systemFlag, lockShown: lockShown)
  }

  func secureInputWarningHolder(systemFlag: Bool) -> String? {
    secureInputMonitor.warningHolder(systemFlag: systemFlag)
  }

  // MARK: - Static Forwarders (preserve existing API for tests)

  static func systemSecureInputOwnerPID() -> pid_t? {
    SecureInputMonitor.systemSecureInputOwnerPID()
  }

  static func isBackgroundSecureInputHolder(
    ownerPID: pid_t?, ownerBundle: String?, ownerIsRegularApp: Bool,
    frontmostPID: pid_t?, frontmostBundle: String?, ownPID: pid_t
  ) -> Bool {
    SecureInputMonitor.isBackgroundHolder(
      ownerPID: ownerPID, ownerBundle: ownerBundle, ownerIsRegularApp: ownerIsRegularApp,
      frontmostPID: frontmostPID, frontmostBundle: frontmostBundle, ownPID: ownPID)
  }

  static func backgroundSecureInputHolderApp(
    frontmost: NSRunningApplication?
  ) -> NSRunningApplication? {
    SecureInputMonitor.backgroundHolderApp(frontmost: frontmost)
  }

  static func shouldWarnAboutSecureInputHolder(
    ownerPID: pid_t?, ownPID: pid_t, screenLocked: Bool,
    standingAsideForPasswordEntry: @autoclosure () -> Bool
  ) -> Bool {
    SecureInputMonitor.shouldWarnAboutHolder(
      ownerPID: ownerPID, ownPID: ownPID, screenLocked: screenLocked,
      standingAsideForPasswordEntry: standingAsideForPasswordEntry())
  }

  static func isScreenLocked() -> Bool {
    SecureInputMonitor.isScreenLocked()
  }

  static func resolveSecureInput(
    systemFlag: Bool, knownOwner: pid_t?,
    backgroundHolder: @autoclosure () -> pid_t?,
    frontmostPID: pid_t?,
    frontField: @autoclosure () -> Focused.SecureFieldState,
    frontmostHidesPasswordPrompts: Bool
  ) -> (isSecure: Bool, owner: pid_t?) {
    SecureInputMonitor.resolve(
      systemFlag: systemFlag, knownOwner: knownOwner, backgroundHolder: backgroundHolder(),
      frontmostPID: frontmostPID, frontField: frontField(),
      frontmostHidesPasswordPrompts: frontmostHidesPasswordPrompts)
  }

  static func standsAsideForRemoteDesktop(
    frontmostBundle: String?, userState: @autoclosure () -> AppSmartSwitchState?
  ) -> Bool {
    RemoteInputPolicy.standsAsideForRemoteDesktop(
      frontmostBundle: frontmostBundle, userState: userState())
  }

  static func isPrecomposedRemoteText(_ payload: String) -> Bool {
    RemoteInputPolicy.isPrecomposedRemoteText(payload)
  }

  static func unicodePayload(of event: CGEvent) -> String {
    RemoteInputPolicy.unicodePayload(of: event)
  }

  static func isUserInputSource(
    stateID: Int64, sourcePID: pid_t, ownPID: pid_t,
    pathForPID: (pid_t) -> String?
  ) -> Bool {
    RemoteInputPolicy.isUserInputSource(
      stateID: stateID, sourcePID: sourcePID, ownPID: ownPID, pathForPID: pathForPID)
  }

  static func executablePath(of pid: pid_t) -> String? {
    RemoteInputPolicy.executablePath(of: pid)
  }

  static func resyncedShiftState(lastInputWasRemote: Bool, hidShiftDown: Bool) -> Bool? {
    RemoteInputPolicy.resyncedShiftState(
      lastInputWasRemote: lastInputWasRemote, hidShiftDown: hidShiftDown)
  }
}

// MARK: - Event Tap Callback

/// Bọc toàn bộ xử lý trong `autoreleasepool` vì callback chạy như source của main run loop
/// trên app menu bar (không xả AppKit pool khi người dùng gõ ở app khác).
func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  autoreleasepool {
    handleTapEvent(type: type, event: event, refcon: refcon)
  }
}

private func handleTapEvent(
  type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let eventHook = Unmanaged<EventHook>.fromOpaque(refcon).takeUnretainedValue()

  // Auto-recover when macOS disables the event tap
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    let stillTrusted = AXIsProcessTrusted()
    eventHook.trustedCache = stillTrusted
    if stillTrusted, eventHook.eventTap != nil {
      eventHook.recoverTap()
      #if DEBUG
      print("[vkey] Event tap was disabled by system (\(type == .tapDisabledByTimeout ? "timeout" : "user input")), auto-recovered (count: \(eventHook.tapRecoveryCount))")
      #endif
    }
    return Unmanaged.passUnretained(event)
  }

  if !eventHook.trustedCache {
    return Unmanaged.passUnretained(event)
  }

  if !eventHook.isUserInput(event) {
    return Unmanaged.passUnretained(event)
  }

  if type == .flagsChanged {
    eventHook.inputProcessor.hardwareShiftDown = event.flags.contains(.maskShift)
  }

  let input = eventHook.inputProcessor

  // ── Secure Input ──────────────────────────────────────────────────────────
  let rawSecureInput = CGSIsSecureEventInputSet()
  let frontmostApp = NSWorkspace.shared.frontmostApplication
  let frontmostBundle = frontmostApp?.bundleIdentifier

  let isSecureInput = eventHook.secureInputMonitor.evaluateForEvent(
    systemFlag: rawSecureInput,
    frontmostApp: frontmostApp
  )

  if let appState = eventHook.appState, appState.secureInputActive != isSecureInput {
    if isSecureInput {
      input.newWord()
    }
    DispatchQueue.main.async {
      appState.secureInputActive = isSecureInput
    }
  }

  if isSecureInput {
    return Unmanaged.passUnretained(event)
  }

  // ── Remote Desktop Stand-Aside ────────────────────────────────────────────
  if eventHook.updateRemoteDesktopStandAside(frontmostBundle: frontmostBundle) {
    return Unmanaged.passUnretained(event)
  }

  // ── Modifier-only Hotkey ──────────────────────────────────────────────────
  let toggleTarget = UInt64(Defaults[.modifierOnlyToggleHotkey])
  if toggleTarget != 0 {
    let currentMods = event.flags.rawValue & ModifierHotkeyTracker.trackedModifierMask
    if eventHook.handleModifierOnlyHotkey(
      type: type, currentMods: currentMods, modifierTarget: toggleTarget),
      let appState = eventHook.appState
    {
      DispatchQueue.main.async {
        appState.setEnabledByUser(!appState.enabled)
      }
    }
  }

  // ── Focus Tracking & Smart Switch ─────────────────────────────────────────
  // ⚠️ v4.28: chụp AX trước → phân giải activeApp ưu tiên bundle AX focused element,
  // overlay Spotlight thắng khi Smart Switch bật, event-target chỉ fallback khi AX hụt.
  if let appState = eventHook.appState {
    if type == .keyDown {
      appState.syncFocusedContextForKeystroke()
    }

    let isInputInteraction =
      type == .keyDown || type == .leftMouseDown || type == .rightMouseDown
    if isInputInteraction {
      let targetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
      if targetPID > 0 {
        EventSimulator.axTargetPID = targetPID
        if targetPID != eventHook.lastEventTargetPID {
          eventHook.lastEventTargetPID = targetPID
          eventHook.lastEventTargetBundleId =
            NSRunningApplication(processIdentifier: targetPID)?.bundleIdentifier
        }
      }

      var focusedBid = appState.currentFocusedBundleId ?? eventHook.lastEventTargetBundleId
      if Defaults[.smartSwitchEnabled],
         let ov = AXDirectInjector.focusedOverlayBundle()
      {
        focusedBid = ov
      }
      if let focusedBid {
        let resolved = AppCompatibilityRegistry.canonicalAppBundle(
          focused: focusedBid, frontmost: frontmostBundle)
        if resolved != input.activeApp {
          input.changeActiveApp(resolved)
          appState.noteFocusedBundleId(resolved)
        }
      }
    }

    var isFocusShiftingKey = false
    if type == .keyDown {
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      if keyCode == 48 || keyCode == 36 || keyCode == 53 || (keyCode >= 123 && keyCode <= 126) {
        isFocusShiftingKey = true
      }
    }

    let isCommandCombo = type == .keyDown && event.flags.contains(.maskCommand)
    if type == .leftMouseDown || type == .rightMouseDown || isFocusShiftingKey || isCommandCombo {
      appState.refreshFocusedBundleIdAsync()
    }

    if Defaults[.smartSwitchEnabled], isInputInteraction,
       let rawFocusedBundleId = appState.currentFocusedBundleId
    {
      appState.applySmartSwitchIfNeeded(
        forFocusedBundle: rawFocusedBundleId,
        frontmostBundle: frontmostBundle
      )
    }
  }

  // ── Route to InputProcessor ───────────────────────────────────────────────
  let skipVietnameseIME = frontmostBundle == Bundle.main.bundleIdentifier

  if type == .keyDown && eventHook.processing && !skipVietnameseIME {
    if event.getIntegerValueField(.eventSourceStateID) != 1,
       RemoteInputPolicy.isPrecomposedRemoteText(RemoteInputPolicy.unicodePayload(of: event))
    {
      input.newWord()
      return Unmanaged.passUnretained(event)
    }
    return input.handleEvent(event: event)
  } else if type == .leftMouseDown || type == .rightMouseDown {
    input.newWord()
    input.resetSentenceCapitalizeState()
  }

  return Unmanaged.passUnretained(event)
}
