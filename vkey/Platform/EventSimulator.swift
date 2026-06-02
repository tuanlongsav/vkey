//
//  EventSimulator.swift
//  vkey
//
//  Created by KhanhIceTea on 27/3/24.
//

import CoreGraphics
import Defaults
import Foundation

/// Strategy for sending keyboard events to replace text.
enum SendingStrategy {
  /// Send all characters in a single batch event (fastest, may fail in some apps).
  case batch
  /// Send each character as individual key events (slowest, most compatible).
  case stepByStep
  /// Send as batch but with delays between backspaces (balanced approach).
  case hybrid(backspaceDelayMicroseconds: UInt32)
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
