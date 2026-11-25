//
//  WordBuffer.swift
//  vkey
//
//  Quản lý bộ đệm từ đang gõ, push/pop (Backspace), recovery mode và snapshot rollback.
//

import Foundation

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

  /// v4.23: chuỗi phím GỐC của từ vừa commit, đi kèm `previousWordState`.
  /// Giữ cả phím dấu để lần Backspace kế tiếp replay không mất dấu.
  var previousKeys: [Character] = []

  var wordState = TiengVietState.empty

  /// Last valid snapshot for single-step rollback out of recovery mode.
  var lastValidSnapshot: Snapshot?

  /// 1.9.7: stage flag cho anywhere `dd` → `đ` toggle trong recovery state.
  /// - 0 = none: nếu 'd' tới và transformed.last == 'd' → toggle ON.
  /// - 1 = toggle ON ('đ' đang hiển thị): nếu 'd' tới → toggle OFF.
  /// - 2 = toggle OFF ('dd' raw): subsequent 'd' đều no-op (frozen).
  var ddToggleStage: Int = 0

  /// F1 (v4.25): chỉ chốt NHÁNH NFD sau lần gửi ĐẦU TIÊN có `backspaceCount > 0`
  /// trong từ trên `.webContent`. Không chốt NFC, không chốt ở phím 1.
  var nfdEmitPlan: EmitPlan? = nil

  private static let impossible2LetterPrefixes: Set<String> = [
    "bl", "cl", "fl", "gl", "pl", "sl", "vl",
    "br", "cr", "dr", "fr", "gr", "pr", "wr",
    "st", "sm", "sn", "sp", "sc", "sk", "sw",
    // v4.23: "kr" đã gỡ để gõ tên riêng Tây Nguyên (Krông…).
    "tw", "dw", "sh", "ps", "pn", "ts", "kn",
    "bb", "cc", "ff", "gg", "hh", "jj", "kk", "ll",
    "mm", "nn", "pp", "qq", "rr", "ss", "tt", "vv",
    "xx", "zz",
  ]

  private static let impossible3LetterPrefixes: Set<String> = [
    "str", "thr", "phr", "chr", "sch", "scr", "spr",
  ]

  private static let doubledTones = ["ss", "ff", "rr", "xx", "jj"]

  func isImpossibleCluster(
    _ keys: [Character],
    engine: TypingMethod,
    options: EngineOptions = .currentFromDefaults
  ) -> Bool {
    guard !keys.isEmpty else { return false }

    // Rule 1: First letter cannot be f, j, z (or w for VNI) if allowed-zwjf is disabled
    if !options.allowedZWJF, let firstChar = keys.first {
      let lowerFirst = firstChar.lowercased()
      if lowerFirst == "f" || lowerFirst == "j" || lowerFirst == "z" {
        return true
      }
      if engine is VNI, lowerFirst == "w" {
        return true
      }
    }

    // Rule 2: Impossible 2-letter prefixes
    if keys.count >= 2 {
      let prefix2 = String(keys.prefix(2)).lowercased()
      // v2.13: khi allowedZWJF TẮT (Telex), w là phím dấu (w→ư, tw→tư, wr→ử)
      let wIsTelexMarkKey = !options.allowedZWJF && !(engine is VNI)
      if Self.impossible2LetterPrefixes.contains(prefix2),
        !(wIsTelexMarkKey && prefix2.contains("w"))
      {
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
    previousKeys = []
    if !wordState.isBlank {
      if storePrevious {
        previousWordState = wordState
        previousKeys = keys
      }
      wordState = .empty
    }

    keys = []
    lastValidSnapshot = nil
    stopProcessing = false
    stoppedByEnglishWord = false
    ddToggleStage = 0
    lastTransformed = ""
    transformed = ""
    nfdEmitPlan = nil
  }

  // MARK: - Pop (Backspace)

  mutating func pop(engine: TypingMethod, usesNFC: Bool) -> (Int, [Character]) {
    lastTransformed = transformed

    // Từ đang hiện đúng chuỗi phím thô của một từ không phải tiếng Việt (khoá English).
    if stoppedByEnglishWord, transformed == String(keys), !keys.isEmpty {
      keys.removeLast()
      transformed = String(keys)
      lastValidSnapshot = nil
      ddToggleStage = 0
      if keys.isEmpty {
        stopProcessing = false
        stoppedByEnglishWord = false
        wordState = .empty
      } else {
        stopProcessing = true
        stoppedByEnglishWord = true
        wordState = .empty
        for k in keys { wordState = wordState.push(k) }
      }
      return finishPop(usesNFC: usesNFC)
    }

    // Single-step rollback: recovery was caused by the latest keystroke
    if stopProcessing, let valid = lastValidSnapshot, keys.count == valid.keys.count + 1 {
      wordState = valid.wordState
      keys = valid.keys
      transformed = valid.transformed
      stopProcessing = valid.stopProcessing
      stoppedByEnglishWord = valid.stoppedByEnglishWord
      lastValidSnapshot = nil
      return finishPop(usesNFC: usesNFC)
    }

    // Normal pop: restore previous word on empty buffer
    if keys.isEmpty {
      if let prev = previousWordState {
        wordState = prev
        previousWordState = nil
        keys = previousKeys.isEmpty ? Array(wordState.chuKhongDau) : previousKeys
        previousKeys = []
        transformed = wordState.transformed
        lastTransformed = transformed
        stopProcessing = false
        lastValidSnapshot = nil
      }
      return (0, [])  // Let OS handle the backspace that brought us here
    }

    // Replay-based pop: drop the last character of keys and replay from scratch
    let remainingKeys = Array(keys.dropLast())
    reconstructState(for: remainingKeys, engine: engine)
    return finishPop(usesNFC: usesNFC)
  }

  /// Tính diff cho `pop`: nếu chỉ xoá đúng 1 ký tự thì trả `(0, [])` để OS tự xử lý.
  private func finishPop(usesNFC: Bool) -> (Int, [Character]) {
    let (numBackspaces, diffChars) = TextDiff.calcKeyStrokes(
      from: lastTransformed, to: transformed, usesNFC: usesNFC)
    if numBackspaces == 1 && diffChars.isEmpty {
      return (0, [])
    }
    return (numBackspaces, diffChars)
  }

  /// 1.9.7: anywhere-dd toggle trong recovery state (dùng chung cho `push` và `reconstructState`).
  /// Trả `true` nếu ký tự đã được tiêu thụ bởi cơ chế toggle `dd` ↔ `đ`.
  private mutating func applyRecoveryDDToggle(char: Character, options: EngineOptions) -> Bool {
    if char == "d" || char == "D" {
      switch ddToggleStage {
      case 0:
        if let last = transformed.last, last == "d" || last == "D" {
          let lastIsUpper = last == "D"
          transformed.removeLast()
          transformed.append(lastIsUpper ? "Đ" : "đ")
          ddToggleStage = 1
          wordState = wordState.push(char, options: options)
          return true
        }
      case 1:
        if let last = transformed.last, last == "đ" || last == "Đ" {
          let wasUpper = last == "Đ"
          transformed.removeLast()
          transformed.append(contentsOf: wasUpper ? "DD" : "dd")
          ddToggleStage = 2
          wordState = wordState.push(char, options: options)
          return true
        }
      case 2:
        wordState = wordState.push(char, options: options)
        return true
      default:
        break
      }
    } else {
      ddToggleStage = 0
    }
    return false
  }

  mutating func reconstructState(for replayedKeys: [Character], engine: TypingMethod) {
    keys = replayedKeys

    stopProcessing = false
    stoppedByEnglishWord = false
    wordState = .empty
    lastValidSnapshot = nil
    ddToggleStage = 0

    if keys.isEmpty {
      transformed = ""
      return
    }

    let options = EngineOptions.currentFromDefaults
    var currentKeys: [Character] = []
    var currentSnapshot: Snapshot? = nil

    for k in keys {
      let lastTransformedForStep = transformed
      currentKeys.append(k)
      let keysStr = String(currentKeys)

      if !stopProcessing {
        currentSnapshot = Snapshot(
          wordState: wordState,
          keys: Array(currentKeys.dropLast()),
          transformed: transformed,
          stopProcessing: false,
          stoppedByEnglishWord: false
        )
      }

      let isPossibleToneCancel = wordState.dauThanh != .bang && TiengViet.TelexToneKeyChars.contains(k)

      // 1. Check instant restore English
      if LexiconManager.shared.isInstantRestoreEnglish(keysStr), !isPossibleToneCancel,
         !Self.toneKeyCompletesVietnameseWord(char: k, state: wordState, engine: engine, options: options) {
        stopProcessing = true
        stoppedByEnglishWord = true
        transformed = keysStr
        wordState = wordState.push(k, options: options)
        if let snap = currentSnapshot {
          lastValidSnapshot = snap
        }
        continue
      }

      // 2. Check impossible cluster
      if isImpossibleCluster(currentKeys, engine: engine, options: options) {
        stopProcessing = true
        transformed = keysStr
        wordState = wordState.push(k, options: options)
        if let snap = currentSnapshot {
          lastValidSnapshot = snap
        }
        continue
      }

      if stopProcessing {
        if applyRecoveryDDToggle(char: k, options: options) {
          continue
        }
        transformed.append(k)
        wordState = wordState.push(k, options: options)
        continue
      }

      let result = engine.push(char: k, state: wordState, options: options)
      wordState = result.state

      if isPossibleToneCancel, wordState.dauThanh == .bang, currentKeys.count >= 4,
         LexiconManager.shared.isInstantRestoreEnglish(keysStr) {
        applyToneCancelEnglishLock(fullKeys: currentKeys, lastChar: k, options: options)
        continue
      }

      if wordState.needsRecovery(options: options) {
        stopProcessing = true
        transformed = keysStr
        if let snap = currentSnapshot {
          lastValidSnapshot = snap
        }
      } else {
        transformed = wordState.transformed(options: options)
      }

      if engine.shouldStopProcessing(keyStr: keysStr) {
        stopProcessing = true
        if WordBuffer.shouldAppendRawKey(
          newTransformed: transformed,
          oldTransformed: lastTransformedForStep
        ) {
          transformed.append(k)
          wordState = wordState.push(k, options: options)
        }
      }
    }
  }

  // MARK: - Push (New Character)

  mutating func push(char: Character, engine: TypingMethod) {
    let options = EngineOptions.currentFromDefaults
    let snapshot = Snapshot(
      wordState: wordState,
      keys: keys,
      transformed: transformed,
      stopProcessing: stopProcessing,
      stoppedByEnglishWord: stoppedByEnglishWord
    )

    keys.append(char)
    lastTransformed = transformed

    if (char == "d" || char == "D"),
       ddToggleStage == 0,
       transformed.count >= 2,
       let lastChar = transformed.last,
       lastChar == "d" || lastChar == "D",
       let secondLast = transformed.dropLast().last,
       secondLast != "d" && secondLast != "D" {
      let lastIsUpper = lastChar == "D"
      transformed.removeLast()
      transformed.append(lastIsUpper ? "Đ" : "đ")
      ddToggleStage = 1
      wordState = wordState.push(char, options: options)
      if !stopProcessing {
        stopProcessing = true
        if !snapshot.stopProcessing {
          lastValidSnapshot = snapshot
        }
      }
      return
    }

    var wasOnlyEnglishRestored = false
    let keysStr = String(keys).lowercased()
    if stopProcessing && stoppedByEnglishWord {
      if !Self.doubledTones.contains(where: { keysStr.contains($0) }) {
        wasOnlyEnglishRestored = true
      }
    }

    if stopProcessing && !wasOnlyEnglishRestored {
      if applyRecoveryDDToggle(char: char, options: options) {
        return
      }
      transformed.append(char)
      wordState = wordState.push(char, options: options)
      return
    }

    if wasOnlyEnglishRestored {
      stopProcessing = false
      stoppedByEnglishWord = false
      wordState = .empty
      var replayValid = true
      for k in keys {
        let result = engine.push(char: k, state: wordState, options: options)
        wordState = result.state
        if wordState.needsRecovery(options: options) {
          replayValid = false
          break
        }
      }
      if replayValid && !wordState.needsRecovery(options: options) {
        transformed = wordState.transformed(options: options)
        lastValidSnapshot = nil
        if engine.shouldStopProcessing(keyStr: String(keys)) {
          stopProcessing = true
          if WordBuffer.shouldAppendRawKey(
            newTransformed: transformed,
            oldTransformed: lastTransformed
          ) {
            transformed.append(char)
            wordState = wordState.push(char, options: options)
          }
        }
        let lastKeyIsToneKey = keys.last.map { TiengViet.TelexToneKeyChars.contains($0) } ?? false
        if LexiconManager.shared.isInstantRestoreEnglish(keysStr),
           !(lastKeyIsToneKey && wordState.dauThanh != .bang
             && transformed.count >= 2
             && LexiconManager.shared.isVietnameseWord(transformed)) {
          stopProcessing = true
          transformed = String(keys)
          if !snapshot.stopProcessing {
            lastValidSnapshot = snapshot
          }
        }
      } else {
        stopProcessing = true
        transformed = String(keys)
        wordState = TiengVietState.empty
        for k in keys { wordState = wordState.push(k, options: options) }
      }
      return
    }

    let isPossibleToneCancel = wordState.dauThanh != .bang && TiengViet.TelexToneKeyChars.contains(char)

    if Self.doubledTones.contains(where: { keysStr.contains($0) }),
       LexiconManager.shared.isInstantRestoreEnglish(keysStr),
       !isPossibleToneCancel {
      stopProcessing = true
      stoppedByEnglishWord = true
      transformed = String(keys)
      wordState = wordState.push(char, options: options)

      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    if LexiconManager.shared.isInstantRestoreEnglish(keysStr),
       !isPossibleToneCancel,
       !Self.toneKeyCompletesVietnameseWord(char: char, state: wordState, engine: engine, options: options) {
      stopProcessing = true
      stoppedByEnglishWord = true
      transformed = String(keys)
      wordState = wordState.push(char, options: options)

      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    if isImpossibleCluster(keys, engine: engine, options: options) {
      stopProcessing = true
      transformed = String(keys)
      wordState = wordState.push(char, options: options)

      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    let result = engine.push(char: char, state: wordState, options: options)
    wordState = result.state

    if isPossibleToneCancel, wordState.dauThanh == .bang, keys.count >= 4,
       LexiconManager.shared.isInstantRestoreEnglish(keysStr) {
      applyToneCancelEnglishLock(fullKeys: keys, lastChar: char, options: options)
      return
    }

    if wordState.needsRecovery(options: options) {
      stopProcessing = true
      transformed = String(keys)

      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
    } else {
      transformed = wordState.transformed(options: options)
      lastValidSnapshot = nil
    }

    if engine.shouldStopProcessing(keyStr: String(keys)) {
      stopProcessing = true
      if WordBuffer.shouldAppendRawKey(
        newTransformed: transformed,
        oldTransformed: lastTransformed
      ) {
        transformed.append(char)
        wordState = wordState.push(char, options: options)
      }
    }
  }

  /// 2.0.2 (J2): quyết định có append raw key vào `transformed` không sau khi
  /// `engine.shouldStopProcessing(...)` return true.
  static func shouldAppendRawKey(newTransformed: String, oldTransformed: String) -> Bool {
    guard newTransformed.count == oldTransformed.count else { return false }
    let nfdNew = newTransformed.decomposedStringWithCanonicalMapping.unicodeScalars.count
    let nfdOld = oldTransformed.decomposedStringWithCanonicalMapping.unicodeScalars.count
    return nfdNew <= nfdOld
  }

  mutating func applyToneCancelEnglishLock(
    fullKeys: [Character],
    lastChar: Character,
    options: EngineOptions = .currentFromDefaults
  ) {
    stopProcessing = true
    stoppedByEnglishWord = true
    transformed = String(fullKeys)
    wordState = wordState.push(lastChar, options: options)
    lastValidSnapshot = Self.rawEnglishPrefixSnapshot(fullKeys: fullKeys, options: options)
  }

  /// Raw-keys prefix snapshot cho single-step rollback sau tone-cancel EN lock.
  static func rawEnglishPrefixSnapshot(
    fullKeys: [Character],
    options: EngineOptions = .currentFromDefaults
  ) -> Snapshot {
    let prefixKeys = Array(fullKeys.dropLast())
    var prefixState = TiengVietState.empty
    for k in prefixKeys {
      prefixState = prefixState.push(k, options: options)
    }
    return Snapshot(
      wordState: prefixState,
      keys: prefixKeys,
      transformed: String(prefixKeys),
      stopProcessing: true,
      stoppedByEnglishWord: true
    )
  }

  static func toneKeyCompletesVietnameseWord(
    char: Character,
    state: TiengVietState,
    engine: TypingMethod,
    options: EngineOptions = .currentFromDefaults
  ) -> Bool {
    guard TiengViet.TelexToneKeyChars.contains(char) else { return false }
    let result = engine.push(char: char, state: state, options: options)
    guard !result.state.needsRecovery(options: options) else { return false }
    let word = result.state.transformed(options: options)
    return word.count >= 2 && LexiconManager.shared.isVietnameseWord(word)
  }
}
