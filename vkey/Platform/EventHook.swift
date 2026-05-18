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

  // Sets up the event tap to listen for keyboard and mouse events.
  func setupEventTap(give appState: AppState) {
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
    self.appState = appState
  }

  // Unregisters the event tap from the run loop.
  func unregisterEventTap(_ eventTap: CFMachPort) {
    if let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    }
  }
}

// Callback function for the event tap.
func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passRetained(event) }
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
    return Unmanaged.passRetained(event)
  }

  // Ignore keystrokes not from hardware (HID system state).
  if event.getIntegerValueField(.eventSourceStateID) != 1 {
    return Unmanaged.passRetained(event)
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
    return Unmanaged.passRetained(event)
  }

  // ── Modifier-only hotkey detection ────────────────────────────────────────
  // The user can configure a pure-modifier combo (e.g. ⌃⇧) to toggle Vi/En.
  // Carbon's RegisterEventHotKey can't bind to modifiers alone, so we watch
  // .flagsChanged events directly and trigger on press→release without an
  // intervening keyDown.
  let modifierTarget = UInt64(Defaults[.modifierOnlyToggleHotkey])
  if modifierTarget != 0 {
    if type == .flagsChanged {
      let currentMods = event.flags.rawValue & kModifierMask
      if currentMods == modifierTarget && eventHook.modifierArmedMask == 0 {
        // Target combo exactly pressed — arm
        eventHook.modifierArmedMask = modifierTarget
        eventHook.modifierKeyUsedDuringArm = false
      } else if eventHook.modifierArmedMask != 0 && currentMods != modifierTarget {
        // Some modifier was released or extra modifier added — fire if clean
        let fire = !eventHook.modifierKeyUsedDuringArm
        eventHook.modifierArmedMask = 0
        eventHook.modifierKeyUsedDuringArm = false
        if fire, let appState = eventHook.appState {
          DispatchQueue.main.async {
            appState.setEnabled(set: !appState.enabled)
          }
        }
      }
    } else if type == .keyDown && eventHook.modifierArmedMask != 0 {
      // Any keyDown while armed disqualifies this press as a "pure" toggle
      eventHook.modifierKeyUsedDuringArm = true
    }
  }

  if type == .keyDown && eventHook.processing {
    return input.handleEvent(event: event)
  } else if type == .leftMouseDown || type == .rightMouseDown {
    input.newWord()
  }

  return Unmanaged.passRetained(event)
}
