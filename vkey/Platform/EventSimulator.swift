//
//  EventSimulator.swift
//  vkey
//
//  Created by KhanhIceTea on 27/3/24.
//

import ApplicationServices
import CoreGraphics
import Defaults
import Foundation
import os.log

/// v2.14: log chẩn đoán đường AX-direct (Spotlight) — xem bằng:
/// `log stream --predicate 'subsystem == "dev.longht.vkey"' --info`
private let axLog = OSLog(subsystem: "dev.longht.vkey", category: "AXDirect")

/// Strategy for sending keyboard events to replace text.
enum SendingStrategy {
  /// Send all characters in a single batch event (fastest, may fail in some apps).
  case batch
  /// Send each character as individual key events (slowest, most compatible).
  case stepByStep
  /// Send as batch but with delays between backspaces (balanced approach).
  case hybrid(backspaceDelayMicroseconds: UInt32)
  /// v2.12: ghi thẳng giá trị ô text qua Accessibility API thay vì gửi event.
  /// Spotlight (inline autocomplete) nuốt/đảo synthetic backspace nên MỌI
  /// strategy event-based đều loạn chữ; ghi AXValue thì nguyên tử, không đụng
  /// event pipeline. Tham khảo gonhanh.org `InjectionMethod.axDirect`.
  case axDirect
}

/// Configuration for per-app event sending strategies.
struct AppSendingConfig {
  /// Bundle ID prefix to match.
  let bundlePrefix: String
  /// Sending strategy for this app.
  let strategy: SendingStrategy
  /// Human-readable name for logging.
  let name: String
}

/// Telemetry for a replacement attempt.
struct EventSendTelemetry {
  let attemptedTransform: Bool
  let createdEvents: Bool
  let usedAsyncQueue: Bool
  let touchedCharacters: Int
}

class EventSimulator {
  /// Dedicated serial queue for event simulation to avoid blocking the event tap callback.
  /// **All** sending strategies dispatch to this queue (since 1.5.0) so the
  /// CGEvent tap callback returns immediately, preventing macOS from disabling
  /// the tap when the system is under load. Earlier versions ran `.batch` sync,
  /// which produced inconsistent semantics across strategies — the tap would
  /// occasionally be blocked long enough to trigger `tapDisabledByTimeout`.
  private static let simulationQueue = DispatchQueue(label: "dev.longht.vkey.eventSimulator", qos: .userInteractive)

  /// v2.3.15: expose dispatch helper for callers (vd InputProcessor commit
  /// path) cần đặt CGEvent posts vào simulationQueue serial.
  static func simulationQueueAsync(_ block: @escaping () -> Void) {
    simulationQueue.async(execute: block)
  }

  /// 2.0 (C4): adaptive flush delay (ms) áp dụng SAU mỗi batch inject —
  /// updated bởi `InputProcessor.changeActiveApp` từ Window Title Rule
  /// `flushDelayMs`. 0 = no delay. Range hợp lệ: 0..500ms.
  ///
  /// Mục đích: tạo cushion giữa các batch injection để tránh race với
  /// app's text engine (Google Docs composition, Chrome address-bar
  /// autocomplete). Giải quyết bug-class "stickiness" mà gonhanh nổi tiếng.
  nonisolated(unsafe) static var adaptiveFlushDelayMs: Int = 0

  /// 2.0 (C4): re-entry counter cho post-flush serialization. Tăng khi
  /// đang post events, giảm khi xong. Tất cả mutation chạy trên
  /// `simulationQueue` (serial) nên không cần atomic.
  nonisolated(unsafe) private static var inflightFlushCount: Int = 0

  static var isFlushInProgress: Bool {
    return inflightFlushCount > 0
  }

  /// 2.0 (C4): wrapper áp dụng adaptive delay sau khi block hoàn thành.
  /// Chỉ áp dụng nếu `cgEventRaceHardeningEnabled` ON và delay > 0.
  /// Gọi từ simulationQueue (serial) nên counter không race.
  static func withAdaptiveFlush<T>(_ work: () -> T) -> T {
    inflightFlushCount += 1
    defer { inflightFlushCount -= 1 }
    let result = work()
    let delay = adaptiveFlushDelayMs
    if delay > 0, Defaults[.cgEventRaceHardeningEnabled] {
      usleep(UInt32(min(500, max(0, delay)) * 1000))
    }
    return result
  }

