//
//  InputProcessor.swift
//  vkey
//
//  Created by KhanhIceTea on 24/02/2024.
//

import AppKit
import CoreGraphics
import Defaults
import Foundation

// MARK: - WordBuffer

/// WordBuffer manages the Vietnamese word state during typing.
/// It tracks the current word being typed, handles push/pop operations,
/// and manages recovery mode with a snapshot stack for multi-step rollback.
struct WordBuffer {

  struct Snapshot {
    let wordState: TiengVietState
    let keys: [Character]
    let transformed: String
    let stopProcessing: Bool
  }

  var keys: [Character] = []
  var stopProcessing = false
  var lastTransformed = ""
  var transformed = ""

  var previousWordState: TiengVietState?
  var wordState = TiengVietState.empty

  /// Last valid snapshot for single-step rollback out of recovery mode.
  var lastValidSnapshot: Snapshot?

  private static let impossible2LetterPrefixes: Set<String> = [
    "bl", "cl", "fl", "gl", "pl", "sl", "vl",
    "br", "cr", "dr", "fr", "gr", "pr", "wr",
    "st", "sm", "sn", "sp", "sc", "sk", "sw",
    "tw", "dw", "sh", "ps", "pn", "ts", "kn", "kr",
    "bb", "cc", "ff", "gg", "hh", "jj", "kk", "ll",
    "mm", "nn", "pp", "qq", "rr", "ss", "tt", "vv",
    "xx", "zz"
  ]

  private static let impossible3LetterPrefixes: Set<String> = [
    "str", "thr", "phr", "chr", "sch", "scr", "spr"
  ]

  func isImpossibleCluster(_ keys: [Character], engine: TypingMethod) -> Bool {
    guard !keys.isEmpty else { return false }
    
    // Rule 1: First letter cannot be f, j, z (or w for VNI) if allowed-zwjf is disabled
    if !Defaults[.allowedZWJF], let firstChar = keys.first {
      let lowerFirst = firstChar.lowercased()
      if lowerFirst == "f" || lowerFirst == "j" || lowerFirst == "z" {
        return true
      }
      
      // VNI specific: starting letter cannot be w
      if engine is VNI, lowerFirst == "w" {
        return true
      }
    }
    
    // Rule 2: Impossible 2-letter prefixes
    if keys.count >= 2 {
      let prefix2 = String(keys.prefix(2)).lowercased()
      if Self.impossible2LetterPrefixes.contains(prefix2) {
        return true
      }
    }
    
    // Rule 3: Impossible 3-letter prefixes
    if keys.count >= 3 {
      let prefix3 = String(keys.prefix(3)).lowercased()
      if Self.impossible3LetterPrefixes.contains(prefix3) {
        return true
      }
    }
    
    return false
  }

  // MARK: - Word Lifecycle

  mutating func newWord(storePrevious: Bool = false) {
    previousWordState = nil
    if !wordState.isBlank {
      if storePrevious {
        previousWordState = wordState
      }
      wordState = .empty
    }

    keys = []
    lastValidSnapshot = nil
    stopProcessing = false
    lastTransformed = ""
    transformed = ""
  }

  // MARK: - Pop (Backspace)

  mutating func pop(engine: TypingMethod) -> (Int, [Character]) {
    lastTransformed = transformed

    // Single-step rollback: if we are in recovery and it was caused by the LATEST keystroke
    if stopProcessing, let valid = lastValidSnapshot, keys.count == valid.keys.count + 1 {
      wordState = valid.wordState
      keys = valid.keys
      transformed = valid.transformed
      stopProcessing = valid.stopProcessing
      lastValidSnapshot = nil

      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: lastTransformed, to: transformed)

      if numBackspaces == 1 && diffChars.isEmpty {
        return (0, [])
      }

      return (numBackspaces, diffChars)
    }

    // Normal pop: restore previous word on empty buffer
    if wordState.isBlank, let prev = previousWordState {
      wordState = prev
      previousWordState = nil
      keys = Array(wordState.chuKhongDau)
      transformed = wordState.transformed
      lastTransformed = transformed
      stopProcessing = false
      lastValidSnapshot = nil
      return (0, [])  // Let OS handle the backspace that brought us here
    }

