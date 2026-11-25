//
//  InputProcessor.swift
//  vkey
//
//  Created by KhanhIceTea on 24/02/2024.
//

import CoreGraphics
import Defaults
import Foundation

// MARK: - InputProcessor

/// Bộ điều phối chính của đường gõ phím: nối `WordBuffer`, `AutoCapitalizer`,
/// `MacroExpander`, `SpellDecisionEngine`, `EmitPlan`, `AppCompatibilityRegistry`
/// và `EventSimulator`.
class InputProcessor {
  static var FixAutocompleteApps: [String] { AppCompatibilityRegistry.browserBundlePrefixes }
  static let NewWordKeys = "`!@#$%^&*()-=[]\\;',./~_+{}|:\"<>?"
  static let NewWordTaskKeys: [TaskKey] = [.Enter, .Space, .Tab]
  static let JumpTaskKeys: [TaskKey] = [.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight]

  public var engine: TypingMethod
  public var typingMethod: TypingMethods
  public var keyLayout = KeyboardUS()
  public var activeApp = ""

  /// v3.9: phân loại field đang focus (push-based từ AppState) — quyết định
  /// diff NFC/NFD (`usesNFCForFocusedField`) và chiến lược gửi
  /// (`effectiveTypingStrategy` → axDirect cho omnibox Chrome).
  public var focusedFieldKind: Focused.FieldKind = .unknown

  private let spellDecisionEngine = SpellDecisionEngine.shared

  /// Word buffer manages the current word state.
  var wordBuffer = WordBuffer()

  /// Shift do bàn phím thật báo qua `flagsChanged` (`nil` = chưa theo dõi → tin event).
  public var hardwareShiftDown: Bool?