  /// Hardcoded macOS virtual key codes used by the simulator. US-layout
  /// positions; these are physical-key codes so they work even on QWERTZ /
  /// AZERTY / Dvorak keymaps.
  private enum KeyCode {
    static let delete: CGKeyCode = 0x33      // Backspace / Delete-Left
    static let leftArrow: CGKeyCode = 0x7B
    static let forwardDelete: CGKeyCode = 0x75  // v2.12: xoá suggestion auto-select
  }

  /// Per-app sending strategy configuration.
  /// Apps are checked in order - first match wins.
  /// Apps not listed use the default batch strategy.
  static let appStrategies: [AppSendingConfig] = [
    AppSendingConfig(bundlePrefix: "com.microsoft.Word", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Word"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Excel", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Excel"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Powerpoint", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "PowerPoint"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Outlook", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Outlook"),
    AppSendingConfig(bundlePrefix: "com.microsoft.onenote.mac", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "OneNote"),

    AppSendingConfig(bundlePrefix: "com.apple.Terminal", strategy: .stepByStep, name: "Terminal"),
    AppSendingConfig(bundlePrefix: "com.googlecode.iterm2", strategy: .stepByStep, name: "iTerm2"),
    AppSendingConfig(bundlePrefix: "net.kovidgoyal.kitty", strategy: .stepByStep, name: "Kitty"),
    AppSendingConfig(bundlePrefix: "com.mitchellh.ghostty", strategy: .stepByStep, name: "Ghostty"),
    AppSendingConfig(bundlePrefix: "com.warp.Warp", strategy: .stepByStep, name: "Warp"),
    AppSendingConfig(bundlePrefix: "co.zeit.hyper", strategy: .stepByStep, name: "Hyper"),
    AppSendingConfig(bundlePrefix: "org.tabby", strategy: .stepByStep, name: "Tabby"),
    AppSendingConfig(bundlePrefix: "io.alacritty", strategy: .stepByStep, name: "Alacritty"),

    // Electron apps thường cần stepByStep vì input model phức tạp (composition events
    // không sync với CGEvent injection thông thường).
    AppSendingConfig(bundlePrefix: "com.anthropic.claudefordesktop", strategy: .stepByStep, name: "Claude"),

    // Launchpad / Spotlight search field chạy trong tiến trình Dock. Ô tìm kiếm
    // này có input model nhạy: batch/hybrid backspace+replace không sync → gõ
    // tiếng Việt bị loạn (lặp/mất chữ, dấu sai). stepByStep gửi từng phím nên
    // đồng bộ đúng. (com.apple.Spotlight = tiến trình Spotlight overlay riêng,
    // mặc định auto English qua Smart Switch; Dock thì không nên vẫn cần fix này.)
    AppSendingConfig(bundlePrefix: "com.apple.dock", strategy: .stepByStep, name: "Launchpad/Dock"),

    // v2.12: Spotlight — synthetic backspace bị inline-autocomplete nuốt/đảo
    // bất kể delay (v2.10 stepByStep vẫn lỗi) → ghi thẳng AXValue (axDirect).
    // systemuiserver: các ô text trong menu bar, cùng hành vi (theo gonhanh).
    AppSendingConfig(bundlePrefix: "com.apple.Spotlight", strategy: .axDirect, name: "Spotlight"),
    AppSendingConfig(bundlePrefix: "com.apple.systemuiserver", strategy: .axDirect, name: "SystemUIServer"),
  ]

  static func getStrategy(for bundleId: String) -> SendingStrategy {
    // Per-app override first; otherwise fall back to a conservative hybrid default
    // (light backspace delay) which works for native AppKit apps AND most Electron
    // / web apps that need a beat between backspace and the replacement string.
    // Pure .batch is faster but fails silently on apps like Claude, Notion, Slack.
    return appStrategies.first(where: { bundleId.hasPrefix($0.bundlePrefix) })?.strategy
      ?? .hybrid(backspaceDelayMicroseconds: 800)
  }

