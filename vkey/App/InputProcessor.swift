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
      // v2.13: khi allowedZWJF TẮT (Telex), w là PHÍM DẤU (w→ư, tw→tư, wr→ử)
      // chứ không phải phụ âm — các cluster chứa w ("tw","dw","sw","wr") không
      // còn "impossible", phải để engine xử lý thay vì khoá raw English.
      let wIsTelexMarkKey = !Defaults[.allowedZWJF] && !(engine is VNI)
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

  mutating func pop(engine: TypingMethod, usesNFC: Bool = true) -> (Int, [Character]) {
    lastTransformed = transformed

    // Single-step rollback: if we are in recovery and it was caused by the LATEST keystroke
    if stopProcessing, let valid = lastValidSnapshot, keys.count == valid.keys.count + 1 {
      wordState = valid.wordState
      keys = valid.keys
      transformed = valid.transformed
      stopProcessing = valid.stopProcessing
      stoppedByEnglishWord = valid.stoppedByEnglishWord
      lastValidSnapshot = nil

      let (numBackspaces, diffChars) = usesNFC
        ? EventSimulator.calcKeyStrokes(from: lastTransformed, to: transformed)
        : EventSimulator.calcKeyStrokesNFD(from: lastTransformed, to: transformed)

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

    let (numBackspaces, diffChars) = usesNFC
      ? EventSimulator.calcKeyStrokes(from: lastTransformed, to: transformed)
      : EventSimulator.calcKeyStrokesNFD(from: lastTransformed, to: transformed)

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
      // 4.13: cùng guard với forward path — phím tone hoàn thành từ VN hợp
      // lệ ("thi"+s → "thí") thì không khoá raw English khi replay.
      if LexiconManager.shared.isInstantRestoreEnglish(keysStr), !isPossibleToneCancel,
         !Self.toneKeyCompletesVietnameseWord(char: k, state: wordState, engine: engine) {
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

      // 4.14: cancel dấu (tone key lặp) + keys khớp instant-restore EN →
      // khoá raw đầy đủ như forward path ("pass" replay → "pass", không
      // "pas"). Cùng giới hạn ≥ 4 phím — giữ semantics cancel ngắn.
      // Snapshot = raw prefix (không phải state có dấu) để BS "pass"→"pas".
      if isPossibleToneCancel, wordState.dauThanh == .bang, currentKeys.count >= 4,
         LexiconManager.shared.isInstantRestoreEnglish(keysStr) {
        applyToneCancelEnglishLock(fullKeys: currentKeys, lastChar: k)
        continue
      }

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
        // 4.13: nếu phím CUỐI là tone key và kết quả replay là từ VN hợp lệ
        // ≥ 2 ký tự ("this" replay → "thí") thì giữ VN — nhất quán forward
        // path (of→ò/if→ì 1 ký tự vẫn instant-restore như cũ).
        // 4.14: chỉ khi kết quả CÒN dấu (dauThanh != bang) — phím tone cuối
        // mà kết quả hết dấu nghĩa là nó vừa CANCEL ("horses" → "hoe"),
        // không phải hoàn thành từ VN → vẫn restore raw EN.
        let lastKeyIsToneKey = keys.last.map { "sSfFrRxXjJ".contains($0) } ?? false
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
    // 4.13: "thi"+s → "thí" là từ VN hợp lệ trong khi keys "this" khớp
    // instant-restore — phím tone hoàn thành từ VN hợp lệ thì tiếng Việt
    // thắng (tiền lệ v2.8/v2.9: queen→quên, theme→thêm đã loại khỏi list
    // vì lý do này; "this" bị sót vì thêm từ v1.5.0 trước khi có quy tắc).
    if LexiconManager.shared.isInstantRestoreEnglish(keysStr),
       !isPossibleToneCancel,
       !Self.toneKeyCompletesVietnameseWord(char: char, state: wordState, engine: engine) {
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

    // 4.14: phím tone lặp lại vừa CANCEL dấu (post-push hết dấu) và toàn bộ
    // keys khớp instant-restore EN → user đang gõ từ EN có phím tone lặp
    // ("pass", "horses", "nurses", "business") → khoá raw ĐẦY ĐỦ ngay.
    // Trước đây đường append-1-phím cho ra "pas"/"hoe" (thiếu phím tone đầu
    // đã bị consume). GIỚI HẠN ≥ 4 phím: giữ nguyên semantics cancel ngắn
    // (testTelexToneToggle/testTelexToneCancelArrm: "ass"→"as", "arr"+m→
    // "arm" — flow VN double-tap xoá dấu rồi gõ tiếp; "ass"/"aff"/"arr"/
    // "axx"/"ajj" trong list KHÔNG được khoá). Cancel không khớp list
    // ("lisst"→"list", "thiss"→"this") cũng giữ nguyên.
    // Snapshot = raw prefix (không phải state có dấu trước cancel) để
    // backspace "pass"→"pas", không "pá".
    if isPossibleToneCancel, wordState.dauThanh == .bang, keys.count >= 4,
       LexiconManager.shared.isInstantRestoreEnglish(keysStr) {
      applyToneCancelEnglishLock(fullKeys: keys, lastChar: char)
      return
    }

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

  /// 4.14: khoá raw EN sau tone-cancel. Snapshot rollback phải là raw prefix
  /// (`"pas"`), không phải state Telex còn dấu (`"pá"`) — nếu lưu snapshot
  /// trước `engine.push` thì BS `"pass"` sẽ nhảy về `"pá"`.
  mutating func applyToneCancelEnglishLock(fullKeys: [Character], lastChar: Character) {
    stopProcessing = true
    stoppedByEnglishWord = true
    transformed = String(fullKeys)
    wordState = wordState.push(lastChar)
    lastValidSnapshot = Self.rawEnglishPrefixSnapshot(fullKeys: fullKeys)
  }

  /// Raw-keys prefix snapshot cho single-step rollback sau tone-cancel EN lock.
  static func rawEnglishPrefixSnapshot(fullKeys: [Character]) -> Snapshot {
    let prefixKeys = Array(fullKeys.dropLast())
    var prefixState = TiengVietState.empty
    for k in prefixKeys {
      prefixState = prefixState.push(k)
    }
    return Snapshot(
      wordState: prefixState,
      keys: prefixKeys,
      transformed: String(prefixKeys),
      stopProcessing: true,
      stoppedByEnglishWord: true
    )
  }

  /// 4.13: phím tone (s/f/r/x/j) áp vào state hiện tại cho ra từ VN hợp lệ
  /// → tiếng Việt thắng instant-restore ("thi"+s → "thí" thay vì giữ raw
  /// "this"). Chỉ tính khi engine không cần recovery; VNI không dùng chữ
  /// cái làm tone key nên push chỉ append → không bao giờ ra từ VN → guard
  /// vô hại. Yêu cầu từ VN ≥ 2 ký tự: "of"→"ò", "if"→"ì" (1 ký tự, có cặp
  /// legacyRestorePairs riêng) phải giữ instant-restore như trước. Chi phí
  /// chỉ phát sinh khi keys ĐÃ khớp list instant-restore (hiếm) nên không
  /// ảnh hưởng độ trễ gõ phím.
  static func toneKeyCompletesVietnameseWord(
    char: Character,
    state: TiengVietState,
    engine: TypingMethod
  ) -> Bool {
    let telexToneKeys: Set<Character> = ["s", "S", "f", "F", "r", "R", "x", "X", "j", "J"]
    guard telexToneKeys.contains(char) else { return false }
    let result = engine.push(char: char, state: state)
    guard !result.state.needsRecovery else { return false }
    let word = result.state.transformed
    return word.count >= 2 && LexiconManager.shared.isVietnameseWord(word)
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

    // v2.14: axDirect là strategy ĐẶC CHỦNG cho app nuốt synthetic event
    // (Spotlight) — auto-switch sang stepByStep sẽ vô hiệu hoá nó và loạn
    // chữ trở lại. Telemetry "fail" ở đây thường là false positive (Spotlight
    // là search field → bị đánh dấu nhạy cảm).
    if case .axDirect = currentStrategy { return }

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

  /// v3.9: phân loại field đang focus (push-based từ AppState) — quyết định
  /// diff NFC/NFD (`usesNFCForFocusedField`) và chiến lược gửi
  /// (`effectiveTypingStrategy` → axDirect cho omnibox Chrome).
  public var focusedFieldKind: Focused.FieldKind = .unknown
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
  // hiển thị trên HUD; `activePredictionAcceptsTab` chặn Tab nhận gợi ý stale
  // sau Enter/click/caret boundary.
  private var prev1Committed: String? = nil
  private var prev2Committed: String? = nil
  private var activePrediction: String? = nil
  private var activePredictionAcceptsTab = false
  // 2.0.2 (J1): xoá `activePredictionCandidates: [String]` — predict về top-1
  // only, không cần lưu danh sách candidates.

  // 2.0 (A5): auto-capitalize state machine.
  // - `sentenceJustEnded`: `. ! ?` vừa commit, chưa có space — chờ promote.
  // - `pendingCapitalize`: đầu câu thật (sau Enter, hoặc `. ! ?` rồi space).
  //   Chỉ khi flag này bật mới inject chữ hoa — tránh google.com.vn, 3.14…
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
    clearActivePrediction()
    updateAdaptiveFlushDelay()
    refreshWordPredictionState()
  }

  /// 2.0 (A5) fix: mọi thao tác DI CHUYỂN con trỏ / gián đoạn (click chuột, phím
  /// mũi tên, Home/End, Escape, tổ hợp Cmd/Ctrl/Alt, đổi app) làm mất ngữ cảnh
  /// "đầu câu". Phải huỷ trạng thái chờ viết hoa, nếu không chữ thường gõ ở vị trí
  /// con trỏ MỚI (giữa từ có sẵn) bị viết hoa nhầm (vd "sviet" → "Sviet").
  /// KHÔNG gọi trong đường commit Enter/Space (chúng cố ý đặt cờ để viết hoa từ kế).
  public func resetSentenceCapitalizeState() {
    pendingCapitalize = false
    sentenceJustEnded = false
  }

  /// Ẩn HUD / xoá prediction khi đoán từ không còn active (đổi app,
  /// rule, hoặc danh sách loại trừ).
  public func refreshWordPredictionState() {
    if !Self.isWordPredictionActive(bundleId: activeApp, ruleOverrides: ruleOverrides) {
      clearActivePrediction()
    }
  }

  /// Đoán từ bật globally, không bị Window Title Rule tắt, và app không nằm
  /// trong danh sách loại trừ.
  static func isWordPredictionActive(
    bundleId: String,
    ruleOverrides: ResolvedRuleOverrides = .init()
  ) -> Bool {
    guard Defaults[.wordPredictionEnabled] else { return false }
    guard !ruleOverrides.disablePrediction else { return false }
    guard !bundleId.isEmpty else { return false }
    return !isExcludedFromWordPrediction(bundleId: bundleId)
  }

  static func isExcludedFromWordPrediction(bundleId: String) -> Bool {
    let normalized = normalizedBundleIdentifier(bundleId)
    guard !normalized.isEmpty else { return false }
    return Defaults[.wordPredictionExcludedApps]
      .contains { normalizedBundleIdentifier($0) == normalized }
  }

  private func isWordPredictionActive() -> Bool {
    Self.isWordPredictionActive(bundleId: activeApp, ruleOverrides: ruleOverrides)
  }

  public func updateAdaptiveFlushDelay() {
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
    if !storePrevious {
      clearActivePrediction()
    }
  }

  public func pop() -> (Int, [Character]) {
    return wordBuffer.pop(engine: engine, usesNFC: usesNFCForFocusedField())
  }

  public func push(char: Character) {
    wordBuffer.push(char: char, engine: engine)
  }

  // MARK: - Main Input Handler

  public func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let isShift = flags.contains(.maskShift)
    // Caps Lock chỉ đảo hoa/thường cho PHÍM CHỮ; số/keypad/dấu câu không đổi.
    // Shift + Caps Lock trên chữ cái = chữ thường (XOR, đúng hành vi macOS).
    let isCapsLock = keyLayout.isLetterKey(keyCode: keyCode) && flags.contains(.maskAlphaShift)
    let shifted = isShift != isCapsLock

    // Handle modifier keys (Cmd, Ctrl, Alt) - clear word buffer
    if flags.contains(.maskCommand) || flags.contains(.maskControl)
      || flags.contains(.maskAlternate)
    {
      newWord()
      resetSentenceCapitalizeState()  // lệnh/điều hướng = gián đoạn ngữ cảnh câu
      return Unmanaged.passUnretained(event)
    }

    // Cập nhật changeCount để theo dõi paste thực — không reset word khi
    // clipboard đổi từ app khác (trước đây gây mất buffer giữa chừng).
    lastPasteboardChangeCount = NSPasteboard.general.changeCount

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
    // - Nếu không có activePrediction hợp lệ → fall-through cho Tab pass-through
    //   (legitimate form navigation / tab indent).
    if taskKey == .Tab,
       isWordPredictionActive(),
       activePredictionAcceptsTab,
       let prediction = activePrediction
    {
      if injectAcceptedPrediction(prediction) {
        return nil  // swallow Tab
      }
      return Unmanaged.passUnretained(event)
    }

    if InputProcessor.NewWordTaskKeys.contains(taskKey) {
      let hadBufferedWord = !wordBuffer.keys.isEmpty || !wordBuffer.wordState.isBlank
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
      // FIX (upstream parity — xkey 20260504 / gonhanh v1.0.131): chỉ Space mới
      // giữ `previousWordState` để cho phép Backspace re-edit từ vừa commit.
      // Enter/Tab tạo ranh giới (xuống dòng / chuyển field) → KHÔNG giữ history,
      // tránh Backspace-sau-Enter khôi phục từ dòng trước gây desync.
      if taskKey == .Space, !hadBufferedWord {
        clearActivePrediction()
      }
      newWord(storePrevious: taskKey == .Space)
    } else if taskKey == .Escape {
      resetSentenceCapitalizeState()  // Esc = gián đoạn, huỷ chờ viết hoa
      let orig = String(wordBuffer.keys)
      let currentTransformed = wordBuffer.transformed
      if !wordBuffer.wordState.isBlank && currentTransformed != orig {
        let usesNFC = usesNFCForFocusedField()
        let (numBackspaces, diffChars) = usesNFC
          ? EventSimulator.calcKeyStrokes(from: currentTransformed, to: orig)
          : EventSimulator.calcKeyStrokesNFD(from: currentTransformed, to: orig)
        let telemetry = sendTypedReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          appLikelySensitive: isFixAutocompleteApp()
        )
        newWord()
        return nil // swallow ESC event
      }
      newWord()
    } else if taskKey == .Delete {
      let (numBackspaces, diffChars) = pop()
      if numBackspaces > 0 || !diffChars.isEmpty {
        sendTypedReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          appLikelySensitive: isFixAutocompleteApp()
        )
        return nil
      }
    } else if InputProcessor.JumpTaskKeys.contains(taskKey) {
      newWord()
      resetSentenceCapitalizeState()  // mũi tên/Home/End dời con trỏ → huỷ chờ viết hoa
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

    // 2.0 (A5): viết hoa chữ cái đầu sau Enter hoặc sau . ! ? kèm space.
    // Không viết hoa ngay sau dấu chấm (domain 3.14, google.com.vn…).
    var didAutoCapitalize = false
    if Defaults[.autoCapitalizeEnabled],
       pendingCapitalize,
       newChar.isLetter,
       newChar.isLowercase
    {
      if let upperChar = String(newChar).uppercased().first {
        newChar = upperChar
      }
      pendingCapitalize = false
      sentenceJustEnded = false
      didAutoCapitalize = true
    } else if !newChar.isWhitespace {
      pendingCapitalize = false
      sentenceJustEnded = false
    }

    push(char: newChar)

    if didAutoCapitalize {
      sendTypedReplacement(
        backspaceCount: 0,
        diffChars: [newChar],
        appLikelySensitive: isFixAutocompleteApp()
      )
      return nil
    }
    // v2.3.14: revert v2.3.13 NFD diff. User confirmed still bug
    // "gooogle, foooter ở claude desktop hay bất kỳ đâu" ngay cả v2.3.13
    // → hypothesis "Chromium NFD scalar backspace" SAI.
    //
    // Bug "gooogle" do CGEvent round-trip mismatch (vkey buffer state đúng
    // nhưng actual display divergent). Không có fix universal vì mỗi app
    // text engine khác (NFC vs NFD storage × grapheme vs scalar backspace
    // — 4 combos, mỗi combo cần diff strategy khác). Revert về grapheme
    // diff như v2.3.11 — stable cho NFC apps, accept bug trong Chromium
    // apps cho đến khi có giải pháp đúng.
    //
    let usesNFC = usesNFCForFocusedField()
    let (numBackspaces, diffChars) = usesNFC
      ? EventSimulator.calcKeyStrokes(from: lastTransformed, to: transformed)
      : EventSimulator.calcKeyStrokesNFD(from: lastTransformed, to: transformed)

    // If the only change is the new character itself, let it pass through
    if let firstDiffChar = diffChars.first,
      diffChars.count == 1 && firstDiffChar == newChar && numBackspaces == 0
    {
      return Unmanaged.passUnretained(event)
    }

    sendTypedReplacement(
      backspaceCount: numBackspaces,
      diffChars: diffChars,
      appLikelySensitive: false
    )
    return nil
  }

  // MARK: - Helpers

  // MARK: - 2.0 (A2): Prediction Acceptance

  private func setActivePrediction(_ prediction: String, acceptsTab: Bool) {
    activePrediction = prediction
    activePredictionAcceptsTab = acceptsTab
    DispatchQueue.main.async {
      PredictionHUDWindow.shared.show(prediction: prediction)
    }
  }

  private func clearActivePrediction() {
    let hadPrediction = activePrediction != nil || activePredictionAcceptsTab
    activePrediction = nil
    activePredictionAcceptsTab = false
    guard hadPrediction else { return }
    DispatchQueue.main.async {
      PredictionHUDWindow.shared.hide()
    }
  }

  /// Chấp nhận một prediction (Tab hoặc digit 1/2/3) — inject vào caret,
  /// cập nhật n-gram window, ẩn HUD. Re-fetches top-1 prediction nếu
  /// buffer còn từ chưa commit (commit qua space trước rồi chèn dự đoán).
  private func injectAcceptedPrediction(_ prediction: String) -> Bool {
    let words = prediction
      .split(separator: " ", omittingEmptySubsequences: true)
      .map(String.init)
    if wordBuffer.wordState.isBlank {
      newWord(storePrevious: false)
      sendTypedReplacement(
        backspaceCount: 0,
        diffChars: Array(prediction),
        appLikelySensitive: isFixAutocompleteApp()
      )
      PredictionEngine.shared.learnAcceptedPhrase(
        prediction,
        prev2: prev2Committed,
        prev1: prev1Committed
      )
      if let last = words.last?.lowercased() {
        prev2Committed = words.count >= 2 ? words[words.count - 2].lowercased() : prev1Committed
        prev1Committed = last
      }
    } else {
      guard applySpellDecisionOnCommit(endingChar: " ", swallowEndingChar: true) else {
        clearActivePrediction()
        return false
      }
      newWord(storePrevious: true)
      let recomputed = PredictionEngine.shared.topPhrasePrediction(
        prev2: prev2Committed,
        prev1: prev1Committed ?? ""
      ) ?? prediction
      sendTypedReplacement(
        backspaceCount: 0,
        diffChars: Array(recomputed),
        appLikelySensitive: isFixAutocompleteApp()
      )
      PredictionEngine.shared.learnAcceptedPhrase(
        recomputed,
        prev2: prev2Committed,
        prev1: prev1Committed
      )
      let acceptedWords = recomputed
        .split(separator: " ", omittingEmptySubsequences: true)
        .map(String.init)
      if let last = acceptedWords.last?.lowercased() {
        prev2Committed = acceptedWords.count >= 2
          ? acceptedWords[acceptedWords.count - 2].lowercased()
          : prev1Committed
        prev1Committed = last
      }
    }
    clearActivePrediction()
    return true
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
  /// - Space: promote `sentenceJustEnded` thành `pendingCapitalize`;
  ///   space thừa khi đã `pendingCapitalize` thì giữ nguyên.
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
      } else if pendingCapitalize {
        // Space thừa sau đầu câu (vd ".  ") — vẫn chờ chữ hoa kế tiếp.
        break
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

  /// Gửi replacement với chiến lược đúng ngữ cảnh (axDirect cho omnibox Chrome…).
  @discardableResult
  private func sendTypedReplacement(
    backspaceCount: Int,
    diffChars: [Character],
    appLikelySensitive: Bool
  ) -> EventSendTelemetry {
    let strategy = effectiveTypingStrategy(
      backspaceCount: backspaceCount,
      diffCharCount: diffChars.count
    )
    let telemetry = EventSimulator.sendReplacement(
      backspaceCount: backspaceCount,
      diffChars: diffChars,
      strategy: strategy
    )
    observeTelemetry(telemetry, appLikelySensitive: appLikelySensitive)
    return telemetry
  }

  /// For tiny diffs (common during Telex tone mutation), force immediate batch sending
  /// to avoid async reordering with the next keystroke (e.g. "push" -> "pussh").
  private func effectiveTypingStrategy(backspaceCount: Int, diffCharCount: Int) -> SendingStrategy {
    // axDirect (set qua bundle-id getStrategy) KHÔNG được downgrade — đa số
    // transform dấu là bs=1+diff=1; downgrade về .batch sẽ gửi synthetic event
    // vào Spotlight và loạn chữ trở lại.
    if case .axDirect = strategyTracker.currentStrategy {
      return .axDirect
    }
    // v3.9: browser-chrome field (thanh địa chỉ Chrome…) có inline autocomplete
    // bôi đen → synthetic backspace lệch. Dùng axDirect (đọc value thật, xử lý
    // suffix-selection như Spotlight). axDirect fail → tự fallback synthetic.
    if focusedFieldIsBrowserChrome() {
      return .axDirect
    }
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

    // v2.3.18: UNIVERSAL SHORT-CIRCUIT — nếu vkey chưa transform input (current
    // == rawInput), bỏ qua ENTIRE spell decision logic. Trả về false để
    // endingChar pass-through (như khi spell check OFF).
    //
    // User report: "google → gooogle" CHỈ xảy ra khi bật spell check, tắt
    // thì không bug. v2.3.17 thử short-circuit restoreRawEnglish (chỉ 1 case)
    // không fix được — chứng tỏ bug có thể ở .suggest hoặc decision path khác.
    //
    // Universal short-circuit ở đây bypass MỌI spell decision path khi không
    // có gì để restore. Trade-off: mất prediction learning + usage stats cho
    // commit này, nhưng giải quyết bug-class.
    //
    // Vẫn áp dụng full spell decision cho real cases (current != rawInput):
    // - Vietnamese typing: "tieengs" → "tiếng" (transformed có dấu, khác raw).
    // - English with Telex tones: "text" → "tẽt" (e+x = nga tone, khác raw).
    if current == rawInput {
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
    if isWordPredictionActive() {
      PredictionEngine.shared.learnTransition(
        prev2: prev2Committed,
        prev1: prev1Committed,
        current: committedToken
      )
    }
    // Slide window
    prev2Committed = prev1Committed
    prev1Committed = committedToken

    // 2.0 (B1): Window Title Rule có thể force tắt prediction cho context này.
    // Prediction HUD luôn hướng dẫn nhận bằng Tab, nên chỉ hiện sau Space.
    if isWordPredictionActive(), endingChar == " " {
      // 2.0.2 (J1): chỉ top-1 prediction. Multi-candidate UI đã được xoá
      // (digit 1/2/3 dễ nhầm với gõ số trong văn bản).
      if let prediction = PredictionEngine.shared.topPhrasePrediction(
        prev2: prev2Committed,
        prev1: prev1Committed ?? ""
      ) {
        setActivePrediction(prediction, acceptsTab: true)
      } else {
        clearActivePrediction()
      }
    } else {
      clearActivePrediction()
    }

    switch decision {
    case .keepVietnamese, .keepRaw:
      lastSuggestions = []
      return false

    case .restoreRawEnglish(let restoredWord):
      lastSuggestions = []
      // v2.3.17: short-circuit khi current == restoredWord (đã raw rồi, không
      // cần restore). User confirm bug "google → gooogle" CHỈ xảy ra khi spell
      // check ON. Trace: cho "google" typing, recovery đã set transformed=
      // "google" (raw). Tại commit, evaluate returns .restoreRawEnglish("google").
      // current=="google" == restoredWord → không có gì để restore.
      //
      // Vẫn fire restoration logic (Option+Backspace + sendString) gây side-
      // effect trong nhiều app → bug. Khi current==restoredWord, return false
      // để space/endingChar pass-through như khi spell check OFF (đã proved
      // không bug).
      //
      // Vẫn giữ restoration cho real cases (vd "text" Telex → "tẽt" → restore
      // raw "text"). Những case này current != restoredWord nên đi qua path
      // cũ.
      if current == restoredWord {
        return false  // Let endingChar pass through via handleTaskKey/handleTextChar.
      }
      let target = Self.commitReplacementTarget(
        word: restoredWord,
        endingChar: endingChar,
        includeEndingChar: swallowEndingChar
      )
      // v2.3.15: Option+Backspace + sendString để wipe entire word + retype.
      // Lý do: trong các app có round-trip CGEvent issues (Chromium / Claude
      // desktop / thậm chí Notes với combining diacritic), display có thể
      // diverge khỏi vkey buffer state trong intermediate steps. Diff-based
      // approach (BS + retype diff chars) không sửa được vì vkey không biết
      // display thực tế. Option+Backspace là macOS standard "delete word"
      // shortcut — xóa từ cursor về đầu word, regardless of display state.
      // Sau khi xóa word, sendString target để retype toàn bộ word + endingChar.
      //
      // Trace "google" trong Notes / Claude desktop:
      // - Display before space (có thể bị bug): "gooogle" hoặc "google".
      // - Option+Backspace: delete word "gooogle" hoặc "google" → "".
      // - sendString "google ": insert correct word + space → "google ". ✓
      let source = CGEventSource(stateID: .privateState)
      EventSimulator.simulationQueueAsync {
        _ = EventSimulator.withAdaptiveFlush {
          EventSimulator.sendOptionBackspace(source: source)
          usleep(10_000)  // 10ms delay — đủ cho app process word deletion
          EventSimulator.sendString(target, source: source)
        }
      }
      observeTelemetry(EventSendTelemetry(
        attemptedTransform: true,
        createdEvents: true,
        usedAsyncQueue: true,
        touchedCharacters: current.count + target.count
      ), appLikelySensitive: false)
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

      // 4.12: giữ kiểu hoa/thường của từ user gõ — suggestion từ lexicon là
      // chữ thường, thay thẳng làm "Dinjhd" đầu câu thành "định" (mất hoa).
      let target = Self.commitReplacementTarget(
        word: Self.matchCase(of: current, to: top.word),
        endingChar: endingChar,
        includeEndingChar: swallowEndingChar
      )
      let usesNFC = usesNFCForFocusedField()
      let (numBackspaces, diffChars) = usesNFC
        ? EventSimulator.calcKeyStrokes(from: current, to: target)
        : EventSimulator.calcKeyStrokesNFD(from: current, to: target)
      sendTypedReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        appLikelySensitive: isFixAutocompleteApp()
      )
      return true
    }
  }

  /// v2.3.10: Detect khi nào nên dùng `sendSelectAndReplace` (Shift+Left) thay
  /// vì backspace-based replacement. Chỉ áp dụng cho **search fields / combo
  /// boxes** thực sự — nơi có inline autocomplete ghost text mà Shift+Left
  /// bao trùm đúng cách.
  ///
  /// Trước v2.3.10: cũng return true cho TẤT CẢ Chrome / Safari / Firefox /…
  /// (bundle ID match) — kể cả khi user đang gõ trong text area của Google
  /// Docs / Sheets / web app. Hệ quả: Shift+Left bị contenteditable JS handler
  /// của Docs bỏ qua → vkey gửi sendString sau Shift+Left mà selection chưa
  /// thay đổi → mọi syllable Vietnamese bị duplicate ("trình → trinình",
  /// "các → cacác", "kiểm → kiêmểm"…).
  ///
  /// Sau v2.3.10: chỉ check `isSearchOrComboFocused` (AX role = AXSearchField
  /// hoặc AXComboBox). Browser URL bar / Google search box vẫn matched (search
  /// field role) → giữ behavior cũ cho autocomplete URL. Web text area (Docs,
  /// Sheets, contenteditable) role = AXTextArea → fall through sang
  /// `sendReplacement` (backspace), hoạt động đúng trong contenteditable.
  ///
  /// `FixAutocompleteApps` list giữ lại cho documentation / future regression
  /// (vd nếu một browser không expose AX role đúng — chưa thấy case nào).
  func isFixAutocompleteApp() -> Bool {
    return isSearchOrComboFocused
  }

  /// v2.3.13: Phân biệt apps theo text storage model để chọn diff algorithm:
  /// - **NFC + grapheme backspace** (Apple native, Microsoft Office native):
  ///   Backspace xóa 1 grapheme. NFC precomposed Vietnamese (`ô` = 1 char).
  ///   Cần grapheme-based diff (`calcKeyStrokes`).
  /// - **NFD + scalar backspace** (Chromium, Electron, web inputs, default):
  ///   Backspace xóa 1 unicode scalar. NFD decomposed (`ô` = `o` + combining `̂`).
  ///   Cần NFD scalar-based diff (`calcKeyStrokesNFD`).
  ///
  /// Whitelist NFC apps theo bundle prefix. Mọi thứ khác giả định NFD.
  /// Lý do whitelist (conservative): NFC chỉ ở Apple + Office native — đếm được.
  /// Chromium/Electron app vô số, không enum nổi → default NFD.
  ///
  /// Native text editors / CAD (Sublime, BBEdit, Vectorworks…) lưu grapheme NFC —
  /// NFD diff gây backspace thừa, nuốt newline/ký tự dòng kế (Sublime Text).
  private static let nfcNativeEditorBundlePrefixes: [String] = [
    "com.sublimetext.",
    "com.barebones.bbedit",
    "com.macromates.TextMate",
    "org.vim.MacVim",
    "net.shinyfrog.bear",
    "pro.writer.mac",
    "net.nemetschek.vectorworks",
    "net.vectorworks.",
  ]

  static func usesNFCGraphemeStorage(bundleId: String) -> Bool {
    if bundleId.isEmpty { return true }  // fallback safe (Apple native)
    // Apple native apps (NSTextView/NSTextField/UITextView based)
    if bundleId.hasPrefix("com.apple.") { return true }
    for prefix in nfcNativeEditorBundlePrefixes {
      if bundleId.hasPrefix(prefix) { return true }
    }
    // Microsoft Office native (NOT Edge which is Chromium)
    let officeNative: Set<String> = [
      "com.microsoft.Word",
      "com.microsoft.Excel",
      "com.microsoft.Powerpoint",
      "com.microsoft.Outlook",
      "com.microsoft.onenote.mac",
      "com.microsoft.Office.Word",
      "com.microsoft.Office.Excel",
    ]
    if officeNative.contains(bundleId) { return true }
    // iWork
    if bundleId.hasPrefix("com.apple.iWork.") { return true }
    // Google Gemini app — native Swift app (Frameworks chỉ có Swift runtime
    // dylib). Bundle ID THẬT là "com.google.GeminiMacOS" (v3.4 ghi nhầm
    // "com.google.gemini" → rơi về NFD → mất chữ "nhập" → "nḥ̂p").
    // So sánh lowercased prefix để chịu được biến thể viết hoa/đuôi.
    if bundleId.lowercased().hasPrefix("com.google.gemini") { return true }
    // Telegram for macOS — native Swift/AppKit (bundle "ru.keepcoder.Telegram",
    // KHÔNG phải Qt "org.telegram.desktop"). Lưu NFC precomposed & xoá theo
    // GRAPHEME như app Apple, nhưng ô soạn tin là custom view nên AX không phân
    // loại được thành .windowField → rơi về NFD scalar diff → backspace THỪA ở
    // bước bỏ dấu cuối của cụm nguyên âm mở (iêu…): "điều" → "đều" (mất chữ "i").
    // Whitelist NFC để bypass field-kind (giống tiền lệ Gemini).
    if bundleId.lowercased().hasPrefix("ru.keepcoder.telegram") { return true }
    // ChatGPT (OpenAI) cho macOS — native Swift/AppKit, ô soạn là NSTextView
    // (lưu NFC, xóa theo grapheme; KHÔNG Electron). Cùng lớp Gemini/Telegram:
    // AX không phân loại field thành .windowField → rơi NFD → mất chữ. Whitelist.
    // (lowercased để nhất quán với nhánh Gemini, chịu biến thể hoa/thường.)
    if bundleId.lowercased() == "com.openai.chat" { return true }
    return false
  }

  /// v3.9: quyết định diff NFC/NFD cho FIELD đang focus.
  /// 1) App nhóm NFC (Apple/Office/iWork/Gemini) → LUÔN NFC, bất kể field kind
  ///    (vd web content trong Safari là WebKit nhưng vẫn NFC grapheme-delete).
  /// 2) App nhóm NFD (Chromium/Electron) → phân biệt theo field:
  ///    - webContent  → NFD (lưu/xoá theo scalar)
  ///    - nativePanel → NFC (NSSavePanel AppKit thật)
  ///    - windowField → NFC (browser-chrome/omnibox; dùng KÈM axDirect — xem
  ///                    effectiveTypingStrategy — vì axDeleteStart đếm grapheme)
  ///    - unknown     → giữ default NFD của app
  func usesNFCForFocusedField() -> Bool {
    if InputProcessor.usesNFCGraphemeStorage(bundleId: activeApp) { return true }
    switch focusedFieldKind {
    case .webContent: return false
    case .nativePanel, .windowField: return true
    case .unknown: return false
    }
  }

  /// v3.9: field hiện tại là browser-chrome (vd thanh địa chỉ Chrome) của app
  /// nhóm NFD — tức `windowField` trong app KHÔNG thuộc whitelist NFC. Các field
  /// này (Chromium Views) có inline autocomplete bôi đen nên backspace synthetic
  /// lệch số ký tự ("trường" → "truường"/"truờng"); phải dùng axDirect.
  func focusedFieldIsBrowserChrome() -> Bool {
    return focusedFieldKind == .windowField
      && !InputProcessor.usesNFCGraphemeStorage(bundleId: activeApp)
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

  /// 4.12: áp kiểu hoa/thường của từ user gõ lên từ thay thế. Lexicon lưu
  /// chữ thường nên auto-suggestion trả về chữ thường — thay thẳng sẽ hạ
  /// "ĐINHJ"/"Dinhj" về "định". ALL-CAPS → uppercase cả từ; chữ đầu hoa →
  /// viết hoa chữ đầu; còn lại giữ nguyên replacement.
  static func matchCase(of source: String, to replacement: String) -> String {
    guard source.first(where: { $0.isLetter })?.isUppercase == true else {
      return replacement
    }
    let letters = source.filter { $0.isLetter }
    if letters.count > 1, letters.allSatisfy({ $0.isUppercase }) {
      return replacement.uppercased()
    }
    guard let first = replacement.first else { return replacement }
    return String(first).uppercased() + replacement.dropFirst()
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

    sendTypedReplacement(
      backspaceCount: replacement.backspaceCount,
      diffChars: replacement.diffChars,
      appLikelySensitive: isFixAutocompleteApp()
    )
    return true
  }
}
