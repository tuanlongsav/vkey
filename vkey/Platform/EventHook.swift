import ApplicationServices
import Cocoa
import Defaults
import Foundation

// Private macOS API to detect secure input mode (password fields)
@_silgen_name("CGSIsSecureEventInputSet")
func CGSIsSecureEventInputSet() -> Bool

/// Bit mask of the modifier flags we care about (matches both
/// `CGEventFlags` and `NSEvent.ModifierFlags` bit layouts on macOS).
private let kModifierMask: UInt64 =
  UInt64(NSEvent.ModifierFlags.command.rawValue) |
  UInt64(NSEvent.ModifierFlags.option.rawValue) |
  UInt64(NSEvent.ModifierFlags.control.rawValue) |
  UInt64(NSEvent.ModifierFlags.shift.rawValue)

// EventHook manages keyboard events and interacts with the Telex engine.
class EventHook {

  var eventTap: CFMachPort?
  /// Run-loop source paired with `eventTap`. Stored so `destroy()` and
  /// `unregisterEventTap` can remove the exact source that was added,
  /// instead of creating a fresh (and never-actually-attached) one.
  private var runLoopSource: CFRunLoopSource?
  var keyLayout: KeyboardUS
  var inputProcessor: InputProcessor
  var processing = false
  var appState: AppState?

  /// Tracks how many times the tap has been auto-recovered
  var tapRecoveryCount = 0

  /// State for modifier-only hotkey detection (e.g. press Shift+Control then
  /// release without any key in between → toggle Vi/En). Tracking is done
  /// inside the event tap so it works while another app has focus and
  /// even while secure input is *not* active (it bypasses during secure input
  /// just like the normal IME path).
  var modifierArmedMask: UInt64 = 0  // current latched target, 0 = not armed
  var modifierKeyUsedDuringArm = false

  init(inputProcessor: InputProcessor) {
    self.keyLayout = KeyboardUS()
    self.inputProcessor = inputProcessor
  }

  @discardableResult
  func handleModifierOnlyHotkey(
    type: CGEventType,
    currentMods: UInt64,
    modifierTarget: UInt64
  ) -> Bool {
    guard modifierTarget != 0 else { return false }

    if type == .flagsChanged {
      if currentMods == modifierTarget && modifierArmedMask == 0 {
        modifierArmedMask = modifierTarget
        modifierKeyUsedDuringArm = false
        return false
      }

      guard modifierArmedMask != 0 else { return false }

      let hasExtraModifier = (currentMods & ~modifierTarget) != 0
      if hasExtraModifier {
        modifierArmedMask = 0
        modifierKeyUsedDuringArm = false
        return false
      }

      if currentMods == 0 {
        let fire = !modifierKeyUsedDuringArm
        modifierArmedMask = 0
        modifierKeyUsedDuringArm = false
        return fire
      }

      // The user released part of the target combo. Keep waiting until all
      // target modifiers are up so a normal one-by-one release still toggles.
      return false
    }

    if type == .keyDown && modifierArmedMask != 0 {
      modifierKeyUsedDuringArm = true
    }

    return false
  }

  func setEnabled(_ value: Bool) {
    self.processing = value
    self.inputProcessor.newWord()
  }

  // Checks if the application has accessibility permissions.
  func isTrusted(prompt: Bool = true) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt as CFBoolean]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }

  // Removes the event tap before the application terminates.
  func destroy() {
    if let eventTap = eventTap {
      CFMachPortInvalidate(eventTap)
      unregisterEventTap(eventTap)
    }
  }

  deinit {
    destroy()
  }

  // Sets up the event tap to listen for keyboard and mouse events.
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
      print("Failed to create event tap")
      return
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    self.eventTap = eventTap
    self.runLoopSource = runLoopSource
    self.appState = appState
  }

  /// Unregisters the event tap from the run loop. Uses the run-loop source
  /// captured in `setupEventTap`; creating a fresh source here (the previous
  /// behaviour) would leak the original and remove a source that was never
  /// actually added.
  func unregisterEventTap(_ eventTap: CFMachPort) {
    if let source = self.runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    }
    self.runLoopSource = nil
    self.eventTap = nil
  }
}

