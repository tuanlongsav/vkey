//
//  EventSimulator.swift
//  vkey
//
//  Created by KhanhIceTea on 27/3/24.
//

import CoreGraphics
import Foundation
import os.log

private let simLog = OSLog(subsystem: "dev.longht.vkey", category: "AXDirect")

class EventSimulator {
  /// Dedicated serial queue for event simulation to avoid blocking the event tap callback.
  private static let simulationQueue = DispatchQueue(
    label: "dev.longht.vkey.eventSimulator", qos: .userInteractive,
    autoreleaseFrequency: .workItem
  )

  /// Expose dispatch helper for callers needing serial CGEvent posts on `simulationQueue`.
  static func simulationQueueAsync(_ block: @escaping () -> Void) {
    simulationQueue.async(execute: block)
  }

  /// Nguồn `.privateState` DÙNG CHUNG cho mọi phím vkey tự phát.
  /// Tạo mới mỗi lần gửi sẽ rò 16 KB shared memory trong SkyLight (`CGSEventSourceCache`).
  static func privateEventSource() -> CGEventSource? {
    privateSourceLock.lock()
    defer { privateSourceLock.unlock() }
    if let source = sharedPrivateSource { return source }
    sharedPrivateSource = CGEventSource(stateID: .privateState)
    return sharedPrivateSource
  }

  private static let privateSourceLock = NSLock()
  nonisolated(unsafe) private static var sharedPrivateSource: CGEventSource?

  /// Hộp thư một chiều từ tap thread cho PID đích; chụp đồng bộ lúc vào `sendReplacement`.
  nonisolated(unsafe) static var axTargetPID: pid_t = 0

  /// Hardcoded macOS virtual key codes used by the simulator.
  enum KeyCode {
    static let delete: CGKeyCode = 0x33         // Backspace / Delete-Left
    static let forwardDelete: CGKeyCode = 0x75  // Xoá suggestion auto-select
    static let leftOption: CGKeyCode = 0x3A     // Left Option (Option+Backspace)

    /// Mã phím hợp lệ 7-bit cho event CHỈ mang chuỗi Unicode (giữ 0 = phím A;
    /// 0xFF/F16..F20 bị AppKit/Blink bỏ im lặng).
    static let unicodeOnly: CGKeyCode = 0
  }

  /// Gắn chuỗi Unicode lên một event phím, kèm mã phím và cờ chuẩn.
  static func applyUnicodePayload(_ event: CGEvent, units: [UniChar]) {
    event.setIntegerValueField(.keyboardEventKeycode, value: Int64(KeyCode.unicodeOnly))
    event.flags = .maskNonCoalesced
    event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
  }

  static func unicodeUnits(for char: Character) -> [UniChar] {
    String(char).utf16.map { UniChar($0) }
  }

  /// Dựng cặp event keyDown/keyUp mang payload Unicode và post tới `tap`.
  @discardableResult
  private static func postUnicodeUnits(
    _ units: [UniChar],
    source: CGEventSource,
    tap: CGEventTapLocation
  ) -> Bool {
    guard
      let downEvent = CGEvent(
        keyboardEventSource: source, virtualKey: KeyCode.unicodeOnly, keyDown: true),
      let upEvent = CGEvent(
        keyboardEventSource: source, virtualKey: KeyCode.unicodeOnly, keyDown: false)
    else {
      return false
    }
    applyUnicodePayload(downEvent, units: units)
    applyUnicodePayload(upEvent, units: units)
    downEvent.post(tap: tap)
    upEvent.post(tap: tap)
    return true
  }

  // MARK: - Low-level CGEvent Posting

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

  @discardableResult
  static func sendOptionBackspace(source: CGEventSource? = nil) -> Bool {
    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)
    guard let source = eventSource else { return false }

    if let optionDown = CGEvent(
      keyboardEventSource: source, virtualKey: KeyCode.leftOption, keyDown: true)
    {
      optionDown.flags = .maskAlternate
      optionDown.post(tap: .cgSessionEventTap)
    }

