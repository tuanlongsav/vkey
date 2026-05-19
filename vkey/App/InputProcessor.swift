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

// MARK: - Spellcheck & Lexicon Core
//
// Type definitions for `Lexicon`, `InMemoryLexicon`, `SpellDecision`,
// `SuggestionCandidate`, and the `String` extension live in
// `Lexicon/Lexicon.swift` (extracted in 1.5.0). InputProcessor.swift retains
// the wiring (LexiconManager, SpellDecisionEngine, WordBuffer, etc.) until
// follow-up 1.5.x patches finish the file split.


// LexiconManager, SuggestionService moved to vkey/Lexicon/ in 1.5.0.


// SpellDecisionEngine moved to vkey/Input/SpellDecisionEngine.swift in 1.5.0.

// `String.normalizedDictionaryToken`, `.vietnameseFolded`, `.isASCIIAlphabeticWord`
// moved to `Lexicon/Lexicon.swift` in 1.5.0.

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
    let stoppedByEnglishWord: Bool
  }

  var keys: [Character] = []
  var stopProcessing = false
  var stoppedByEnglishWord = false
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
    stoppedByEnglishWord = false
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
      stopProcessing: stopProcessing,
      stoppedByEnglishWord: stoppedByEnglishWord
    )

    keys.append(char)
    lastTransformed = transformed

    // If stopProcessing was set, but it was ONLY because of English word restoration on the previous step
    // (i.e. the previous state did not have a real spelling matrix failure or impossible cluster),
    // we allow re-evaluation by REPLAYING all keys from scratch through the engine.
    // This fixes bugs like 'tees' → 'tế' where 'tee' (English) blocked further processing.
    // However, if the new keys form a doubled tone mark (like 'ss', 'ff'), we skip re-evaluation to preserve double-letter English suffixes.
    var wasOnlyEnglishRestored = false
    let keysStr = String(keys).lowercased()
    let doubledTones = ["ss", "ff", "rr", "xx", "jj"]
    // Use the explicit stoppedByEnglishWord flag set during English word restoration.
    // This is reliable because wordState.needsRecovery gets corrupted by the raw push
    // during English restoration, making it unsuitable for detection.
    if stopProcessing && stoppedByEnglishWord {
      if !doubledTones.contains(where: { keysStr.contains($0) }) {
        wasOnlyEnglishRestored = true
      }
    }

    if stopProcessing && !wasOnlyEnglishRestored {
      transformed.append(char)
      wordState = wordState.push(char)
      return
    }

    // When re-evaluating after English restoration, replay ALL keys from scratch
    // because the wordState was corrupted by the raw English restoration path.
    if wasOnlyEnglishRestored {
      stopProcessing = false
      stoppedByEnglishWord = false
      wordState = .empty
      var replayValid = true
      for k in keys {
        let result = engine.push(char: k, state: wordState)
        wordState = result.state
        if wordState.needsRecovery {
          replayValid = false
          break
        }
      }
      if replayValid && !wordState.needsRecovery {
        transformed = wordState.transformed
        lastValidSnapshot = nil
        // Check shouldStopProcessing for the replayed keys
        if engine.shouldStopProcessing(keyStr: String(keys)) {
          stopProcessing = true
          if transformed.count == lastTransformed.count {
            transformed.append(char)
            wordState = wordState.push(char)
          }
        }
        // Check if the full replayed word is an English word
        if LexiconManager.shared.isEnglishWord(keysStr) {
          stopProcessing = true
          transformed = String(keys)
          if !snapshot.stopProcessing {
            lastValidSnapshot = snapshot
          }
        }
      } else {
        // Replay failed — treat as raw text
        stopProcessing = true
        transformed = String(keys)
        wordState = TiengVietState.empty
        for k in keys { wordState = wordState.push(k) }
      }
      return
    }

    // Doubled Tone Mark Preservation: if raw keys contains consecutive doubled tone marks, preserve it raw if it forms an English word
    if doubledTones.contains(where: { keysStr.contains($0) }),
       LexiconManager.shared.isEnglishWord(keysStr) {
      stopProcessing = true
      stoppedByEnglishWord = true
      transformed = String(keys)
      wordState = wordState.push(char)
      
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    // Instantaneous English word restoration: if the raw keys form a known English word, preserve it raw
    if LexiconManager.shared.isEnglishWord(keysStr) {
      stopProcessing = true
      stoppedByEnglishWord = true
      transformed = String(keys)
      wordState = wordState.push(char)
      
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
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
  private var consecutiveFailures = 0
  private var consecutiveHighRiskTransforms = 0

  // MARK: - Strategy Management

  mutating func resetForApp(_ bundleId: String) {
    currentStrategy = EventSimulator.getStrategy(for: bundleId)
    consecutiveFailures = 0
    consecutiveHighRiskTransforms = 0
  }

  /// Detect transformation failures based on event creation status and
  /// repeated high-risk transforms on apps that are known to be sensitive.
  mutating func detectFailure(
    telemetry: EventSendTelemetry,
    appLikelySensitive: Bool
  ) -> Bool {
    guard telemetry.attemptedTransform else {
      consecutiveHighRiskTransforms = max(0, consecutiveHighRiskTransforms - 1)
      return false
    }

    if telemetry.createdEvents {
      consecutiveFailures = max(0, consecutiveFailures - 1)
    } else {
      consecutiveFailures += 1
    }

    let isHighRisk = appLikelySensitive
      && !telemetry.usedAsyncQueue
      && telemetry.touchedCharacters >= 3
    if isHighRisk {
      consecutiveHighRiskTransforms += 1
    } else {
      consecutiveHighRiskTransforms = max(0, consecutiveHighRiskTransforms - 1)
    }

    return consecutiveFailures >= 2 || consecutiveHighRiskTransforms >= 3
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
  public private(set) var lastSuggestions: [SuggestionCandidate] = []

  private let spellDecisionEngine = SpellDecisionEngine.shared

  /// Word buffer manages the current word state
  var wordBuffer = WordBuffer()

  /// Transformation tracker manages per-app strategy and failure detection
  var strategyTracker = TransformationTracker()

  /// Track pasteboard change count to detect external paste operations
  private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount

  // 1.6.0: Word prediction state — track 2 previous committed words để
  // feed bigram + trigram model. `activePrediction` lưu prediction đang
  // hiển thị trên HUD; nếu user nhấn Tab → accept và inject.
  private var prev1Committed: String? = nil
  private var prev2Committed: String? = nil
  private var activePrediction: String? = nil

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
    LexiconManager.shared.reload()
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
    // 1.6.0: Tab + có prediction active + feature bật → accept prediction.
    // Chỉ ăn Tab khi tất cả điều kiện match; nếu không, pass-through để
    // app khác (vd form input) nhận Tab bình thường.
    if taskKey == .Tab,
       let prediction = activePrediction,
       Defaults[.wordPredictionEnabled],
       wordBuffer.wordState.isBlank  // chỉ accept khi user vừa commit xong word
    {
      let toInsert = "\(prediction) "
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: 0,
        diffChars: Array(toInsert),
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      DispatchQueue.main.async {
        PredictionHUDWindow.shared.hide()
      }
      // Update prediction chain — prediction giờ trở thành prev1.
      prev2Committed = prev1Committed
      prev1Committed = prediction.lowercased()
      activePrediction = nil
      return nil  // swallow Tab
    }

    if InputProcessor.NewWordTaskKeys.contains(taskKey) {
      // Only expand macros on Space — Tab/Enter often have form-submission semantics
      // we don't want to swallow.
      if taskKey == .Space, expandMacroIfMatch(endingChar: " ") {
        newWord(storePrevious: true)
        return nil
      }

      if taskKey == .Space, applySpellDecisionOnCommit(endingChar: " ", swallowEndingChar: true) {
        newWord(storePrevious: true)
        return nil
      }
      newWord(storePrevious: true)
    } else if taskKey == .Escape {
      let orig = String(wordBuffer.keys)
      let currentTransformed = wordBuffer.transformed
      if !wordBuffer.wordState.isBlank && currentTransformed != orig {
        let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: currentTransformed, to: orig)
        let telemetry = EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
        newWord()
        return nil // swallow ESC event
      }
      newWord()
    } else if taskKey == .Delete {
      let (numBackspaces, diffChars) = pop()
      if numBackspaces > 0 || !diffChars.isEmpty {
        let telemetry = EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
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
      if applySpellDecisionOnCommit(endingChar: newChar, swallowEndingChar: true) {
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

    if isFixAutocompleteApp() {
      // For autocomplete-capable apps (browsers, etc.), use select-and-replace
      // instead of backspace-and-type. Shift+Left naturally extends any existing
      // inline autocomplete selection, so the typed replacement covers both the
      // autocomplete text and the characters being modified.
      let strategy = effectiveTypingStrategy(
        backspaceCount: numBackspaces,
        diffCharCount: diffChars.count
      )
      let telemetry = EventSimulator.sendSelectAndReplace(
        selectLeftCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategy
      )
      observeTelemetry(telemetry, appLikelySensitive: true)
    } else {
      let strategy = effectiveTypingStrategy(
        backspaceCount: numBackspaces,
        diffCharCount: diffChars.count
      )
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategy
      )
      observeTelemetry(telemetry, appLikelySensitive: false)
    }
    return nil
  }

  // MARK: - Helpers

  private func observeTelemetry(_ telemetry: EventSendTelemetry, appLikelySensitive: Bool) {
    if strategyTracker.detectFailure(
      telemetry: telemetry,
      appLikelySensitive: appLikelySensitive
    ) {
      strategyTracker.autoSwitchIfNeeded(activeApp: activeApp)
    }
  }

  /// For tiny diffs (common during Telex tone mutation), force immediate batch sending
  /// to avoid async reordering with the next keystroke (e.g. "push" -> "pussh").
  private func effectiveTypingStrategy(backspaceCount: Int, diffCharCount: Int) -> SendingStrategy {
    if backspaceCount <= 1 && diffCharCount <= 1 {
      return .batch
    }
    return strategyTracker.currentStrategy
  }

  /// Applies spell/restore/suggestion rules when a word commit key is pressed.
  /// - Parameters:
  ///   - endingChar: Commit key character (space or punctuation).
  ///   - swallowEndingChar: True when commit key should be emitted by vkey and swallowed by the caller.
  /// - Returns: True when a replacement was sent.
  @discardableResult
  private func applySpellDecisionOnCommit(
    endingChar: Character,
    swallowEndingChar: Bool
  ) -> Bool {
    let rawInput = String(wordBuffer.keys)
    let current = wordBuffer.transformed
    guard !rawInput.isEmpty, !current.isEmpty else {
      lastSuggestions = []
      return false
    }

    guard Defaults[.spellCheckInSentenceEnabled] else {
      lastSuggestions = []
      return false
    }

    let decision = spellDecisionEngine.evaluate(
      rawInput: rawInput,
      transformed: current,
      needsRecovery: wordBuffer.wordState.needsRecovery || wordBuffer.stopProcessing
    )

    // 1.5.0: feed every committed word into UsageStatistics. No-op when the
    // user has turned stats off in Settings.
    UsageStatistics.shared.recordCommit(
      decision: decision,
      rawInput: rawInput,
      transformed: current,
      appBundleId: activeApp.isEmpty ? nil : activeApp
    )

    // 1.6.0: Word prediction learning + lookup. Học passively từ commit;
    // chỉ trigger HUD khi user bật toggle `wordPredictionEnabled`.
    let committedToken = current.normalizedDictionaryToken
    PredictionEngine.shared.learnTransition(
      prev2: prev2Committed,
      prev1: prev1Committed,
      current: committedToken
    )
    // Slide window
    prev2Committed = prev1Committed
    prev1Committed = committedToken

    if Defaults[.wordPredictionEnabled],
       let prediction = PredictionEngine.shared.topPrediction(
         prev2: prev2Committed, prev1: prev1Committed ?? ""
       )
    {
      activePrediction = prediction
      DispatchQueue.main.async {
        PredictionHUDWindow.shared.show(prediction: prediction)
      }
    } else {
      activePrediction = nil
      DispatchQueue.main.async {
        PredictionHUDWindow.shared.hide()
      }
    }

    switch decision {
    case .keepVietnamese, .keepRaw:
      lastSuggestions = []
      return false

    case .restoreRawEnglish(let restoredWord):
      lastSuggestions = []
      let target = Self.commitReplacementTarget(
        word: restoredWord,
        endingChar: endingChar,
        includeEndingChar: swallowEndingChar
      )
      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: current, to: target)
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      return true

    case .suggest(let suggestions):
      lastSuggestions = suggestions
      guard
        Defaults[.autoApplyHighConfidenceSuggestion],
        let top = suggestions.first,
        top.score >= 0.88
      else {
        return false
      }

      let target = Self.commitReplacementTarget(
        word: top.word,
        endingChar: endingChar,
        includeEndingChar: swallowEndingChar
      )
      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: current, to: target)
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      return true
    }
  }

  func isFixAutocompleteApp() -> Bool {
    if Focused.isComboBoxOrSearchField() {
      return true
    }
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

  static func commitReplacementTarget(
    word: String,
    endingChar: Character,
    includeEndingChar: Bool
  ) -> String {
    includeEndingChar ? word + String(endingChar) : word
  }

  /// Expands the current word using the user's macro table if it matches.
  /// When a match is found, replaces the on-screen word with the expansion plus
  /// the word-ending character, then returns true so the caller can swallow the
  /// original ending key. Returns false (no side effects) when no macro matches.
  private func expandMacroIfMatch(endingChar: Character) -> Bool {
    // Toggle from menu bar / tab Macro. Khi tắt, danh sách macro vẫn được
    // giữ — chỉ tạm dừng expansion.
    guard Defaults[.macroEnabled] else { return false }

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

    let telemetry = EventSimulator.sendReplacement(
      backspaceCount: replacement.backspaceCount,
      diffChars: replacement.diffChars,
      strategy: strategyTracker.currentStrategy
    )
    observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
    return true
  }
}