    // Normal pop: remove last character
    wordState = engine.pop(state: wordState)
    keys = Array(wordState.chuKhongDau)
    
    if isImpossibleCluster(keys, engine: engine) {
      stopProcessing = true
    } else {
      stopProcessing = wordState.needsRecovery
    }

    if stopProcessing {
      transformed = String(keys)
    } else {
      transformed = wordState.transformed
    }

    lastValidSnapshot = nil

    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If it's a simple 1-char deletion, let the OS handle it
    if numBackspaces == 1 && diffChars.isEmpty {
      return (0, [])
    }

    return (numBackspaces, diffChars)
  }

  // MARK: - Push (New Character)

  mutating func push(char: Character, engine: TypingMethod) {
    // Save current state before mutation
    let snapshot = Snapshot(
      wordState: wordState,
      keys: keys,
      transformed: transformed,
      stopProcessing: stopProcessing
    )

    keys.append(char)
    lastTransformed = transformed

    if stopProcessing {
      transformed.append(char)
      wordState = wordState.push(char)
      return
    }

    // Check if newly formed keys are an impossible cluster
    if isImpossibleCluster(keys, engine: engine) {
      stopProcessing = true
      transformed = String(keys)
      wordState = wordState.push(char)
      
      // Save snapshot for rollback if we just entered recovery/stopProcessing
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    let result = engine.push(char: char, state: wordState)
    wordState = result.state

    // Check if we need to recover original input (invalid Vietnamese syllable)
    if wordState.needsRecovery {
      stopProcessing = true
      // Use keys array which contains ALL typed characters (including tone marks like 's', 'f' etc.)
      transformed = String(keys)

      // If we JUST entered recovery mode, save the snapshot for rollback
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
    } else {
      transformed = wordState.transformed
      // Clear snapshot when we're in valid state — no rollback needed
      lastValidSnapshot = nil
    }

    if engine.shouldStopProcessing(keyStr: String(keys)) {
      stopProcessing = true
      if transformed.count == lastTransformed.count {
        transformed.append(char)
        wordState = wordState.push(char)
      }
    }
  }
}

// MARK: - TransformationTracker

/// TransformationTracker monitors for repeated transformation failures
/// and auto-switches the sending strategy when a pattern is detected.
/// This helps apps where the default strategy doesn't work reliably.
struct TransformationTracker {

  /// Current sending strategy for the active app
  var currentStrategy: SendingStrategy = .batch

  // MARK: - Strategy Management

  mutating func resetForApp(_ bundleId: String) {
    currentStrategy = EventSimulator.getStrategy(for: bundleId)
  }

  /// Placeholder for future output-aware failure detection.
  /// The previous heuristic only counted repeated input characters, which could
  /// switch strategies after valid typing and slow down the app unnecessarily.
  mutating func detectFailure(input: Character) -> Bool {
    return false
  }

  /// Auto-switches to step-by-step mode if failures are detected.
  mutating func autoSwitchIfNeeded(activeApp: String) {
    guard Defaults[.autoSwitchStrategy] else { return }

    // Don't auto-switch if already using step-by-step
    if case .stepByStep = currentStrategy { return }

    // Switch to step-by-step for this session
    #if DEBUG
    let appName = EventSimulator.getAppName(for: activeApp)
    print("[vkey] Auto-switched from \(currentStrategy) to step-by-step mode for \(appName) due to failures")
    #endif

    currentStrategy = .stepByStep
  }
}

// MARK: - InputProcessor

