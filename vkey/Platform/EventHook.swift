import ApplicationServices
import Cocoa
import Defaults
import Foundation
import os.log

/// v2.14: log chẩn đoán nhận diện app đích (xem qua `log stream`).
private let hookLog = OSLog(subsystem: "dev.longht.vkey", category: "EventHook")

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

  /// v2.10: số lần retry tạo tap khi `tapCreate` fail dù app tưởng có quyền
  /// (TCC mismatch sau update đổi chữ ký). Trước đây fail im lặng → user thấy
  /// "bật V" mà không gõ được ở mọi app.
  private var tapSetupRetries = 0
  /// v2.10: callback khi tap vẫn fail sau khi retry — AppDelegate hiện alert
  /// hướng dẫn re-grant Accessibility (tái dùng `showAccessibilityHelpAlert`).
  var onTapSetupFailed: (() -> Void)?

  /// v2.11: PID đích của event gần nhất — đọc trực tiếp từ event
  /// (`.eventTargetUnixProcessID`, WindowServer điền sẵn). Cache bundleId
  /// để chỉ lookup NSRunningApplication khi PID đổi (rẻ, không AX).
  var lastEventTargetPID: pid_t = 0
  var lastEventTargetBundleId: String?

  /// State for modifier-only hotkey detection (e.g. press Shift+Control then
  /// release without any key in between → toggle Vi/En). Tracking is done
  /// inside the event tap so it works while another app has focus and
  /// even while secure input is *not* active (it bypasses during secure input
  /// just like the normal IME path).
  var modifierArmedMask: UInt64 = 0  // current latched target, 0 = not armed
  var modifierKeyUsedDuringArm = false

  /// PID of the app that owns the currently active system-wide secure input,
  /// recorded at the off→on transition. `CGSIsSecureEventInputSet` is global,
  /// so when a background app keeps a focused password field the flag stays on
  /// even after the user switches apps. We scope private mode to this owner so
  /// vkey resumes normal typing in other apps. `nil` while secure input is off.
  var secureInputOwnerPID: pid_t?

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
    return processModifierTargets(type: type, currentMods: currentMods, targets: [modifierTarget])
      == modifierTarget
  }

  /// 2.0.2 (J3): support nhiều modifier-only targets cùng lúc (vd VI/EN
  /// + Text Tools). Logic: armed theo target khớp currentMods. Khi release
  /// (currentMods == 0) trả về target đã armed (nếu key chưa được dùng).
  /// Return 0 = không trigger; non-zero = mask của target vừa fire.
  @discardableResult
  func processModifierTargets(
    type: CGEventType,
    currentMods: UInt64,
    targets: [UInt64]
  ) -> UInt64 {
    // Bỏ targets = 0 và duplicate.
    let validTargets = Array(Set(targets.filter { $0 != 0 }))
    guard !validTargets.isEmpty else { return 0 }

    if type == .flagsChanged {
      // Khi chưa armed, check xem currentMods có match target nào không.
      if modifierArmedMask == 0 {
        if validTargets.contains(currentMods) {
          modifierArmedMask = currentMods
          modifierKeyUsedDuringArm = false
        }
        return 0
      }

      // Đang armed. Check extra modifier ngoài armedMask → cancel.
      let armedMask = modifierArmedMask
      let hasExtraModifier = (currentMods & ~armedMask) != 0
      if hasExtraModifier {
        modifierArmedMask = 0
        modifierKeyUsedDuringArm = false
        return 0
      }

      if currentMods == 0 {
        let fire = !modifierKeyUsedDuringArm
        modifierArmedMask = 0
        modifierKeyUsedDuringArm = false
        return fire ? armedMask : 0
      }

      // Một phần của combo được thả — đợi tất cả modifiers up.
      return 0
    }

    if type == .keyDown && modifierArmedMask != 0 {
      modifierKeyUsedDuringArm = true
    }

    return 0
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
      // v2.10: tap fail dù `isTrusted()` có thể vẫn true (TCC entry cũ sau khi
      // update đổi chữ ký). Retry vài lần (TCC có thể đang settle) rồi báo user
      // thay vì chết im lặng với toggle "bật".
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
  // `CGSIsSecureEventInputSet` is a *system-wide* flag: it stays on while ANY
  // app (even a background one) keeps a focused password field. Treating that
  // raw flag as "be private" left vkey stuck in private mode after the user
  // switched away from the app holding the password window. Instead we scope
  // private mode to whoever actually owns the secure input right now:
  //   • record the owning app at the off→on transition;
  //   • stay private only while that owner is frontmost, OR the frontmost app's
  //     focused element is itself a secure field (front app opened its own
  //     password box, so ownership moves to it).
  // This keeps Terminal `sudo` working (owner == Terminal, exposes no secure
  // subrole) while following the active app everywhere else.
  let rawSecureInput = CGSIsSecureEventInputSet()
  let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

  let isSecureInput: Bool
  if rawSecureInput {
    if eventHook.secureInputOwnerPID == nil {
      // First event after secure input turned on (or it was already on at
      // launch): the frontmost app is the owner.
      eventHook.secureInputOwnerPID = frontmostPID
    }
    if eventHook.secureInputOwnerPID == frontmostPID {
      isSecureInput = true
    } else if Focused.isSecureField() {
      // Front app has its own password field focused — ownership moves to it.
      eventHook.secureInputOwnerPID = frontmostPID
      isSecureInput = true
    } else {
      // Secure input belongs to a background app; keep typing here.
      isSecureInput = false
    }
  } else {
    eventHook.secureInputOwnerPID = nil
    isSecureInput = false
  }

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
  // The user can configure pure-modifier combos (e.g. ⇧⌥ for Vi/En toggle,
  // ⌃⇧ for Text Tools menu). Carbon's RegisterEventHotKey can't bind to
  // modifiers alone, so we watch .flagsChanged events directly and trigger
  // on press→release without an intervening keyDown.
  // 2.0.2 (J3): support 2 modifier-only targets song song.
  let toggleTarget = UInt64(Defaults[.modifierOnlyToggleHotkey])
  let textToolsTarget = UInt64(Defaults[.modifierOnlyTextToolsHotkey])
  if toggleTarget != 0 || textToolsTarget != 0 {
    let currentMods = event.flags.rawValue & kModifierMask
    let firedMask = eventHook.processModifierTargets(
      type: type,
      currentMods: currentMods,
      targets: [toggleTarget, textToolsTarget]
    )
    if firedMask != 0 {
      if firedMask == toggleTarget, let appState = eventHook.appState {
        DispatchQueue.main.async {
          appState.setEnabled(set: !appState.enabled)
        }
      } else if firedMask == textToolsTarget {
        DispatchQueue.main.async {
          TextConversionService.shared.openMenu(near: nil)
        }
      }
    }
  }

  // ── Focus Tracking & Smart Switch Overlay Probing ──────────────────────────
  // 1.7.x: KHÔNG gọi AX đồng bộ trong callback. Đọc `currentFocusedBundleId`
  // do AppState cache (cập nhật bởi NSWorkspace.didActivateApplicationNotification).
  // Trên mouse-click hoặc phím chuyển focus, trigger async refresh.
  if let appState = eventHook.appState {
    // v2.11: xác định app ĐÍCH của event bằng PID đọc TỪ CHÍNH EVENT —
    // nguồn chính xác duy nhất cho overlay UIElement như Spotlight (Tahoe):
    // không phát didActivateApplicationNotification, còn AX refresh thì race
    // (chạy lúc ⌘Space keyDown, TRƯỚC khi overlay mở). v2.10 dựa vào 2 đường
    // đó nên sending strategy không bao giờ được áp cho Spotlight → ký tự đôi.
    if type == .keyDown || type == .leftMouseDown || type == .rightMouseDown {
      let targetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
      if targetPID > 0 {
        // v2.15: cập nhật PID đích cho axDirect (đường fallback khi system-wide
        // không cho focused element).
        EventSimulator.axTargetPID = targetPID
        if targetPID != eventHook.lastEventTargetPID {
          eventHook.lastEventTargetPID = targetPID
          eventHook.lastEventTargetBundleId =
            NSRunningApplication(processIdentifier: targetPID)?.bundleIdentifier
        }
        if let bid = eventHook.lastEventTargetBundleId, bid != input.activeApp {
          input.changeActiveApp(bid)
          // Đồng bộ luôn cache focused-bundle để Smart Switch per-keystroke
          // (block bên dưới) thấy đúng app đích — vd Spotlight auto-English
          // theo config mặc định giờ mới thực sự hoạt động trong overlay.
          appState.noteFocusedBundleId(bid)
        }
      }
    }

    var isFocusShiftingKey = false
    if type == .keyDown {
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      // Tab (48), Enter (36), Esc (53), Up (126), Down (125), Left (123), Right (124)
      if keyCode == 48 || keyCode == 36 || keyCode == 53 || (keyCode >= 123 && keyCode <= 126) {
        isFocusShiftingKey = true
      }
    }

    // v2.10: ⌘-combo (⌘Space mở Spotlight, ⌘Tab đổi app…) cũng có thể chuyển
    // focus sang overlay không fire NSWorkspace notification → trigger refresh.
    let isCommandCombo = type == .keyDown && event.flags.contains(.maskCommand)

    if type == .leftMouseDown || type == .rightMouseDown || isFocusShiftingKey
      || isCommandCombo {
      appState.refreshFocusedBundleIdAsync()
    }

    // v2.10: đồng bộ sending strategy theo FOCUSED bundle — overlay (Spotlight)
    // có thể không kích hoạt activeApplicationDidChange nên strategy bị kẹt ở
    // app cũ → backspace/replace sai. Guard `!=` nên chỉ chạy khi focus đổi
    // thật, không reset tracker mỗi phím.
    if type == .keyDown,
       let focusedBundleId = appState.currentFocusedBundleId,
       focusedBundleId != input.activeApp {
      input.changeActiveApp(focusedBundleId)
    }

    if Defaults[.smartSwitchEnabled],
       (type == .keyDown || type == .leftMouseDown || type == .rightMouseDown) {
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
  }

  if type == .keyDown && eventHook.processing {
    return input.handleEvent(event: event)
  } else if type == .leftMouseDown || type == .rightMouseDown {
    input.newWord()
  }

  return Unmanaged.passUnretained(event)
}