  static func getAppName(for bundleId: String) -> String {
    appStrategies.first(where: { bundleId.hasPrefix($0.bundlePrefix) })?.name ?? "Unknown App"
  }

  static func calcKeyStrokes(from: String, to: String) -> (Int, [Character]) {
    let fromChars = Array(from)
    let toChars = Array(to)
    var commonPrefixLength = 0
    let minLength = min(fromChars.count, toChars.count)

    while commonPrefixLength < minLength
      && fromChars[commonPrefixLength] == toChars[commonPrefixLength]
    {
      commonPrefixLength += 1
    }

    let backspaceCount = fromChars.count - commonPrefixLength
    let diffChars = Array(toChars.dropFirst(commonPrefixLength))

    return (backspaceCount, diffChars)
  }

  /// v2.3.8: NFD scalar-aware diff cho `FixAutocompleteApps` (Chrome, Google
  /// Docs, Google Sheets) — apps có thể store Vietnamese text dạng decomposed
  /// (NFD: o + combining ̂) trong khi vkey send NFC (precomposed ô).
  /// Khi đó Shift+Left của browser đếm theo UTF-16 scalar (NFD = 2 cho "ô"),
  /// trong khi grapheme-based diff đếm 1 → selectLeftCount thiếu → replace
  /// sai → bug "google → gooogle" (extra 'o' do combining mark còn sót).
  ///
  /// Fix: compute diff trong NFD scalar space. selectLeft match đúng số scalar
  /// mà browser storage cần Shift+Left.
  ///
  /// Trace ví dụ "gôg" → "googl":
  /// - from NFD: [g, o, ◌̂, g] (4 scalars)
  /// - to   NFD: [g, o, o, g, l] (5 scalars)
  /// - common prefix: 2 (g, o)
  /// - backspaceCount = 4 - 2 = 2
  /// - remaining = [o, g, l] → "ogl"
  /// - Shift+Left ×2 selects [◌̂, g] (NFD storage) → replace "ogl" → "googl" ✓
  static func calcKeyStrokesNFD(from: String, to: String) -> (Int, [Character]) {
    let fromNFD = from.decomposedStringWithCanonicalMapping
    let toNFD = to.decomposedStringWithCanonicalMapping
    let fromScalars = Array(fromNFD.unicodeScalars)
    let toScalars = Array(toNFD.unicodeScalars)
    var commonPrefixLength = 0
    let minLength = min(fromScalars.count, toScalars.count)
    while commonPrefixLength < minLength
      && fromScalars[commonPrefixLength] == toScalars[commonPrefixLength]
    {
      commonPrefixLength += 1
    }
    let backspaceCount = fromScalars.count - commonPrefixLength
    var remainingScalars = String.UnicodeScalarView()
    for s in toScalars.dropFirst(commonPrefixLength) {
      remainingScalars.append(s)
    }
    return (backspaceCount, Array(String(remainingScalars)))
  }

  @discardableResult
  static func sendBackspace(
    _ count: Int,
    source: CGEventSource? = nil,
    delayMicroseconds: UInt32 = 0
  ) -> Bool {
    guard count > 0 else { return true }

    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)