  /// 2.0 (A5): máy trạng thái tự viết hoa đầu câu.
  private var autoCapitalizer = AutoCapitalizer()

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
    // Khởi tạo sớm ngoài đường gõ phím (init đã tự reload).
    _ = LexiconManager.shared
  }

  public func changeTypingMethod(newMethod: TypingMethods) {
    typingMethod = newMethod
    engine = typingMethod == .Telex ? Telex() : VNI()
    newWord()
  }

  /// ⚠️ CỐ Ý KHÔNG GỌI `newWord()` Ở ĐÂY — xem ghi chú hồi quy Spotlight (v4.23):
  /// `activeApp` có thể dao động giữa overlay và app nền trên macOS 26.
  public func changeActiveApp(_ app: String) {
    let appChanged = app != activeApp
    activeApp = app
    if appChanged {
      resetSentenceCapitalizeState()
    }
  }

  /// Huỷ trạng thái chờ viết hoa đầu câu khi con trỏ di chuyển / ngữ cảnh bị gián đoạn.
  public func resetSentenceCapitalizeState() {
    autoCapitalizer.reset()
  }

  // MARK: - Word & EmitPlan Operations

  public func newWord(storePrevious: Bool = false) {
    wordBuffer.newWord(storePrevious: storePrevious)
  }

  /// Kế hoạch phát cho MỘT lần gửi. Đo lại mỗi lần gọi, trừ khi `nfdEmitPlan`
  /// đã kích hoạt (F1 — chốt NFD sau lần gửi đầu có `backspaceCount > 0`).
  func emitPlan() -> EmitPlan {
    if let locked = wordBuffer.nfdEmitPlan {
      return locked
    }
    let kind = currentFieldKind()
    return EmitPlan(
      usesNFC: usesNFC(forFieldKind: kind),
      fieldIsBrowserChrome: isBrowserChrome(forFieldKind: kind)
    )
  }

  /// Kích hoạt chốt NFD (F1) sau lần gửi có backspace thật sự trên nhánh NFD `.webContent`.
  private func noteConsequentialNfdEmit(_ plan: EmitPlan, backspaceCount: Int) {
    guard backspaceCount > 0, !plan.usesNFC, wordBuffer.nfdEmitPlan == nil else { return }
    guard currentFieldKind() == .webContent else { return }
    wordBuffer.nfdEmitPlan = plan
  }

  /// Ghi nhận lần gửi đã xảy ra — chỉ cho test (`@testable import`).
  internal func recordConsequentialEmitForTests(_ replacement: EmitPlan.Replacement) {
    noteConsequentialNfdEmit(replacement.plan, backspaceCount: replacement.backspaceCount)
  }

  /// Dạng THÔ của `pop`, nhận trục rời (giữ cho test đối chiếu hai trục).
  /// Đường gõ thật phải dùng `pop(plan:)` trong `EmitPlan.swift`.
  public func pop(usesNFC: Bool) -> (Int, [Character]) {
    wordBuffer.pop(engine: engine, usesNFC: usesNFC)
  }

  public func push(char: Character) {
    wordBuffer.push(char: char, engine: engine)
  }

  // MARK: - Main Input Handler

  public func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let eventShift = flags.contains(.maskShift)
    let isShift = hardwareShiftDown.map { eventShift && $0 } ?? eventShift
    let isCapsLock = keyLayout.isLetterKey(keyCode: keyCode) && flags.contains(.maskAlphaShift)
    let shifted = isShift != isCapsLock

    if flags.contains(.maskCommand) || flags.contains(.maskControl)
      || flags.contains(.maskAlternate)
    {
      newWord()
      resetSentenceCapitalizeState()
      return Unmanaged.passUnretained(event)
    }

    if let taskKey = keyLayout.mapTask(keyCode: keyCode) {
      return handleTaskKey(taskKey, event: event)
    } else if let newChar = keyLayout.mapText(keyCode: keyCode, withShift: shifted) {
      return handleTextChar(newChar, event: event)
    }

    return passThrough(event)
  }

  /// Trả event về app; gỡ `maskShift` kẹt trên phím chữ và Backspace khi phần cứng không giữ Shift.
  private func passThrough(_ event: CGEvent) -> Unmanaged<CGEvent> {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let inScope =
      keyLayout.isLetterKey(keyCode: keyCode)
      || keyCode == Int64(EventSimulator.KeyCode.delete)
    if inScope,
       hardwareShiftDown == false,
       event.flags.contains(.maskShift),
       !event.flags.contains(.maskCommand),
       !event.flags.contains(.maskControl),
       !event.flags.contains(.maskAlternate)
    {
      event.flags.remove(.maskShift)
    }
    return Unmanaged.passUnretained(event)
  }

  // MARK: - Private Event Handlers

  private func handleTaskKey(_ taskKey: TaskKey, event: CGEvent) -> Unmanaged<CGEvent>? {
    if InputProcessor.NewWordTaskKeys.contains(taskKey) {
      autoCapitalizer.handleTaskKey(taskKey)

      if taskKey == .Space, expandMacroAndAdvance(endingChar: " ") {
        return nil
      }

      if taskKey == .Space, applySpellDecisionAndAdvance(endingChar: " ", swallowEndingChar: true) {
        return nil
      }
      newWord(storePrevious: taskKey == .Space)
    } else if taskKey == .Escape {
      resetSentenceCapitalizeState()
      let orig = String(wordBuffer.keys)
      let currentTransformed = wordBuffer.transformed
      if !wordBuffer.wordState.isBlank && currentTransformed != orig {
        sendTypedReplacement(emitPlan().replacement(from: currentTransformed, to: orig))
        newWord()
        return nil
      }
      newWord()
    } else if taskKey == .Delete {
      let plan = emitPlan()
      if sendsViaAXDirect(plan), Focused.focusedTextHasSelection() {
        return passThrough(event)
      }
      let replacement = pop(plan: plan)
      if !replacement.isEmpty {
        sendTypedReplacement(replacement)
        return nil
      }
    } else if InputProcessor.JumpTaskKeys.contains(taskKey) {
      newWord()
      resetSentenceCapitalizeState()
    }
    return passThrough(event)
  }

  private func handleTextChar(_ incomingChar: Character, event: CGEvent) -> Unmanaged<CGEvent>? {
    if InputProcessor.NewWordKeys.firstIndex(of: incomingChar) != nil {
      autoCapitalizer.handlePunctuation(incomingChar)

      if expandMacroAndAdvance(endingChar: incomingChar) {
        return nil
      }
      if applySpellDecisionAndAdvance(endingChar: incomingChar, swallowEndingChar: true) {
        return nil
      }
      newWord(storePrevious: true)
      return passThrough(event)
    }

    let (newChar, didAutoCapitalize) = autoCapitalizer.transformIncomingChar(
      incomingChar,
      enabled: Defaults[.autoCapitalizeEnabled]
    )

    push(char: newChar)

    if didAutoCapitalize {
      let plan = emitPlan()
      var replacement = plan.replacement(from: lastTransformed, to: transformed)
      if replacement.isEmpty {
        replacement = plan.insertion(of: [newChar])
      }
      sendTypedReplacement(replacement)
      return nil
    }

    let replacement = emitPlan().replacement(from: lastTransformed, to: transformed)

    if let firstDiffChar = replacement.diffChars.first,
      replacement.diffChars.count == 1 && firstDiffChar == newChar
        && replacement.backspaceCount == 0
    {
      return passThrough(event)
    }

    sendTypedReplacement(replacement)
    return nil
  }

  // MARK: - Replacement Dispatch & Strategy

  /// Điểm gọi DUY NHẤT tới `EventSimulator.sendReplacement` trong toàn bộ `vkey/`.
  private func sendTypedReplacement(_ replacement: EmitPlan.Replacement) {
    let backspaceCount = replacement.backspaceCount
    let diffChars = replacement.diffChars
    noteConsequentialNfdEmit(replacement.plan, backspaceCount: backspaceCount)
    let strategy = effectiveTypingStrategy(
      plan: replacement.plan,
      backspaceCount: backspaceCount,
      diffCharCount: diffChars.count
    )
    EventSimulator.sendReplacement(
      backspaceCount: backspaceCount,
      diffChars: diffChars,
      strategy: strategy,
      normalizeToNFC: replacement.plan.usesNFC
    )
  }

  /// Quyết định chiến lược gửi phím cho một lần thay thế.
  /// Nhánh `bs <= 1 && diff <= 1 → .batch` giữ nguyên để tránh race "push" → "pussh",
  /// trừ các app trong `keepsCushionOnSmallDiffs` (Plume/Messenger hoặc user tự chọn mode).
  private func effectiveTypingStrategy(
    plan: EmitPlan,
    backspaceCount: Int,
    diffCharCount: Int
  ) -> SendingStrategy {
    let appStrategy = AppCompatibilityRegistry.getStrategy(for: activeApp)

    if sendsViaAXDirect(plan) {
      return .axDirect
    }
    if backspaceCount <= 1 && diffCharCount <= 1 {
      if AppCompatibilityRegistry.keepsCushionOnSmallDiffs(
        bundleId: activeApp, userMode: AppCompatibilityRegistry.userSendingMode(for: activeApp))
      {
        return appStrategy
      }
      return .batch
    }
    return appStrategy
  }

  private func sendsViaAXDirect(_ plan: EmitPlan) -> Bool {
    if case .axDirect = AppCompatibilityRegistry.getStrategy(for: activeApp) { return true }
    return plan.fieldIsBrowserChrome
  }

  // MARK: - Spell Decision & Macro Commit

  @discardableResult
  func applySpellDecisionAndAdvance(
    endingChar: Character,
    swallowEndingChar: Bool
  ) -> Bool {
    guard applySpellDecisionOnCommit(
      endingChar: endingChar,
      swallowEndingChar: swallowEndingChar
    ) else {
      return false
    }
    newWord(storePrevious: false)
    return true
  }

  @discardableResult
  private func applySpellDecisionOnCommit(
    endingChar: Character,
    swallowEndingChar: Bool
  ) -> Bool {
    let rawInput = String(wordBuffer.keys)
    let current = wordBuffer.transformed
    guard !rawInput.isEmpty, !current.isEmpty else {
      return false
    }
    guard Defaults[.spellCheckEnabled] else {
      return false
    }
    if current == rawInput {
      return false
    }

    let needsRecovery = wordBuffer.wordState.needsRecovery(options: .currentFromDefaults)
      || wordBuffer.stopProcessing
    let decision = spellDecisionEngine.evaluate(
      rawInput: rawInput,
      transformed: current,
      needsRecovery: needsRecovery
    )

    UsageStatistics.shared.recordCommit(
      decision: decision,
      rawInput: rawInput,
      transformed: current,
      appBundleId: activeApp.isEmpty ? nil : activeApp,
      needsRecovery: needsRecovery
    )

    switch decision {
    case .keepVietnamese, .keepRaw:
      return false

    case .restoreRawEnglish(let restoredWord):
      if current == restoredWord {
        return false
      }
      let target = MacroExpander.commitReplacementTarget(
        word: restoredWord,
        endingChar: endingChar,
        includeEndingChar: swallowEndingChar
      )
      let plan = emitPlan()
      if sendsViaAXDirect(plan) {
        sendTypedReplacement(plan.replacement(from: current, to: target))
        return true
      }
      let source = EventSimulator.privateEventSource()
      let typed = plan.usesNFC
        ? target.precomposedStringWithCanonicalMapping
        : target
      EventSimulator.simulationQueueAsync {
        EventSimulator.sendOptionBackspace(source: source)
        usleep(10_000)
        EventSimulator.sendString(typed, source: source)
      }
      return true

    case .suggest(let suggestions):
      guard
        Defaults[.autoApplyHighConfidenceSuggestion],
        let top = suggestions.first,
        top.score >= 0.88
      else {
        return false
      }

      let target = MacroExpander.commitReplacementTarget(
        word: MacroExpander.matchCase(of: current, to: top.word),
        endingChar: endingChar,
        includeEndingChar: swallowEndingChar
      )
      sendTypedReplacement(emitPlan().replacement(from: current, to: target))
      return true
    }
  }

  @discardableResult
  func expandMacroAndAdvance(endingChar: Character) -> Bool {
    guard expandMacroIfMatch(endingChar: endingChar) else { return false }
    newWord(storePrevious: false)
    return true
  }

  private func expandMacroIfMatch(endingChar: Character) -> Bool {
    guard Defaults[.macroEnabled] else { return false }

    let current = wordBuffer.transformed
    guard
      let target = MacroExpander.macroTarget(
        for: current,
        endingChar: endingChar,
        macros: MacroExpander.cachedMacros
      )
    else {
      return false
    }

    sendTypedReplacement(emitPlan().replacement(from: current, to: target))
    return true
  }

  // MARK: - Field Classification & Compatibility Forwarders

  func usesNFCForFocusedField() -> Bool {
    usesNFC(forFieldKind: currentFieldKind())
  }

  func focusedFieldIsBrowserChrome() -> Bool {
    isBrowserChrome(forFieldKind: currentFieldKind())
  }

  private func currentFieldKind() -> Focused.FieldKind {
    focusedFieldKind
  }

  private func usesNFC(forFieldKind kind: Focused.FieldKind) -> Bool {
    if AppCompatibilityRegistry.usesNFCGraphemeStorage(bundleId: activeApp) { return true }
    switch kind {
    case .webContent, .unknown:
      return AppCompatibilityRegistry.isBrowserApp(bundleId: activeApp)
    case .nativePanel, .windowField:
      return true
    }
  }

  private func isBrowserChrome(forFieldKind kind: Focused.FieldKind) -> Bool {
    kind == .windowField
      && !AppCompatibilityRegistry.usesNFCGraphemeStorage(bundleId: activeApp)
  }

  static func canonicalAppBundle(focused: String, frontmost: String?) -> String {
    AppCompatibilityRegistry.canonicalAppBundle(focused: focused, frontmost: frontmost)
  }

  static func usesNFCGraphemeStorage(bundleId: String) -> Bool {
    AppCompatibilityRegistry.usesNFCGraphemeStorage(bundleId: bundleId)
  }

  static func isBrowserApp(bundleId: String) -> Bool {
    AppCompatibilityRegistry.isBrowserApp(bundleId: bundleId)
  }

  static func keepsCushionOnSmallDiffs(
    bundleId: String, userMode: AppSendingMode? = nil
  ) -> Bool {
    AppCompatibilityRegistry.keepsCushionOnSmallDiffs(bundleId: bundleId, userMode: userMode)
  }

  static func macroTarget(
    for current: String,
    endingChar: Character,
    macros: [Macro]
  ) -> String? {
    MacroExpander.macroTarget(for: current, endingChar: endingChar, macros: macros)
  }

  static func autoCapitalizedVariant(of trigger: String) -> String? {
    MacroExpander.autoCapitalizedVariant(of: trigger)
  }

  static func macroReplacement(
    for current: String,
    endingChar: Character,
    macros: [Macro],
    usesNFC: Bool
  ) -> (backspaceCount: Int, diffChars: [Character])? {
    MacroExpander.macroReplacement(
      for: current, endingChar: endingChar, macros: macros, usesNFC: usesNFC)
  }

  static func commitReplacementTarget(
    word: String,
    endingChar: Character,
    includeEndingChar: Bool
  ) -> String {
    MacroExpander.commitReplacementTarget(
      word: word, endingChar: endingChar, includeEndingChar: includeEndingChar)
  }

  static func matchCase(of source: String, to replacement: String) -> String {
    MacroExpander.matchCase(of: source, to: replacement)
  }
}
