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

  /// 1.9.7: stage flag cho anywhere `dd` → `đ` toggle trong recovery state.
  /// - 0 = none (chưa toggle): nếu 'd' tới và transformed.last == 'd' → toggle ON.
  /// - 1 = toggle ON ('đ' đang hiển thị): nếu 'd' tới → toggle OFF.
  /// - 2 = toggle OFF ('dd' raw): subsequent 'd' đều no-op (frozen).
  /// Reset về 0 trên non-'d' char hoặc newWord.
  var ddToggleStage: Int = 0

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
    ddToggleStage = 0
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
    if keys.isEmpty {
      if let prev = previousWordState {
        wordState = prev
        previousWordState = nil
        keys = Array(wordState.chuKhongDau)
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

    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If it's a simple 1-char deletion, let the OS handle it
    if numBackspaces == 1 && diffChars.isEmpty {
      return (0, [])
    }

    return (numBackspaces, diffChars)
  }

  mutating func reconstructState(for replayedKeys: [Character], engine: TypingMethod) {
    keys = replayedKeys

    // Clear state
    stopProcessing = false
    stoppedByEnglishWord = false
    wordState = .empty
    lastValidSnapshot = nil

    if keys.isEmpty {
      transformed = ""
      return
    }

    var currentKeys: [Character] = []
    var currentSnapshot: Snapshot? = nil
    // 1.9.7: local stage cho anywhere-dd toggle khi replay recovery state.
    var localDdToggleStage = 0

    for k in keys {
      let lastTransformedForStep = transformed
      currentKeys.append(k)
      let keysStr = String(currentKeys)

      // Save snapshot BEFORE pushing if the state was valid
      if !stopProcessing {
        currentSnapshot = Snapshot(
          wordState: wordState,
          keys: Array(currentKeys.dropLast()),
          transformed: transformed,
          stopProcessing: false,
          stoppedByEnglishWord: false
        )
      }

      let telexToneKeys: Set<Character> = ["s","S","f","F","r","R","x","X","j","J"]
      let isPossibleToneCancel = wordState.dauThanh != .bang && telexToneKeys.contains(k)

      // 1. Check instant restore English
      if LexiconManager.shared.isInstantRestoreEnglish(keysStr), !isPossibleToneCancel {
        stopProcessing = true
        stoppedByEnglishWord = true
        transformed = keysStr
        wordState = wordState.push(k)
        if let snap = currentSnapshot {
          lastValidSnapshot = snap
        }
        continue
      }

      // 2. Check impossible cluster
      if isImpossibleCluster(currentKeys, engine: engine) {
        stopProcessing = true
        transformed = keysStr
        wordState = wordState.push(k)
        if let snap = currentSnapshot {
          lastValidSnapshot = snap
        }
        continue
      }

      if stopProcessing {
        // 1.9.7: anywhere-dd toggle khi replay recovery — match forward typing.
        if k == "d" || k == "D" {
          switch localDdToggleStage {
          case 0:
            if let last = transformed.last, last == "d" || last == "D" {
              let lastIsUpper = last == "D"
              transformed.removeLast()
              transformed.append(lastIsUpper ? "Đ" : "đ")
              localDdToggleStage = 1
              wordState = wordState.push(k)
              continue
            }
          case 1:
            if let last = transformed.last, last == "đ" || last == "Đ" {
              let wasUpper = last == "Đ"
              transformed.removeLast()
              transformed.append(contentsOf: wasUpper ? "DD" : "dd")
              localDdToggleStage = 2
              wordState = wordState.push(k)
              continue
            }
          case 2:
            wordState = wordState.push(k)
            continue
          default:
            break
          }
        } else {
          localDdToggleStage = 0
        }
        transformed.append(k)
        wordState = wordState.push(k)
        continue
      }

      let result = engine.push(char: k, state: wordState)
      wordState = result.state

      if wordState.needsRecovery {
        stopProcessing = true
        transformed = keysStr
        if let snap = currentSnapshot {
          lastValidSnapshot = snap
        }
      } else {
        transformed = wordState.transformed
      }

      if engine.shouldStopProcessing(keyStr: keysStr) {
        stopProcessing = true
        // 2.0.2 bug-fix (J2): không append nếu engine vừa THÊM combining
        // diacritic (vd Telex `to`+`o` → `tô` — grapheme count vẫn 2 nhưng
        // NFD scalar count tăng từ 2 → 3). Trước đây chỉ check
        // `count ==` → bug "tools" → "toools". Vẫn cho append khi
        // engine BỎ diacritic (vd VNI a11 toggle: NFD giảm 2 → 1) để
        // user thấy ký tự command thô như '1', '6'…
        if WordBuffer.shouldAppendRawKey(
          newTransformed: transformed,
          oldTransformed: lastTransformedForStep
        ) {
          transformed.append(k)
          wordState = wordState.push(k)
        }
      }
    }
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

    // v2.3.7: UNIVERSAL anywhere-DD toggle — fire trước cả `stopProcessing`
    // branch, đảm bảo hoạt động khi:
    //   - Free Mark Mode bật (`needsRecovery` bypass → stopProcessing
    //     không bao giờ được set bởi validator).
    //   - Buffer ở state "valid VN" mà user vẫn muốn DD = Đ (vd
    //     all-caps abbreviation như `QDD → QĐ`, `BCTDD → BCTĐ`).
    //
    // Conflict avoidance:
    //   - Telex initial `dd → đ` (chuKhongDau=[d]+push d): khi đó
    //     `transformed.count==1` ("d"), không match điều kiện count>=2.
    //     Telex.push tự xử lý, transformed thành "đ" (1 char).
    //   - Toggle-off / frozen state (stage 1, 2): khi rule mới fire,
    //     set stage=1. Lần kế tiếp char d/D đến: rule mới check stage==0,
    //     skip → existing anywhere-DD ở dưới xử lý stage 1→2 (toggle off).
    //   - Khi second-to-last cũng là d/D (vd "vcdd" + d): rule mới skip
    //     để existing logic xử lý frozen state đúng cách.
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
      wordState = wordState.push(char)
      // Set stopProcessing để toggle-off (3rd d) đi qua existing branch.
      if !stopProcessing {
        stopProcessing = true
        if !snapshot.stopProcessing {
          lastValidSnapshot = snapshot
        }
      }
      return
    }

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
      // 1.9.7: anywhere `dd` ↔ `đ` toggle trong recovery state.
      // State machine ddToggleStage:
      //   0 → 1: 2nd 'd' liên tiếp (transformed.last == 'd') → toggle ON ('d' → 'đ').
      //   1 → 2: 3rd 'd' (transformed.last == 'đ') → toggle OFF ('đ' → 'dd').
      //   2: subsequent 'd' = no-op (frozen, giữ nguyên dd).
      //   non-'d' char → reset về 0.
      if char == "d" || char == "D" {
        switch ddToggleStage {
        case 0:
          // Toggle ON nếu last char là 'd'/'D'.
          if let last = transformed.last, last == "d" || last == "D" {
            let lastIsUpper = last == "D"
            transformed.removeLast()
            transformed.append(lastIsUpper ? "Đ" : "đ")
            ddToggleStage = 1
            wordState = wordState.push(char)
            return
          }
          // first 'd' (or last char not 'd') → append bình thường, stage=0.
        case 1:
          // Toggle OFF nếu last char là 'đ'/'Đ'.
          if let last = transformed.last, last == "đ" || last == "Đ" {
            let wasUpper = last == "Đ"
            transformed.removeLast()
            transformed.append(contentsOf: wasUpper ? "DD" : "dd")
            ddToggleStage = 2
            wordState = wordState.push(char)
            return
          }
        case 2:
          // Frozen — no-op (keys đã append qua line 277, transformed giữ nguyên).
          wordState = wordState.push(char)
          return
        default:
          break
        }
      } else {
        ddToggleStage = 0
      }
      transformed.append(char)
      wordState = wordState.push(char)
      // v2.3.8: nếu trong recovery, keysStr giờ match English instant-restore
      // (vd "google" sau khi append 'e'), mark stoppedByEnglishWord=true để
      // commit-time spell decision xử lý đúng (restore raw). Không thay đổi
      // transformed (đã là raw). Mục đích: cải thiện handoff giữa intermediate
      // recovery state và full-word English recognition cho các app
      // autocomplete (Chrome/Google) — tránh artifacts từ partial replacement.
      if LexiconManager.shared.isInstantRestoreEnglish(keysStr) {
        stoppedByEnglishWord = true
      }
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
          // 2.0.2 bug-fix (J2): xem chú thích trong reconstructState.
          if WordBuffer.shouldAppendRawKey(
            newTransformed: transformed,
            oldTransformed: lastTransformed
          ) {
            transformed.append(char)
            wordState = wordState.push(char)
          }
        }
        // Check if the full replayed word is an English word.
        // 1.8.4: dùng isInstantRestoreEnglish (narrow 126 + userAllow) khớp
        // philosophy ở line 359-360 (doubled tone check). Tránh regression
        // v1.7.9 khi full enLexicon 9826 chứa "teen"/"men"/"tens"/... match
        // Telex VN pattern → bị nhầm sang raw English thay vì giữ VN.
        if LexiconManager.shared.isInstantRestoreEnglish(keysStr) {
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

    // 1.7.5: detect tone-cancel intent (Telex double-tap tone key xoá dấu).
    // Nếu state đang có tone applied AND char là tone key → user xoá dấu,
    // KHÔNG được lock raw English (vd "ả" + "r" để cancel hỏi → "a" thay vì
    // bị giữ "arr"). Engine.push tiếp theo sẽ toggle tone off.
    let telexToneKeys: Set<Character> = ["s","S","f","F","r","R","x","X","j","J"]
    let isPossibleToneCancel = wordState.dauThanh != .bang && telexToneKeys.contains(char)

    // Doubled Tone Mark Preservation: if raw keys contains consecutive
    // doubled tone marks, preserve it raw if it forms an English word.
    // 1.7.10: dùng `isInstantRestoreEnglish` (list HẸP: embedded 126 +
    // userAllow) thay vì `isEnglishWord` (full 9826) để tránh collision
    // telex stems "cos/the/tie/hop" trong package EN.
    if doubledTones.contains(where: { keysStr.contains($0) }),
       LexiconManager.shared.isInstantRestoreEnglish(keysStr),
       !isPossibleToneCancel {
      stopProcessing = true
      stoppedByEnglishWord = true
      transformed = String(keys)
      wordState = wordState.push(char)

      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    // Instantaneous English word restoration: if the raw keys form a known
    // English word, preserve it raw. 1.7.10: dùng instant-restore narrow list.
    if LexiconManager.shared.isInstantRestoreEnglish(keysStr),
       !isPossibleToneCancel {
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
      // 2.0.2 bug-fix (J2): xem chú thích trong reconstructState.
      // Đây là path main push.
      if WordBuffer.shouldAppendRawKey(
        newTransformed: transformed,
        oldTransformed: lastTransformed
      ) {
        transformed.append(char)
        wordState = wordState.push(char)
      }
    }
  }

  /// 2.0.2 (J2): quyết định có append raw key vào `transformed` không sau
  /// khi `engine.shouldStopProcessing(...)` return true. Logic:
  /// - Nếu engine vừa THÊM combining diacritic (vd Telex 'to'+'o' → 'tô'):
  ///   grapheme count giữ nguyên, NFD scalar count tăng → engine đã consume
  ///   keystroke vào diacritic → KHÔNG append (tránh bug "tools" → "toools").
  /// - Nếu engine vừa BỎ diacritic (vd VNI a11 toggle "á" → "a"):
  ///   grapheme count giữ nguyên, NFD scalar count GIẢM → user thực sự gõ
  ///   command key thứ 2 → cần emit raw ký tự (vd '1') để user thấy.
  /// - Nếu count thay đổi (vd Telex 'aaa' cancel "â" → "aa"): engine đã tự
  ///   bù vào transformed → KHÔNG append.
  /// - Nếu count + NFD giống nhau (engine no-op trên character này):
  ///   APPEND raw key.
  static func shouldAppendRawKey(newTransformed: String, oldTransformed: String) -> Bool {
    // Khác grapheme count → engine đã tự reflect keystroke vào output.
    guard newTransformed.count == oldTransformed.count else { return false }
    let nfdNew = newTransformed.decomposedStringWithCanonicalMapping.unicodeScalars.count
    let nfdOld = oldTransformed.decomposedStringWithCanonicalMapping.unicodeScalars.count
    // NFD tăng = combining diacritic vừa thêm → engine consumed → KHÔNG append.
    return nfdNew <= nfdOld
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

    // Edge (Chromium — inline autocomplete cần Shift+Left)
    // Excel cố tình KHÔNG nằm trong danh sách: Excel không có inline autocomplete,
    // và Shift+Left trong Excel = mở rộng selection sang cell trái → nhảy/bôi ô.
    // Excel vẫn dùng .hybrid(1000μs) qua appStrategies (EventSimulator.swift:94).
    "com.microsoft.edge", "com.microsoft.Edge",
  ]
  static let NewWordKeys = "`!@#$%^&*()-=[]\\;',./~_+{}|:\"<>?"
  static let NewWordTaskKeys: [TaskKey] = [.Enter, .Space, .Tab]
  static let JumpTaskKeys: [TaskKey] = [.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight]

  public var engine: TypingMethod
  public var typingMethod: TypingMethods
  public var keyLayout = KeyboardUS()
  public var activeApp = ""
  public var isSearchOrComboFocused = false
  public private(set) var lastSuggestions: [SuggestionCandidate] = []

  /// 2.0 (B1): cached Window Title Rule overrides cho activeApp.
  /// AppState cập nhật giá trị này khi đổi app hoặc focus.
  public var ruleOverrides: ResolvedRuleOverrides = .init()

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
  // 2.0.2 (J1): xoá `activePredictionCandidates: [String]` — predict về top-1
  // only, không cần lưu danh sách candidates.

  // 2.0 (A5): auto-capitalize state machine — tracking khi user gõ
  // sentence-ending punctuation (. ! ?) hoặc Enter, để uppercase chữ cái
  // đầu của từ kế tiếp.
  // - `sentenceJustEnded`: punctuation . ! ? vừa được commit (chưa thấy space).
  // - `pendingCapitalize`: đã ở vị trí "đầu câu" (sau Enter hoặc . ! ?+space)
  //   — chữ cái text kế tiếp sẽ được uppercase.
  private var sentenceJustEnded = false
  private var pendingCapitalize = false

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
    // 2.0 (C4): cập nhật adaptive flush delay theo rule (nếu có) hoặc
    // global default. Đọc ruleOverrides hiện tại — AppState gán trước
    // khi gọi changeActiveApp khi đổi app.
    let delay = ruleOverrides.flushDelayMs > 0
      ? ruleOverrides.flushDelayMs
      : Defaults[.cgEventFlushDelayMs]
    EventSimulator.adaptiveFlushDelayMs = max(0, min(500, delay))
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
    // 1.6.1/1.7.7/1.8.1: Tab handling khi prediction enabled — SMART-DETECT buffer.
    // - Buffer sạch (sau commit qua Space, caret đã ở sau 1 space): chèn THẲNG
    //   prediction, KHÔNG leading space. Trước 1.8.1 chèn " prediction" → thừa
    //   space ("đoán  từ" thay vì "đoán từ").
    // - Buffer có từ chưa commit: commit từ qua spell decision (emit space)
    //   rồi chèn prediction (không leading space — space đã được emit).
    //   User có thể gõ "viet" + Tab → "việt Nam" (commit + insert prediction).
    // - Nếu không có activePrediction → fall-through cho Tab pass-through
    //   (legitimate form navigation / tab indent).
    if taskKey == .Tab,
       Defaults[.wordPredictionEnabled],
       let prediction = activePrediction
    {
      injectAcceptedPrediction(prediction)
      return nil  // swallow Tab
    }

    if InputProcessor.NewWordTaskKeys.contains(taskKey) {
      // 2.0 (A5): Enter ALWAYS đánh dấu đầu câu kế tiếp. Space chỉ propagate
      // pendingCapitalize nếu sentence-ending punctuation vừa được commit.
      updateCapitalizeStateForTaskKey(taskKey)

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

  private func handleTextChar(_ incomingChar: Character, event: CGEvent) -> Unmanaged<CGEvent>? {
    var newChar = incomingChar

    // 2.0.2 (J1): digit-selection 1/2/3 đã bị xoá vì dễ nhầm với gõ số
    // trong văn bản. Prediction về đơn giản: chỉ top-1, Tab accept.

    // Check if this is a word-ending character (punctuation, etc.) BEFORE processing
    if let _ = InputProcessor.NewWordKeys.firstIndex(of: newChar) {
      // 2.0 (A5): cập nhật state đánh dấu sentence-ending punctuation.
      updateCapitalizeStateForPunctuation(newChar)

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

    // 2.0 (A5): nếu đang pending capitalize và char là chữ cái lowercase,
    // uppercase nó trước khi push vào buffer. Engine xử lý 'W' như 'w'
    // (Telex case-insensitive cho phụ âm). Output sẽ có chữ hoa đầu câu.
    if Defaults[.autoCapitalizeEnabled],
       pendingCapitalize,
       newChar.isLetter,
       newChar.isLowercase {
      let upperString = String(newChar).uppercased()
      if let upperChar = upperString.first {
        newChar = upperChar
      }
      pendingCapitalize = false
      sentenceJustEnded = false
    } else if !newChar.isWhitespace {
      // Mọi char không phải whitespace → reset state (đã không còn ở đầu câu).
      pendingCapitalize = false
      sentenceJustEnded = false
    }

    push(char: newChar)
    let isAutocompleteApp = isFixAutocompleteApp()
    // v2.3.8: dùng NFD-aware diff cho FixAutocompleteApps để match scalar
    // count với browser storage (Chrome decomposes "ô" → "o" + combining ̂).
    // Tránh bug "google → gooogle" do Shift+Left count thiếu.
    let (numBackspaces, diffChars) = isAutocompleteApp
      ? EventSimulator.calcKeyStrokesNFD(from: lastTransformed, to: transformed)
      : EventSimulator.calcKeyStrokes(from: lastTransformed, to: transformed)

    // If the only change is the new character itself, let it pass through
    if let firstDiffChar = diffChars.first,
      diffChars.count == 1 && firstDiffChar == newChar && numBackspaces == 0
    {
      return Unmanaged.passUnretained(event)
    }

    if isAutocompleteApp {
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

  // MARK: - 2.0 (A2): Prediction Acceptance

  /// Chấp nhận một prediction (Tab hoặc digit 1/2/3) — inject vào caret,
  /// cập nhật n-gram window, ẩn HUD. Re-fetches top-1 prediction nếu
  /// buffer còn từ chưa commit (commit qua space trước rồi chèn dự đoán).
  private func injectAcceptedPrediction(_ prediction: String) {
    if wordBuffer.wordState.isBlank {
      // Caret đã ở sau space của commit trước. Chèn thẳng, không leading space.
      newWord(storePrevious: false)
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: 0,
        diffChars: Array(prediction),
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      prev2Committed = prev1Committed
      prev1Committed = prediction.lowercased()
    } else {
      // Buffer có từ chưa commit: commit qua space rồi chèn prediction.
      applySpellDecisionOnCommit(endingChar: " ", swallowEndingChar: true)
      newWord(storePrevious: true)
      // Recompute prediction sau commit (prev1 đã đổi). Nếu HUD lúc đó
      // hiển thị candidate cho từ KHÁC, mới recompute; giữ user-chosen
      // nếu họ explicitly chọn (digit-selection).
      let recomputed = PredictionEngine.shared.topPrediction(
        prev2: prev2Committed,
        prev1: prev1Committed ?? ""
      ) ?? prediction
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: 0,
        diffChars: Array(recomputed),
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      prev2Committed = prev1Committed
      prev1Committed = recomputed.lowercased()
    }
    activePrediction = nil
    DispatchQueue.main.async {
      PredictionHUDWindow.shared.hide()
    }
  }

  // MARK: - 2.0 (A5): Auto-Capitalize Helpers

  /// Sentence-ending punctuation set — chỉ . ! ? trigger capitalize.
  /// Các punctuation khác (,;: …) thuộc NewWordKeys nhưng KHÔNG phải
  /// sentence boundary nên không trigger.
  private static let sentenceEndingChars: Set<Character> = [".", "!", "?"]

  /// Cập nhật `sentenceJustEnded` khi punctuation được commit qua
  /// `handleTextChar` path. Chỉ . ! ? coi như kết thúc câu.
  private func updateCapitalizeStateForPunctuation(_ char: Character) {
    if Self.sentenceEndingChars.contains(char) {
      sentenceJustEnded = true
      pendingCapitalize = false  // chờ space để promote
    } else {
      // Punctuation khác (vd dấu phẩy) → reset, không phải đầu câu mới.
      sentenceJustEnded = false
      pendingCapitalize = false
    }
  }

  /// Cập nhật capitalize state khi gặp TaskKey (Space/Enter/Tab).
  /// - Enter: ALWAYS đánh dấu đầu câu kế tiếp.
  /// - Space: promote `sentenceJustEnded` thành `pendingCapitalize`.
  /// - Tab: bảo toàn state hiện tại (Tab thường dùng cho prediction
  ///   accept, không thay đổi cảm nhận câu).
  private func updateCapitalizeStateForTaskKey(_ taskKey: TaskKey) {
    switch taskKey {
    case .Enter:
      pendingCapitalize = true
      sentenceJustEnded = false
    case .Space:
      if sentenceJustEnded {
        pendingCapitalize = true
        sentenceJustEnded = false
      } else {
        // Space giữa các từ → reset pending nếu trước đó có lỡ set.
        pendingCapitalize = false
      }
    default:
      break
    }
  }

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

    // v1.7.0: bỏ guard spellCheckInSentenceEnabled — sub-toggle UI đã gộp vào
    // master `spellCheckEnabled`. Khi master ON thì luôn check cả single word
    // và in-sentence. Key vẫn giữ trong Defaults cho backward-compat.
    // 2.0 (B1): Window Title Rule có thể force tắt spell-check cho context này.
    guard Defaults[.spellCheckEnabled], !ruleOverrides.disableSpellCheck else {
      lastSuggestions = []
      return false
    }

    let needsRecovery = wordBuffer.wordState.needsRecovery || wordBuffer.stopProcessing
    let decision = spellDecisionEngine.evaluate(
      rawInput: rawInput,
      transformed: current,
      needsRecovery: needsRecovery
    )

    // 1.5.0: feed every committed word into UsageStatistics. No-op when the
    // user has turned stats off in Settings.
    // 1.7.4: forward needsRecovery → stats skip per-token counters cho commit
    // qua đường recovery (typo/parser-error) để top từ + đề xuất không nhiễu.
    UsageStatistics.shared.recordCommit(
      decision: decision,
      rawInput: rawInput,
      transformed: current,
      appBundleId: activeApp.isEmpty ? nil : activeApp,
      needsRecovery: needsRecovery
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

    // 2.0 (B1): Window Title Rule có thể force tắt prediction cho context này.
    if Defaults[.wordPredictionEnabled], !ruleOverrides.disablePrediction {
      // 2.0.2 (J1): chỉ top-1 prediction. Multi-candidate UI đã được xoá
      // (digit 1/2/3 dễ nhầm với gõ số trong văn bản).
      if let prediction = PredictionEngine.shared.topPrediction(
        prev2: prev2Committed,
        prev1: prev1Committed ?? ""
      ) {
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
      // 1.8.3: dùng select-and-replace cho commit-time restore khi
      // target app có autocomplete/strategy-mismatch (Word, Slack, Notion,
      // browsers, search fields...). Tránh bug "footer → foooter" do
      // backspace nuốt sai trên những app này. handleKey đã dùng pattern
      // tương tự ở line 791; đây cover thêm path commit-time restore.
      // v2.3.8: cho autocomplete apps, dùng NFD-aware diff để tránh
      // "google → gooogle" do scalar mismatch (Chrome NFD storage).
      let isAutocompleteAppRestore = isFixAutocompleteApp()
      let (numBackspaces, diffChars) = isAutocompleteAppRestore
        ? EventSimulator.calcKeyStrokesNFD(from: current, to: target)
        : EventSimulator.calcKeyStrokes(from: current, to: target)
      if isAutocompleteAppRestore {
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
        let telemetry = EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        observeTelemetry(telemetry, appLikelySensitive: false)
      }
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
    if isSearchOrComboFocused {
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