// Callback function for the event tap.
func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let eventHook = Unmanaged<EventHook>.fromOpaque(refcon).takeUnretainedValue()

  // Auto-recover when macOS disables the event tap
  // This happens when the tap callback takes too long or the system is under load
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if let eventTap = eventHook.eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: true)
      eventHook.tapRecoveryCount += 1
      #if DEBUG
      print("[vkey] Event tap was disabled by system (\(type == .tapDisabledByTimeout ? "timeout" : "user input")), auto-recovered (count: \(eventHook.tapRecoveryCount))")
      #endif
    }
    return Unmanaged.passUnretained(event)
  }

  // Ignore keystrokes not from hardware (HID system state).
  if event.getIntegerValueField(.eventSourceStateID) != 1 {
    return Unmanaged.passUnretained(event)
  }

  // IME Switcher button on keyboard
  //    if let appState = eventHook.appState,
  //      type == .flagsChanged && (event.flags.contains(.maskSecondaryFn))  // Left Fn
  //    {
  //      appState.setEnabled(set: !appState.enabled)
  //      return nil
  //    }

  let input = eventHook.inputProcessor

  // Check for secure input mode (password fields, Terminal sudo prompts, 1Password, …)
  // When active, macOS forbids reading raw key data — vkey must completely step aside
  // so the user can type their password normally and the app doesn't appear to "eat"
  // keystrokes. We also reset the word buffer at the false→true transition so we don't
  // resume processing with stale state when secure input ends.
  let isSecureInput = CGSIsSecureEventInputSet()
  if let appState = eventHook.appState, appState.secureInputActive != isSecureInput {
    if isSecureInput {
      // Entering secure input: drop any in-progress Vietnamese word so the next
      // resumed session starts clean.
      input.newWord()
    }
    DispatchQueue.main.async {
      appState.secureInputActive = isSecureInput
    }
  }

  // Hard bypass: no Vietnamese processing while secure input is active, regardless
  // of enabled state. The hotkey (Option+Z) is registered via Carbon hotkey through
  // the KeyboardShortcuts library and operates independently of this event tap, so
  // toggling Vi/En still works while the password field is focused.
  if isSecureInput {
    return Unmanaged.passUnretained(event)
  }

  // ── Modifier-only hotkey detection ────────────────────────────────────────
  // The user can configure a pure-modifier combo (e.g. ⌃⇧) to toggle Vi/En.
  // Carbon's RegisterEventHotKey can't bind to modifiers alone, so we watch
  // .flagsChanged events directly and trigger on press→release without an
  // intervening keyDown.
  let modifierTarget = UInt64(Defaults[.modifierOnlyToggleHotkey])
  if modifierTarget != 0 {
    let currentMods = event.flags.rawValue & kModifierMask
    let shouldToggle = eventHook.handleModifierOnlyHotkey(
      type: type,
      currentMods: currentMods,
      modifierTarget: modifierTarget
    )
    if shouldToggle, let appState = eventHook.appState {
      DispatchQueue.main.async {
        appState.setEnabled(set: !appState.enabled)
      }
    }
  }

  // ── Smart Switch Overlay Probing ──────────────────────────────────────────
  // 1.7.x: KHÔNG gọi AX đồng bộ trong callback. Đọc `currentFocusedBundleId`
  // do AppState cache (cập nhật bởi NSWorkspace.didActivateApplicationNotification).
  // Trên mouse-click, trigger async refresh để bắt sub-window focus changes.
  if let appState = eventHook.appState, Defaults[.smartSwitchEnabled],
     (type == .keyDown || type == .leftMouseDown || type == .rightMouseDown) {
    if type == .leftMouseDown || type == .rightMouseDown {
      appState.refreshFocusedBundleIdAsync()
    }
    if let focusedBundleId = appState.currentFocusedBundleId {
      let configs = Defaults[.appSmartSwitchConfigs]
      let desiredEnabled: Bool?
      if let config = configs[focusedBundleId] {
        switch config.state {
        case .disabled, .englishMode: desiredEnabled = false
        case .vietnameseMode:         desiredEnabled = true
        }
      } else if Defaults[.smartSwitchApps].contains(focusedBundleId) {
        desiredEnabled = false
      } else {
        desiredEnabled = nil
      }

      if let desired = desiredEnabled {
        if !appState.smartSwitchActive {
          appState.enabledBeforeSmartSwitch = appState.enabled
          appState.smartSwitchActive = true
          // 1.5.0: record fire for weekly stats. Async-recorded inside
          // UsageStatistics so the event tap callback stays fast.
          UsageStatistics.shared.recordSmartSwitchFire(toApp: focusedBundleId)
        }
        if appState.enabled != desired {
          appState.setEnabledWithoutPersist(desired)
        }
      } else if appState.smartSwitchActive {
        appState.smartSwitchActive = false
        appState.setEnabledWithoutPersist(appState.enabledBeforeSmartSwitch)
      }
    }
  }

  if type == .keyDown && eventHook.processing {
    return input.handleEvent(event: event)
  } else if type == .leftMouseDown || type == .rightMouseDown {
    input.newWord()
  }

  return Unmanaged.passUnretained(event)
}