    if let bsDown = CGEvent(
      keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: true)
    {
      bsDown.flags = [.maskAlternate, .maskNonCoalesced]
      bsDown.post(tap: .cgSessionEventTap)
    }
    if let bsUp = CGEvent(
      keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: false)
    {
      bsUp.flags = [.maskAlternate, .maskNonCoalesced]
      bsUp.post(tap: .cgSessionEventTap)
    }

    if let optionUp = CGEvent(
      keyboardEventSource: source, virtualKey: KeyCode.leftOption, keyDown: false)
    {
      optionUp.flags = []
      optionUp.post(tap: .cgSessionEventTap)
    }

    return true
  }

  @discardableResult
  static func sendString(_ str: String, source: CGEventSource? = nil) -> Bool {
    guard !str.isEmpty else { return true }

    let uniChars = str.utf16.map { UniChar($0) }
    guard let source = source ?? CGEventSource(stateID: .combinedSessionState) else {
      return false
    }
    return postUnicodeUnits(uniChars, source: source, tap: .cgSessionEventTap)
  }

  @discardableResult
  static func sendStringStepByStep(
    _ str: String,
    source: CGEventSource? = nil,
    delayMicroseconds: UInt32 = 500
  ) -> Bool {
    guard !str.isEmpty else { return true }

    guard let source = source ?? CGEventSource(stateID: .combinedSessionState) else {
      return sendString(str)
    }

    var createdAnyEvent = false
    let chars = Array(str)
    for (index, char) in chars.enumerated() {
      let uniChars = unicodeUnits(for: char)
      guard !uniChars.isEmpty else { continue }

      if postUnicodeUnits(uniChars, source: source, tap: .cgSessionEventTap) {
        createdAnyEvent = true
      }

      if delayMicroseconds > 0 && index < chars.count - 1 {
        usleep(delayMicroseconds)
      }
    }
    return createdAnyEvent
  }

  /// Fallback khi AX fail 3 lần: ForwardDelete xoá suggestion → backspace chậm → text từng ký tự qua HID tap.
  private static func sendSpotlightFallback(
    backspaceCount: Int, diffChars: [Character], source: CGEventSource
  ) {
    os_log(
      "axDirect: fallback synthetic (HID tap), bs=%d diff=%d",
      log: simLog, type: .default, backspaceCount, diffChars.count)
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
      postUnicodeUnits(units, source: source, tap: .cghidEventTap)
      usleep(1000)
    }
  }

  // MARK: - Replacement Dispatch

  static func sendReplacement(
    backspaceCount: Int,
    diffChars rawDiffChars: [Character],
    strategy: SendingStrategy,
    normalizeToNFC: Bool
  ) {
    let diffChars = TextDiff.emittedCharacters(rawDiffChars, normalizeToNFC: normalizeToNFC)
    // Chụp PID đích đồng bộ ngay trên tap thread trước khi async xuống `simulationQueue`.
    let targetPID = axTargetPID
    guard backspaceCount + diffChars.count > 0 else { return }

    var effectiveStrategy = strategy
    if case .axDirect = strategy {} else if AXDirectInjector.overlaySearchIsFocused() {
      effectiveStrategy = .axDirect
    }

    switch effectiveStrategy {
    case .batch:
      let source = privateEventSource()
      simulationQueue.async {
        sendBackspace(backspaceCount, source: source, delayMicroseconds: 0)
        sendString(String(diffChars), source: source)
      }

    case .stepByStep:
      guard let source = privateEventSource() else { return }
      simulationQueue.async {
        sendBackspace(backspaceCount, source: source, delayMicroseconds: 2000)
        usleep(3000)
        sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 2000)
        usleep(3000)
      }

    case .axDirect:
      simulationQueue.async {
        for attempt in 0..<3 {
          if attempt > 0 { usleep(5000) }
          if AXDirectInjector.axDirectReplace(
            backspaceCount: backspaceCount, insert: String(diffChars),
            usesNFC: normalizeToNFC, targetPID: targetPID)
          {
            return
          }
        }
        if let source = privateEventSource() {
          sendSpotlightFallback(
            backspaceCount: backspaceCount, diffChars: diffChars, source: source)
        }
      }

    case .hybrid(let backspaceDelay):
      guard let source = privateEventSource() else { return }
      simulationQueue.async {
        sendBackspace(backspaceCount, source: source, delayMicroseconds: backspaceDelay)
        sendString(String(diffChars), source: source)
      }
    }
  }

  // MARK: - Compatibility Forwarders (delegate to AppCompatibilityRegistry / TextDiff / AXDirectInjector)

  static var appStrategies: [AppSendingConfig] { AppCompatibilityRegistry.appStrategies }
  static var terminalBundlePrefixes: [String] { AppCompatibilityRegistry.terminalBundlePrefixes }

  static func isTerminalApp(_ bundleId: String?) -> Bool {
    AppCompatibilityRegistry.isTerminalApp(bundleId)
  }

  static func isOverlayBundle(_ bundleId: String) -> Bool {
    AppCompatibilityRegistry.isOverlayBundle(bundleId)
  }

  static func userSendingMode(for bundleId: String) -> AppSendingMode? {
    AppCompatibilityRegistry.userSendingMode(for: bundleId)
  }

  static func getStrategy(for bundleId: String) -> SendingStrategy {
    AppCompatibilityRegistry.getStrategy(for: bundleId)
  }

  static func resolveStrategy(for bundleId: String, userMode: AppSendingMode?) -> SendingStrategy {
    AppCompatibilityRegistry.resolveStrategy(for: bundleId, userMode: userMode)
  }

  static func builtInStrategy(for bundleId: String) -> SendingStrategy {
    AppCompatibilityRegistry.builtInStrategy(for: bundleId)
  }

  static func calcKeyStrokes(from: String, to: String) -> (Int, [Character]) {
    TextDiff.calcKeyStrokes(from: from, to: to)
  }

  static func calcKeyStrokesNFD(from: String, to: String) -> (Int, [Character]) {
    TextDiff.calcKeyStrokesNFD(from: from, to: to)
  }

  static func calcKeyStrokes(from: String, to: String, usesNFC: Bool) -> (Int, [Character]) {
    TextDiff.calcKeyStrokes(from: from, to: to, usesNFC: usesNFC)
  }

  static func emittedCharacters(_ diffChars: [Character], normalizeToNFC: Bool) -> [Character] {
    TextDiff.emittedCharacters(diffChars, normalizeToNFC: normalizeToNFC)
  }

  static func axDeleteStart(
    _ value: String, caretUTF16: Int, backspaceCount: Int, usesNFC: Bool
  ) -> Int {
    TextDiff.axDeleteStart(
      value, caretUTF16: caretUTF16, backspaceCount: backspaceCount, usesNFC: usesNFC)
  }

  static func focusedOverlayBundle() -> String? {
    AXDirectInjector.focusedOverlayBundle()
  }

  static func axDirectReplace(
    backspaceCount: Int, insert: String, usesNFC: Bool, targetPID: pid_t
  ) -> Bool {
    AXDirectInjector.axDirectReplace(
      backspaceCount: backspaceCount, insert: insert, usesNFC: usesNFC, targetPID: targetPID)
  }

  static func axShouldPlaceCaret(
    selectionAfterWrite: CFRange?, targetCaret: Int, valueLength: Int
  ) -> Bool {
    AXDirectInjector.axShouldPlaceCaret(
      selectionAfterWrite: selectionAfterWrite, targetCaret: targetCaret, valueLength: valueLength)
  }

  static func axWriteLanded(
    oldValue: String, wanted: String, got: String, hadSuffixSelection: Bool
  ) -> Bool {
    AXDirectInjector.axWriteLanded(
      oldValue: oldValue, wanted: wanted, got: got, hadSuffixSelection: hadSuffixSelection)
  }
}