class InputProcessor {
  static let FixAutocompleteApps = [
    // Chromium-based
    "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta",
    "org.chromium.Chromium",
    "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
    "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary",
    "com.vivaldi.Vivaldi", "com.vivaldi.Vivaldi.snapshot",
    "ru.yandex.desktop.yandex-browser", "com.naver.Whale",

    // Opera
    "com.opera.Opera", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
    "com.operasoftware.OperaAir", "com.opera.OperaNext",

    // Firefox-based
    "org.mozilla.firefox", "org.mozilla.nightly", "org.torproject.torbrowser", "org.librewolf.LibreWolf",
    "app.zen-browser.zen",

    // Safari & WebKit-based
    "com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.apple.Safari.TechnologyPreview",
    "com.kagi.kagimacOS", "com.duckduckgo.mac", "com.duckduckgo.macos.browser",

    // Arc & Others
    "company.thebrowser.Browser", "company.thebrowser.Arc", "company.thebrowser.dia",
    "com.sigmaos.sigmaos", "com.sigmaos.sigmaos.macos",
    "com.pushplaylabs.sidekick", "com.firstversionist.polypane",
    "ai.perplexity.comet", "com.electron.min",

    // Office & Legacy
    "com.microsoft.Excel", "com.microsoft.Office.Excel", "com.microsoft.edge", "com.microsoft.Edge",
  ]
  static let NewWordKeys = "`!@#$%^&*()-=[]\\;',./~_+{}|:\"<>?"
  static let NewWordTaskKeys: [TaskKey] = [.Enter, .Space, .Tab]
  static let JumpTaskKeys: [TaskKey] = [.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight]

  public var engine: TypingMethod
  public var typingMethod: TypingMethods
  public var keyLayout = KeyboardUS()
  public var activeApp = ""

  /// Word buffer manages the current word state
  var wordBuffer = WordBuffer()

  /// Transformation tracker manages per-app strategy and failure detection
  var strategyTracker = TransformationTracker()

  /// Track pasteboard change count to detect external paste operations
  private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount

  // MARK: - Convenience accessors (preserve existing API for tests)

  public var keys: [Character] {
    get { wordBuffer.keys }
    set { wordBuffer.keys = newValue }
  }

  public var stopProcessing: Bool {
    get { wordBuffer.stopProcessing }
    set { wordBuffer.stopProcessing = newValue }
  }

  public var lastTransformed: String {
    get { wordBuffer.lastTransformed }
    set { wordBuffer.lastTransformed = newValue }
  }

  public var transformed: String {
    get { wordBuffer.transformed }
    set { wordBuffer.transformed = newValue }
  }

  public var previousWordState: TiengVietState? {
    get { wordBuffer.previousWordState }
    set { wordBuffer.previousWordState = newValue }
  }

  public var wordState: TiengVietState {
    get { wordBuffer.wordState }
    set { wordBuffer.wordState = newValue }
  }

  // MARK: - Init & Configuration

  init(method: TypingMethods) {
    typingMethod = method
    engine = typingMethod == .Telex ? Telex() : VNI()
  }

  public func changeTypingMethod(newMethod: TypingMethods) {
    typingMethod = newMethod
    engine = typingMethod == .Telex ? Telex() : VNI()
    newWord()
  }

  public func changeActiveApp(_ app: String) {
    activeApp = app
    strategyTracker.resetForApp(app)
  }

  // MARK: - Word Operations (delegate to WordBuffer)

  public func newWord(storePrevious: Bool = false) {
    wordBuffer.newWord(storePrevious: storePrevious)
  }

  public func pop() -> (Int, [Character]) {
    return wordBuffer.pop(engine: engine)
  }

  public func push(char: Character) {
    wordBuffer.push(char: char, engine: engine)
  }

  // MARK: - Main Input Handler

  public func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let shifted = flags.contains(.maskShift) || (!keyLayout.isNumberKey(keyCode: keyCode) && flags.contains(.maskAlphaShift))

    // Handle modifier keys (Cmd, Ctrl, Alt) - clear word buffer
    if flags.contains(.maskCommand) || flags.contains(.maskControl)
      || flags.contains(.maskAlternate)
    {
      newWord()
      return Unmanaged.passUnretained(event)
    }

    // Detect if a paste operation occurred (pasteboard changed externally)
    let currentPasteboardCount = NSPasteboard.general.changeCount
    if currentPasteboardCount != lastPasteboardChangeCount {
      lastPasteboardChangeCount = currentPasteboardCount
      newWord()
    }