    guard
      let source = eventSource,
      let downEvent = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: true),
      let upEvent = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: false)
    else {
      return false
    }

    downEvent.flags = .maskNonCoalesced
    upEvent.flags = .maskNonCoalesced

    for index in 0..<count {
      downEvent.post(tap: .cgSessionEventTap)
      upEvent.post(tap: .cgSessionEventTap)

      if delayMicroseconds > 0 && index < count - 1 {
        usleep(delayMicroseconds)
      }
    }
    return true
  }

  /// v2.3.15 → v2.3.16: Option+Backspace = delete word (macOS standard).
  /// v2.3.15 chỉ set `.maskAlternate` trên key event — không work ở Notes/
  /// Claude desktop vì app check actual modifier state qua NSEvent. Một số
  /// app chỉ react khi nhận đầy đủ event sequence: Option down → Backspace
  /// down → Backspace up → Option up.
  ///
  /// v2.3.16: gửi proper modifier press/release sequence để simulate đúng
  /// hành vi keyboard thực.
  @discardableResult
  static func sendOptionBackspace(source: CGEventSource? = nil) -> Bool {
    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)
    guard let source = eventSource else { return false }
    let leftOptionKey: CGKeyCode = 0x3A  // 58 = Left Option

    // 1. Press Option key (modifier down)
    if let optionDown = CGEvent(keyboardEventSource: source, virtualKey: leftOptionKey, keyDown: true) {
      optionDown.flags = .maskAlternate
      optionDown.post(tap: .cgSessionEventTap)
    }

    // 2. Press + release Backspace with Option held
    if let bsDown = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: true) {
      bsDown.flags = [.maskAlternate, .maskNonCoalesced]
      bsDown.post(tap: .cgSessionEventTap)
    }
    if let bsUp = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: false) {
      bsUp.flags = [.maskAlternate, .maskNonCoalesced]
      bsUp.post(tap: .cgSessionEventTap)
    }

    // 3. Release Option key (modifier up)
    if let optionUp = CGEvent(keyboardEventSource: source, virtualKey: leftOptionKey, keyDown: false) {
      optionUp.flags = []
      optionUp.post(tap: .cgSessionEventTap)
    }

    return true
  }

  @discardableResult
  static func sendString(_ str: String, source: CGEventSource? = nil) -> Bool {
    guard !str.isEmpty else { return true }

    let uniChars = str.utf16.map { UniChar($0) }
    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)

    guard
      let source = eventSource,
      let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
      let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
    else {
      return false
    }

    downEvent.flags = .maskNonCoalesced
    upEvent.flags = .maskNonCoalesced

    downEvent.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
    upEvent.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)

    downEvent.post(tap: .cgSessionEventTap)
    upEvent.post(tap: .cgSessionEventTap)
    return true
  }

  @discardableResult
  static func sendStringStepByStep(
    _ str: String,
    source: CGEventSource? = nil,
    delayMicroseconds: UInt32 = 500
  ) -> Bool {
    guard !str.isEmpty else { return true }

    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)
    guard let source = eventSource else {
      return sendString(str)
    }

    var createdAnyEvent = false
    let chars = Array(str)
    for (index, char) in chars.enumerated() {
      let uniChars = unicodeUnits(for: char)
      guard !uniChars.isEmpty else { continue }

      if
        let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
        let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
      {
        createdAnyEvent = true
        downEvent.flags = .maskNonCoalesced
        upEvent.flags = .maskNonCoalesced

        downEvent.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
        upEvent.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)

        downEvent.post(tap: .cgSessionEventTap)
        upEvent.post(tap: .cgSessionEventTap)
      }

      if delayMicroseconds > 0 && index < chars.count - 1 {
        usleep(delayMicroseconds)
      }
    }
    return createdAnyEvent
  }

  static func unicodeUnits(for char: Character) -> [UniChar] {
    String(char).utf16.map { UniChar($0) }
  }

  // MARK: - AX-direct injection (v2.12, tham khảo gonhanh.org)

  /// Ghi thẳng giá trị ô text của focused element qua Accessibility API:
  /// xoá `backspaceCount` ký tự (grapheme) TRƯỚC con trỏ rồi chèn `insert`.
  /// - Spotlight auto-select phần suggestion SAU con trỏ (gõ "saf" → "saf|ari"
  ///   với "ari" được select) — phần đó không phải text user gõ, loại bỏ.
  /// - AX trả offset UTF-16; engine đếm grapheme → quy đổi cẩn thận.
  /// - Trả false nếu element không đọc/ghi được → caller fallback synthetic.
  static func axDirectReplace(backspaceCount: Int, insert: String) -> Bool {
    let systemWide = AXUIElementCreateSystemWide()
    // Giới hạn thời gian AX (theo gonhanh v1.0.150) — app đích bận thì fail
    // nhanh để retry/fallback, không treo simulationQueue.
    AXUIElementSetMessagingTimeout(systemWide, 0.1)

    var focusedRef: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
      let ref = focusedRef, CFGetTypeID(ref) == AXUIElementGetTypeID()
    else {
      os_log("axDirect: no focused element", log: axLog, type: .info)
      return false
    }
    let element = ref as! AXUIElement

    var valueRef: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success
    else {
      os_log("axDirect: AXValue unreadable", log: axLog, type: .info)
      return false
    }
    let valueStr = (valueRef as? String) ?? ""
    let valueNS = valueStr as NSString
    let valueLength = valueNS.length

    // Caret + selection (offset UTF-16). Thiếu range → coi caret ở cuối.
    var caret = valueLength
    var selLen = 0
    var rangeRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(
         element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
       let rv = rangeRef, CFGetTypeID(rv) == AXValueGetTypeID() {
      var sel = CFRange()
      if AXValueGetValue(rv as! AXValue, .cfRange, &sel), sel.location >= 0 {
        caret = min(sel.location, valueLength)
        selLen = max(0, sel.length)
      }
    }

    // Vùng thay thế (theo PHTV PHTVAccessibilityService):
    // - selection GIỮA text (user bôi đen) → thay đúng vùng select.
    // - selection Ở CUỐI (suffix autocomplete Spotlight, vd "saf|ari") →
    //   xoá [deleteStart, caret) + cả suffix trong cùng một lần replace.
    var start = caret
    var len = 0
    let selectionAtEnd = selLen > 0 && (caret + selLen == valueLength)
    if selLen > 0 && !selectionAtEnd {
      start = caret
      len = selLen
    } else {
      let deleteStart = axDeleteStart(valueStr, caretUTF16: caret, backspaceCount: backspaceCount)
      start = deleteStart
      len = (caret - deleteStart) + (selectionAtEnd ? selLen : 0)
    }
    if start + len > valueLength { len = valueLength - start }
    if len < 0 { len = 0 }

    let insertNFC = insert.precomposedStringWithCanonicalMapping
    let newValue = valueNS.replacingCharacters(
      in: NSRange(location: start, length: len), with: insertNFC)

    guard
      AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFTypeRef)
        == .success
    else {
      os_log("axDirect: AXValue write REFUSED", log: axLog, type: .info)
      return false
    }

    // Đặt con trỏ ngay sau text vừa chèn.
    var newSel = CFRange(location: start + (insertNFC as NSString).length, length: 0)
    if let newRange = AXValueCreate(.cfRange, &newSel) {
      AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, newRange)
    }

    // v2.14 (theo PHTV): VERIFY khi có xoá — một số app trả success nhưng áp
    // async hoặc âm thầm bỏ. Không verify thì tưởng thành công trong khi field
    // không đổi → "vẫn lỗi" mà không có dấu vết.
    guard backspaceCount > 0 else { return true }
    let wantNFC = newValue.precomposedStringWithCanonicalMapping
    for attempt in 0..<2 {
      var vRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &vRef) == .success {
        let gotNFC = ((vRef as? String) ?? "").precomposedStringWithCanonicalMapping
        if gotNFC == wantNFC { return true }
        // Spotlight có thể đã gắn lại suffix autocomplete mới sau khi ghi.
        if selectionAtEnd && gotNFC.hasPrefix(wantNFC) { return true }
      }
      if attempt == 0 { usleep(2000) }
    }
    os_log("axDirect: verify FAILED (write not applied)", log: axLog, type: .info)
    return false
  }

  /// Lùi từ caret `backspaceCount` "phím xoá" trong không gian UTF-16, coi mỗi
  /// cụm grapheme (base + combining marks, surrogate pair) là MỘT đơn vị —
  /// an toàn với app lưu text dạng NFD (ô = o + ◌̂).
  static func axDeleteStart(_ value: String, caretUTF16: Int, backspaceCount: Int) -> Int {
    guard backspaceCount > 0, caretUTF16 > 0 else { return max(0, caretUTF16) }
    let ns = value as NSString
    var idx = min(caretUTF16, ns.length)
    for _ in 0..<backspaceCount {
      guard idx > 0 else { break }
      idx = ns.rangeOfComposedCharacterSequence(at: idx - 1).location
    }
    return idx
  }

  /// Fallback khi AX fail 3 lần: ForwardDelete xoá suggestion đang auto-select
  /// (gonhanh) → backspace chậm → text từng ký tự. v2.14: post vào HID TAP
  /// (`.cghidEventTap`, theo PHTV `postToHIDTapEnabled`) — Spotlight xử lý
  /// event mức HID đáng tin hơn session tap. Event dùng `.privateState` nên
  /// vẫn bị tap của vkey bỏ qua (eventSourceStateID != 1), không loop.
  private static func sendSpotlightFallback(
    backspaceCount: Int, diffChars: [Character], source: CGEventSource
  ) {
    os_log("axDirect: fallback synthetic (HID tap), bs=%d diff=%d",
           log: axLog, type: .info, backspaceCount, diffChars.count)
    func postHID(_ event: CGEvent?) {
      guard let event else { return }
      event.flags = .maskNonCoalesced
      event.post(tap: .cghidEventTap)
    }
    postHID(CGEvent(keyboardEventSource: source, virtualKey: KeyCode.forwardDelete, keyDown: true))
    postHID(CGEvent(keyboardEventSource: source, virtualKey: KeyCode.forwardDelete, keyDown: false))
    usleep(3000)
    for _ in 0..<backspaceCount {
      postHID(CGEvent(keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: true))
      postHID(CGEvent(keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: false))
      usleep(1000)
    }
    if backspaceCount > 0 { usleep(5000) }
    for ch in diffChars {
      let units = unicodeUnits(for: ch)
      guard !units.isEmpty else { continue }
      let dn = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
      let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
      dn?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
      up?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
      postHID(dn)
      postHID(up)
      usleep(1000)
    }
  }

  static func sendReplacement(
    backspaceCount: Int,
    diffChars: [Character],
    strategy: SendingStrategy
  ) -> EventSendTelemetry {
    let touchedCharacters = backspaceCount + diffChars.count
    guard touchedCharacters > 0 else {
      return EventSendTelemetry(
        attemptedTransform: false,
        createdEvents: true,
        usedAsyncQueue: false,
        touchedCharacters: 0
      )
    }

    switch strategy {
    case .batch:
      // 1.5.0: even .batch now dispatches to simulationQueue so the event tap
      // callback never blocks. Ordering with the user's next keystroke is
      // preserved because simulationQueue is serial and the system queues
      // pending events behind our outgoing post() calls.
      // 2.0 (C4): wrap với withAdaptiveFlush — counter + optional usleep.
      let source = CGEventSource(stateID: .privateState)
      simulationQueue.async {
        _ = withAdaptiveFlush {
          sendBackspace(backspaceCount, source: source, delayMicroseconds: 0)
          sendString(String(diffChars), source: source)
        }
      }
      return EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: touchedCharacters
      )

    case .stepByStep:
      guard let source = CGEventSource(stateID: .privateState) else {
        return EventSendTelemetry(
          attemptedTransform: true,
          createdEvents: false,
          usedAsyncQueue: true,
          touchedCharacters: touchedCharacters
        )
      }
      // Dispatch to background queue to avoid blocking the event tap
      simulationQueue.async {
        _ = withAdaptiveFlush {
          sendBackspace(backspaceCount, source: source, delayMicroseconds: 2000)
          usleep(3000)
          sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 2000)
          usleep(3000)
        }
      }
      return EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: touchedCharacters
      )

    case .axDirect:
      simulationQueue.async {
        _ = withAdaptiveFlush {
          // Spotlight có thể đang bận search → AX call fail thoáng qua; retry
          // 3 lần (5ms/lần, theo gonhanh) rồi mới fallback synthetic.
          for attempt in 0..<3 {
            if attempt > 0 { usleep(5000) }
            if axDirectReplace(backspaceCount: backspaceCount, insert: String(diffChars)) {
              return
            }
          }
          if let source = CGEventSource(stateID: .privateState) {
            sendSpotlightFallback(
              backspaceCount: backspaceCount, diffChars: diffChars, source: source)
          }
        }
      }
      return EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: touchedCharacters
      )

    case .hybrid(let backspaceDelay):
      guard let source = CGEventSource(stateID: .privateState) else {
        return EventSendTelemetry(
          attemptedTransform: true,
          createdEvents: false,
          usedAsyncQueue: true,
          touchedCharacters: touchedCharacters
        )
      }
      // Dispatch to background queue to avoid blocking the event tap
      simulationQueue.async {
        _ = withAdaptiveFlush {
          sendBackspace(backspaceCount, source: source, delayMicroseconds: backspaceDelay)
          sendString(String(diffChars), source: source)
        }
      }
      return EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: touchedCharacters
      )
    }
  }

  /// Sends Shift+Left arrow key events to select text to the left.
  /// This extends any existing selection (including inline autocomplete).
  static func sendShiftLeft(
    _ count: Int,
    source: CGEventSource? = nil
  ) {
    guard count > 0 else { return }

    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)
    guard let source = eventSource else { return }

    guard
      let downEvent = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.leftArrow, keyDown: true),
      let upEvent = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.leftArrow, keyDown: false)
    else { return }

    downEvent.flags = [.maskShift, .maskNonCoalesced]
    upEvent.flags = [.maskShift, .maskNonCoalesced]

    for _ in 0..<count {
      downEvent.post(tap: .cgSessionEventTap)
      upEvent.post(tap: .cgSessionEventTap)
    }
  }

  /// Uses Shift+Left to select characters then types replacement text.
  /// Unlike backspace-based replacement, Shift+Left naturally extends any
  /// existing inline autocomplete selection in browsers, so the replacement
  /// covers both the autocomplete text and the characters being modified.
  static func sendSelectAndReplace(
    selectLeftCount: Int,
    diffChars: [Character],
    strategy: SendingStrategy
  ) -> EventSendTelemetry {
    let touchedCharacters = selectLeftCount + diffChars.count
    guard touchedCharacters > 0 else {
      return EventSendTelemetry(
        attemptedTransform: false,
        createdEvents: true,
        usedAsyncQueue: false,
        touchedCharacters: 0
      )
    }

    switch strategy {
    case .batch:
      // 2.0 (C4): wrap với withAdaptiveFlush.
      let source = CGEventSource(stateID: .privateState)
      simulationQueue.async {
        _ = withAdaptiveFlush {
          sendShiftLeft(selectLeftCount, source: source)
          if !diffChars.isEmpty {
            sendString(String(diffChars), source: source)
          } else if selectLeftCount > 0 {
            sendBackspace(1, source: source)
          }
        }
      }
      return EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: touchedCharacters
      )

    case .stepByStep:
      guard let source = CGEventSource(stateID: .privateState) else {
        return EventSendTelemetry(
          attemptedTransform: true,
          createdEvents: false,
          usedAsyncQueue: true,
          touchedCharacters: touchedCharacters
        )
      }
      simulationQueue.async {
        _ = withAdaptiveFlush {
          sendShiftLeft(selectLeftCount, source: source)
          usleep(3000)
          if !diffChars.isEmpty {
            sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 2000)
          } else if selectLeftCount > 0 {
            sendBackspace(1, source: source)
          }
          usleep(3000)
        }
      }
      return EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: touchedCharacters
      )

    case .axDirect:
      // v2.12: selection-replace ≡ xoá selectLeftCount ký tự trước con trỏ +
      // chèn diff — đúng semantics của axDirectReplace. Fallback Shift+Left.
      simulationQueue.async {
        _ = withAdaptiveFlush {
          for attempt in 0..<3 {
            if attempt > 0 { usleep(5000) }
            if axDirectReplace(backspaceCount: selectLeftCount, insert: String(diffChars)) {
              return
            }
          }
          guard let source = CGEventSource(stateID: .privateState) else { return }
          sendShiftLeft(selectLeftCount, source: source)
          usleep(3000)
          if !diffChars.isEmpty {
            sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 2000)
          } else if selectLeftCount > 0 {
            sendBackspace(1, source: source)
          }
        }
      }
      return EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: touchedCharacters
      )

    case .hybrid(let backspaceDelay):
      guard let source = CGEventSource(stateID: .privateState) else {
        return EventSendTelemetry(
          attemptedTransform: true,
          createdEvents: false,
          usedAsyncQueue: true,
          touchedCharacters: touchedCharacters
        )
      }
      simulationQueue.async {
        _ = withAdaptiveFlush {
          sendShiftLeft(selectLeftCount, source: source)
          usleep(backspaceDelay)
          if !diffChars.isEmpty {
            sendString(String(diffChars), source: source)
          } else if selectLeftCount > 0 {
            sendBackspace(1, source: source)
          }
        }
      }
      return EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: touchedCharacters
      )
    }
  }
}