    // Dispatch based on key type
    if let taskKey = keyLayout.mapTask(keyCode: keyCode) {
      return handleTaskKey(taskKey, event: event)
    } else if let newChar = keyLayout.mapText(keyCode: keyCode, withShift: shifted) {
      return handleTextChar(newChar, event: event)
    }

    return Unmanaged.passUnretained(event)
  }

  // MARK: - Private Event Handlers

  private func handleTaskKey(_ taskKey: TaskKey, event: CGEvent) -> Unmanaged<CGEvent>? {
    if InputProcessor.NewWordTaskKeys.contains(taskKey) {
      // Only expand macros on Space — Tab/Enter often have form-submission semantics
      // we don't want to swallow.
      if taskKey == .Space, expandMacroIfMatch(endingChar: " ") {
        newWord(storePrevious: true)
        return nil
      }
      newWord(storePrevious: true)
    } else if taskKey == .Delete {
      let (numBackspaces, diffChars) = pop()
      if numBackspaces > 0 || !diffChars.isEmpty {
        EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        return nil
      }
    } else if InputProcessor.JumpTaskKeys.contains(taskKey) {
      newWord()
    }
    return Unmanaged.passUnretained(event)
  }

  private func handleTextChar(_ newChar: Character, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Check if this is a word-ending character (punctuation, etc.) BEFORE processing
    if let _ = InputProcessor.NewWordKeys.firstIndex(of: newChar) {
      if expandMacroIfMatch(endingChar: newChar) {
        newWord(storePrevious: true)
        return nil
      }
      newWord(storePrevious: true)
      return Unmanaged.passUnretained(event)
    }

    push(char: newChar)
    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If the only change is the new character itself, let it pass through
    if let firstDiffChar = diffChars.first,
      diffChars.count == 1 && firstDiffChar == newChar && numBackspaces == 0
    {
      return Unmanaged.passUnretained(event)
    }

    // Check for transformation failures and auto-switch if needed
    if strategyTracker.detectFailure(input: newChar) {
      strategyTracker.autoSwitchIfNeeded(activeApp: activeApp)
    }

    if isFixAutocompleteApp() {
      // For autocomplete-capable apps (browsers, etc.), use select-and-replace
      // instead of backspace-and-type. Shift+Left naturally extends any existing
      // inline autocomplete selection, so the typed replacement covers both the
      // autocomplete text and the characters being modified.
      EventSimulator.sendSelectAndReplace(
        selectLeftCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
    } else {
      EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
    }
    return nil
  }

  // MARK: - Helpers

  func isFixAutocompleteApp() -> Bool {
    return InputProcessor.FixAutocompleteApps.contains { app in
      return activeApp.hasPrefix(app)
    }
  }

  static func macroReplacement(
    for current: String,
    endingChar: Character,
    macros: [Macro]
  ) -> (backspaceCount: Int, diffChars: [Character])? {
    guard !current.isEmpty else { return nil }
    guard
      let macro = macros.first(where: {
        !$0.from.isEmpty && !$0.to.isEmpty && $0.from == current
      })
    else {
      return nil
    }

    return (current.count, Array(macro.to + String(endingChar)))
  }

  /// Expands the current word using the user's macro table if it matches.
  /// When a match is found, replaces the on-screen word with the expansion plus
  /// the word-ending character, then returns true so the caller can swallow the
  /// original ending key. Returns false (no side effects) when no macro matches.
  private func expandMacroIfMatch(endingChar: Character) -> Bool {
    let current = wordBuffer.transformed
    guard
      let replacement = Self.macroReplacement(
        for: current,
        endingChar: endingChar,
        macros: Defaults[.macros]
      )
    else {
      return false
    }

    EventSimulator.sendReplacement(
      backspaceCount: replacement.backspaceCount,
      diffChars: replacement.diffChars,
      strategy: strategyTracker.currentStrategy
    )
    return true
  }
}
