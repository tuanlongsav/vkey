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

  /// v4.23: chuỗi phím GỐC của từ vừa commit, đi kèm `previousWordState`.
  ///
  /// `TiengVietState.chuKhongDau` KHÔNG chứa phím dấu — `withTone`/`withMu`/
  /// `withGachD` không push ký tự nào — nên dựng lại `keys` từ nó (cách cũ)
  /// khiến lần Backspace kế tiếp replay một chuỗi phím đã mất sạch dấu:
  /// "chào" → "cha", "tiếng" → "tien", "đường" → "duon", kèm 5 backspace và
  /// gõ lại cả cụm. `Snapshot` mang sẵn `keys` cũng vì đúng lý do này.
  var previousKeys: [Character] = []

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
    // v4.23: "kr" ĐÃ GỠ khỏi danh sách. Nó vừa ở đây vừa nằm trong
    // `TiengViet.PhuAmGhep` và `TiengVietValidator.ValidInitials` như phụ âm
    // đầu tiếng Việt HỢP LỆ — mâu thuẫn trực tiếp. `isImpossibleCluster` chạy
    // TRƯỚC validator (và trước cả Free Mark) nên "kroong" bị khoá raw ngay ở
    // phím 'r' → ra "kroong" thay vì "Krông" (Krông Pắc, Krông Ana, Krông
    // Bông) — đúng nhóm tên riêng mà Free Mark tuyên bố phục vụ.
    //
    // ĐÂY LÀ NỚI GUARD THẬT, KHÔNG PHẢI DỌN MÂU THUẪN VÔ HẠI — CÓ GIÁ:
    // gỡ "kr" mở đường cho từ tiếng Anh kr… đi vào engine, và phím dấu bị
    // nuốt làm dấu. Đo trên engine: "kris" → "krí" (phím 's' thành dấu sắc
    // trên "kri", KHÔNG hồi phục vì từ vẫn "hợp lệ"); "krispy" đi qua "krí" →
    // "kríp" rồi mới hồi phục ở phím 'y'. Trước đây Kris/Krispy gõ sạch.
    // ("kraft", "krill", "kremlin" vẫn tự hồi phục ở phím kế tiếp.)
    //
    // ĐÃ CÂN NHẮC VÀ LOẠI cách "chỉ cho qua khi có dấu hiệu tên riêng (chữ hoa
    // đầu)": nó KHÔNG phân biệt được hai bên — "Krông" viết hoa thì "Kris",
    // "Kraft", "Krispy Kreme" cũng viết hoa (đều là danh từ riêng). Gate theo
    // chữ hoa chỉ đổi nạn nhân, còn làm hỏng thêm ca gõ "kroong" thường.
    //
    // Fix ĐÚNG TẦNG nằm ở `TiengVietValidator`: "kr" hiện nhận MỌI vần, nên
    // "kri" được coi là âm tiết hợp lệ và ăn được dấu. Vần kr- thực tế chỉ có
    // trong tên gọi Tây Nguyên (krông, krăk…); siết `ValidInitials`/vần cho
    // "kr" mới lấy lại được cả hai. Chưa siết thì đây là đánh đổi có ý thức:
    // ưu tiên địa danh tiếng Việt hơn một nhúm từ tiếng Anh hiếm.
    "tw", "dw", "sh", "ps", "pn", "ts", "kn",
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
    previousKeys = []
    if !wordState.isBlank {
      if storePrevious {
        previousWordState = wordState
        // v4.23: giữ CẢ phím dấu — xem chú thích ở `previousKeys`.
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
  }

  // MARK: - Pop (Backspace)

  mutating func pop(engine: TypingMethod, usesNFC: Bool) -> (Int, [Character]) {
    lastTransformed = transformed

    // Single-step rollback: if we are in recovery and it was caused by the LATEST keystroke
    if stopProcessing, let valid = lastValidSnapshot, keys.count == valid.keys.count + 1 {
      wordState = valid.wordState
      keys = valid.keys
      transformed = valid.transformed
      stopProcessing = valid.stopProcessing
      stoppedByEnglishWord = valid.stoppedByEnglishWord
      lastValidSnapshot = nil

      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: lastTransformed, to: transformed, usesNFC: usesNFC)

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
        // v4.23: replay từ chuỗi phím GỐC. `chuKhongDau` không mang phím dấu
        // nên dựng lại từ nó làm mọi backspace kế tiếp mất dấu (xem
        // `previousKeys`). Fallback giữ hành vi cũ cho ai gán thẳng
        // `previousWordState` mà không qua `newWord(storePrevious:)`.
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

    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed, usesNFC: usesNFC)

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
    // v4.23: stage anywhere-dd cũng phải dựng lại theo chuỗi phím replay. Trước
    // đây vòng lặp dưới ghi vào một biến CỤC BỘ nên `self.ddToggleStage` giữ
    // nguyên giá trị của từ TRƯỚC khi backspace: "vcdd" → "vcđ" (stage=1), BS
    // đưa màn hình về "vcd" mà stage vẫn 1 → gõ 'd' lại không toggle được nữa
    // (ra "vcdd"), và mọi 'd' sau đó cũng vậy cho tới hết từ.
    ddToggleStage = 0

    if keys.isEmpty {
      transformed = ""
      return
    }

    var currentKeys: [Character] = []
    var currentSnapshot: Snapshot? = nil

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
        // v4.23: dùng THẲNG `ddToggleStage` (đã reset ở đầu hàm) thay cho biến
        // cục bộ, để trạng thái sau replay khớp với màn hình.
        if k == "d" || k == "D" {
          switch ddToggleStage {
          case 0:
            if let last = transformed.last, last == "d" || last == "D" {
              let lastIsUpper = last == "D"
              transformed.removeLast()
              transformed.append(lastIsUpper ? "Đ" : "đ")
              ddToggleStage = 1
              wordState = wordState.push(k)
              continue
            }
          case 1:
            if let last = transformed.last, last == "đ" || last == "Đ" {
              let wasUpper = last == "Đ"
              transformed.removeLast()
              transformed.append(contentsOf: wasUpper ? "DD" : "dd")
              ddToggleStage = 2
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
          ddToggleStage = 0
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

// MARK: - InputProcessor
//
// v4.23: `TransformationTracker` (đếm lỗi transform để TỰ đổi chiến lược gửi
// phím) đã bị GỠ HẲN cùng công tắc `autoSwitchStrategy`. Nó là cơ chế chết:
// `isHighRisk` đòi `!telemetry.usedAsyncQueue`, mà MỌI chỗ dựng
// `EventSendTelemetry` với `attemptedTransform == true` đều đặt
// `usedAsyncQueue: true` — bộ đếm high-risk không bao giờ tăng.
// Nhánh còn lại (`consecutiveFailures >= 2`) thì bật được, nhưng chỉ khi
// `CGEventSource(stateID: .privateState)` trả nil HAI LẦN liên tiếp — tức lỗi
// hệ thống, không phải lỗi gõ. Nên cơ chế không bao giờ phản ứng với thứ nó
// sinh ra để phát hiện (app nuốt/đảo synthetic event), và công tắc vô nghĩa.
// Chiến lược gửi phím nay tra
// thẳng `EventSimulator.getStrategy(for:)` (xem `effectiveTypingStrategy`).
// Đừng dựng lại nếu chưa có phép đo chứng minh auto-switch cứu được app nào.

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

  /// Ô đang focus có AX role là `AXSearchField` / `AXComboBox` không (AppState
  /// đẩy vào). Đây là tín hiệu duy nhất phân biệt ô tìm kiếm có inline
  /// autocomplete với web text area.
  ///
  /// v2.3.10: trước đó vkey nhận diện "app cần Shift+Left" theo bundle ID
  /// (`FixAutocompleteApps`), nên cả text area của Google Docs/Sheets cũng bị
  /// tính vào → Shift+Left bị JS handler của contenteditable bỏ qua, selection
  /// không đổi mà vkey vẫn `sendString` → mọi âm tiết bị nhân đôi ("trình" →
  /// "trinình", "các" → "cacác"). Chuyển sang AX role thì Docs/Sheets rơi về
  /// `AXTextArea` và đi đường backspace bình thường.
  ///
  /// v4.23: hàm bọc `isFixAutocompleteApp()` đã gỡ cùng `TransformationTracker`
  /// — nó chỉ còn phục vụ tham số `appLikelySensitive` của cơ chế chết đó.
  /// Giữ lại chính cờ này vì nó là dữ liệu AX thật, không phải suy đoán.
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

  // ⚠️ ĐÃ THỬ VÀ ĐÃ LÙI (v4.23): một `DispatchGroup pendingReplacements` làm
  // "sổ nợ" của `EventSimulator.simulationQueue`, để phím mà vkey KHÔNG nuốt
  // được xếp SAU replacement đang bay thay vì đi thẳng qua event tap. Cơ chế đó
  // đã gỡ hẳn — lý do đầy đủ ghi ở `effectiveTypingStrategy`. Đừng dựng lại nếu
  // chưa đọc chỗ đó.

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

  /// v4.22: bundle mà AX trả về cho ô đang focus KHÔNG phải lúc nào cũng là app
  /// người dùng đang dùng. Hộp thoại Lưu của app sandbox chạy ở tiến trình phụ
  /// (`com.apple.Safari.SandboxBroker`, `com.apple.appkit.xpc.openAndSavePanelService`),
  /// và AX trả về khi thì tiến trình phụ, khi thì app cha — đổi qua lại TỪNG PHÍM.
  ///
  /// Mỗi lần đổi bị coi là chuyển app: Smart Switch áp lại chế độ, đường đó xoá
  /// bộ đệm từ, nên từ đang gõ bị cắt đôi. Đo được trong hộp thoại "Thư mục mới"
  /// của Safari: "Haf Nooij" ra nguyên phím thô, và "Nooij" ra "Nôị" vì "nô" đã
  /// commit còn "ij" thành từ mới.
  ///
  /// Quy về app cha khi bundle focus là hậu duệ của app đang ở trước, hoặc là
  /// dịch vụ panel dùng chung của AppKit.
  static func canonicalAppBundle(focused: String, frontmost: String?) -> String {
    guard let frontmost, !frontmost.isEmpty else { return focused }
    // Tiến trình phụ đặt tên theo app cha: "com.apple.Safari.SandboxBroker".
    if focused.hasPrefix(frontmost + ".") { return frontmost }
    // Hộp thoại Mở/Lưu ngoài tiến trình — dùng chung cho mọi app sandbox nên
    // tên nó không dính gì tới app cha.
    if focused == "com.apple.appkit.xpc.openAndSavePanelService" { return frontmost }
    return focused
  }

  /// ⚠️ CỐ Ý KHÔNG GỌI `newWord()` Ở ĐÂY — ĐÃ THỬ, ĐÃ LÙI (v4.23). ĐỌC HẾT
  /// TRƯỚC KHI "SỬA".
  ///
  /// (a) LỖI GỐC (P1, có thật, vẫn còn): số backspace của lần thay thế kế tiếp
  ///     tính từ `transformed` của app CŨ, nên bộ đệm sống sót qua ranh giới app
  ///     sẽ xoá vào văn bản CÓ SẴN của app mới. Gõ "vie" ở Safari, một app khác
  ///     cướp focus mà KHÔNG sinh keyDown/mouseDown (nên không đường nào gọi
  ///     `newWord()`), gõ tiếp "t" → calcKeyStrokes("vie"→"viêt") = 1 backspace
  ///     + "êt", và backspace đó ăn mất ký tự cuối của ô bên app mới.
  ///     Đường xoá cũ là `EventHook.setEnabled` (Smart Switch áp lại chế độ khi
  ///     đổi app); v4.22 siết nó thành "chỉ khi trạng thái THẬT SỰ đổi" nên từ
  ///     đó không còn đường nào xoá bộ đệm ở ranh giới app.
  /// (b) ĐÃ VÁ THẾ NÀO: thêm `if app != activeApp { newWord() }` ngay tại đây —
  ///     đúng tầng, và guard `!=` để không cắt từ khi hàm bị gọi lại cùng bundle.
  /// (c) HỒI QUY ĐẺ RA: hàm này chạy trong callback event-tap, và trên macOS 26
  ///     `activeApp` DAO ĐỘNG mỗi phím ở overlay (Spotlight): hai khối trong
  ///     `EventHook.eventTapCallback` ghi nó từ hai nguồn lệch nhau
  ///     (`eventTargetUnixProcessID` trả app NỀN, còn AX trả Spotlight). Guard
  ///     `!=` vì thế đúng mà vô dụng — mỗi phím vẫn là một lần "đổi app" thật
  ///     sự khác giá trị → `newWord()` xoá bộ đệm ở MỌI phím → `transformed`
  ///     luôn rỗng → không dấu nào hình thành nữa, gõ tiếng Việt âm thầm thành
  ///     gõ tiếng Anh. Vòng vá tiếp theo (gộp hai khối kia thành một bộ phân
  ///     giải duy nhất) lại đẻ hồi quy khác — xem chú thích trong EventHook.
  /// (d) QUYẾT ĐỊNH: sống chung với P1. Nó cần một chuỗi thao tác hiếm (đổi
  ///     focus không qua chuột/bàn phím, GIỮA một từ dở) và hỏng đúng một ký
  ///     tự; còn bản vá thì làm hỏng việc gõ tiếng Việt nói chung. Muốn vá lại
  ///     thì điều kiện tiên quyết là `activeApp` phải ỔN ĐỊNH mỗi phím — chứng
  ///     minh điều đó TRƯỚC trên máy thật (macOS 26 + Spotlight + Chrome web
  ///     content), rồi mới tính đến việc xoá bộ đệm ở đây.
  public func changeActiveApp(_ app: String) {
    let appChanged = app != activeApp
    activeApp = app
    if appChanged {
      // P8 (GIỮ, không thuộc phần bị lùi): cắt cửa sổ n-gram khi đổi app. Chỉ
      // đụng `prev1Committed`/`prev2Committed` + cờ viết hoa, KHÔNG đụng bộ đệm
      // từ đang gõ — nên không mất ký tự nào kể cả khi `activeApp` dao động như
      // mô tả ở (c). ĐỪNG đọc thành "vô hại": trong lúc dao động, reset chạy
      // MỖI PHÍM, nên `prev1Committed` luôn nil ⇒ bigram/trigram không bao giờ
      // tra được và NGramStore không học cặp nào ở app đó; `pendingCapitalize`
      // cũng bị xoá giữa Enter và phím chữ (gõ ra `a` thay vì `A`). Đó là xuống
      // cấp gợi ý + viết hoa, chấp nhận được so với việc mất chữ, và đúng ý đồ
      // A5 (đổi app = gián đoạn ngữ cảnh câu) khi app đổi THẬT.
      // Đã truy riêng: KHÔNG sinh trạng thái lệch giữa cờ viết hoa và bộ đệm từ
      // — `pendingCapitalize` chỉ bật bởi Enter/Space, cả hai đều qua `newWord()`,
      // nên không dựng được ca "cờ bật + bộ đệm còn chữ".
      resetSentenceCapitalizeState()
    }
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
    // v4.23: cửa sổ n-gram phải chết cùng ngữ cảnh câu. `prev1Committed`/
    // `prev2Committed` trước đây chỉ có chỗ GHI (lúc commit), không chỗ nào gán
    // nil — nên từ commit ở app/dòng TRƯỚC ghép với từ đầu tiên gõ ở chỗ MỚI
    // thành một bigram RÁC, và cặp đó được ghi VĨNH VIỄN vào NGramStore
    // (Defaults user-bigrams): commit "lương" trong Zalo, sang Xcode gõ tiếp là
    // học cặp ("lương", <từ đầu tiên ở Xcode>). HUD cũng gợi ý theo câu của app
    // trước. Mọi đường gọi hàm này (đổi app, Escape, mũi tên/Home/End, tổ hợp
    // Cmd/Ctrl/Alt, click chuột trong EventHook) đều là gián đoạn ngữ cảnh nên
    // là đúng chỗ để cắt cửa sổ.
    prev1Committed = nil
    prev2Committed = nil
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

  /// Nhận `usesNFC` từ caller để dạng ĐẾM backspace và dạng EMIT cùng dựa
  /// trên MỘT quyết định (xem `sendTypedReplacement`) — không đọc field hai lần.
  public func pop(usesNFC: Bool) -> (Int, [Character]) {
    return wordBuffer.pop(engine: engine, usesNFC: usesNFC)
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

    // v4.23: bỏ hẳn `lastPasteboardChangeCount = NSPasteboard.general.changeCount`
    // ở đây. Biến đó chỉ có GHI, không chỗ nào ĐỌC — tính năng "phát hiện dán từ
    // ngoài" mà comment cũ nhắc tới đã không còn tồn tại. Mà `changeCount` là một
    // round-trip tới pasteboard server, chạy trên thread event-tap cho MỌI phím
    // không kèm modifier: đúng loại chi phí làm macOS tắt tap khi máy tải nặng.
    // KHÔNG khôi phục, vì mọi đường dán đều đã xoá bộ đệm sẵn: ⌘V rơi vào nhánh
    // modifier ngay phía trên (`newWord()`), còn dán bằng menu / chuột phải thì
    // mouseDown trong `EventHook` cũng đã gọi `newWord()`.

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
      if taskKey == .Space, expandMacroAndAdvance(endingChar: " ") {
        return nil
      }

      if taskKey == .Space, applySpellDecisionAndAdvance(endingChar: " ", swallowEndingChar: true) {
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
      // Space rơi xuống cuối hàm và được trả về app như event THẬT.
      // (Đã thử hoãn nó qua `passThroughOrDefer` để giữ thứ tự với replacement
      // đang bay — đã lùi, xem `effectiveTypingStrategy`.)
    } else if taskKey == .Escape {
      resetSentenceCapitalizeState()  // Esc = gián đoạn, huỷ chờ viết hoa
      let orig = String(wordBuffer.keys)
      let currentTransformed = wordBuffer.transformed
      if !wordBuffer.wordState.isBlank && currentTransformed != orig {
        let usesNFC = usesNFCForFocusedField()
        let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
          from: currentTransformed, to: orig, usesNFC: usesNFC)
        sendTypedReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          usesNFC: usesNFC
        )
        newWord()
        return nil // swallow ESC event
      }
      newWord()
    } else if taskKey == .Delete {
      // Một lần đọc field, dùng chung cho cả trục diff (trong pop) lẫn emit.
      let usesNFC = usesNFCForFocusedField()
      let (numBackspaces, diffChars) = pop(usesNFC: usesNFC)
      if numBackspaces > 0 || !diffChars.isEmpty {
        sendTypedReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          usesNFC: usesNFC
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

      if expandMacroAndAdvance(endingChar: newChar) {
        return nil
      }
      if applySpellDecisionAndAdvance(endingChar: newChar, swallowEndingChar: true) {
        return nil
      }
      newWord(storePrevious: true)
      // Dấu câu kết từ trả về app như event THẬT. (Đã thử hoãn nó qua
      // `passThroughOrDefer` — đã lùi, xem `effectiveTypingStrategy`.)
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
      // v4.23: phát KẾT QUẢ ENGINE, không phát `newChar` thô. Nhánh cũ giả định
      // engine không bao giờ đụng ký tự ĐẦU của từ — sai khi `allowedZWJF` TẮT:
      // Telex biến 'w' đứng một mình thành 'ư' (Telex.swift, nhánh w→ư). Khi đó
      // lệnh gửi đi là "W" trong khi bộ đệm tin rằng màn hình có "Ư", mà event
      // gốc thì bị nuốt (`return nil`) → mọi phím sau diff trên nền sai và cả từ
      // hỏng. Diff từ `lastTransformed` (giá trị TRƯỚC push) sang `transformed`
      // luôn đúng, kể cả khi engine không đụng gì (khi đó vẫn ra đúng 1 ký tự).
      let usesNFC = usesNFCForFocusedField()
      var (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: lastTransformed, to: transformed, usesNFC: usesNFC)
      if numBackspaces == 0 && diffChars.isEmpty {
        // Lưới an toàn: đã nuốt event gốc rồi thì không được phát ra rỗng.
        diffChars = [newChar]
      }
      sendTypedReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        // Dạng emit bám field để ô tìm kiếm NFC nhận text precomposed.
        usesNFC: usesNFC
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
    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed, usesNFC: usesNFC)

    // If the only change is the new character itself, let it pass through
    if let firstDiffChar = diffChars.first,
      diffChars.count == 1 && firstDiffChar == newChar && numBackspaces == 0
    {
      // Thả thẳng phím thật về app. ĐÂY là chỗ hai đường (event tap đồng bộ vs
      // `simulationQueue` async) tách nhau — nguồn của race "push" → "pussh".
      // Cách chống race vẫn là hạ chiến lược xuống `.batch` cho diff nhỏ, xem
      // `effectiveTypingStrategy`; cơ chế hoãn phím đã thử và đã lùi.
      return Unmanaged.passUnretained(event)
    }

    sendTypedReplacement(
      backspaceCount: numBackspaces,
      diffChars: diffChars,
      usesNFC: usesNFC
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
        usesNFC: usesNFCForFocusedField()
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
      guard applySpellDecisionAndAdvance(endingChar: " ", swallowEndingChar: true) else {
        clearActivePrediction()
        return false
      }
      let recomputed = PredictionEngine.shared.topPhrasePrediction(
        prev2: prev2Committed,
        prev1: prev1Committed ?? ""
      ) ?? prediction
      sendTypedReplacement(
        backspaceCount: 0,
        diffChars: Array(recomputed),
        usesNFC: usesNFCForFocusedField()
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
      // v4.23: Enter là ranh giới câu/dòng — cửa sổ n-gram của dòng trước không
      // được nối sang dòng sau (xem `resetSentenceCapitalizeState`). Enter vốn
      // KHÔNG chạy `applySpellDecisionOnCommit` nên từ đang gõ cũng chưa từng
      // vào cửa sổ; cắt ở đây không mất dữ liệu học nào.
      prev1Committed = nil
      prev2Committed = nil
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

  /// Gửi replacement với chiến lược đúng ngữ cảnh (axDirect cho omnibox Chrome…).
  ///
  /// - Parameter usesNFC: quyết định chuẩn hoá của caller — PHẢI là chính giá
  ///   trị đã dùng để chọn `calcKeyStrokes` (NFC) vs `calcKeyStrokesNFD` (NFD)
  ///   khi tính `backspaceCount`/`diffChars`. Tham số này KHÔNG có giá trị mặc
  ///   định: bất biến "dạng EMIT == dạng ĐẾM backspace" (v4.15) là thứ giữ cho
  ///   bộ gõ không rụng chữ, nên nó phải do compiler ép ở từng call site chứ
  ///   không phải nhờ hai lần đọc `usesNFCForFocusedField()` tình cờ trùng nhau
  ///   — đọc hai lần chính là lớp lỗi đã gây regression v4.14 ("gửi"→"ửi").
  @discardableResult
  private func sendTypedReplacement(
    backspaceCount: Int,
    diffChars: [Character],
    usesNFC: Bool
  ) -> EventSendTelemetry {
    let strategy = effectiveTypingStrategy(
      backspaceCount: backspaceCount,
      diffCharCount: diffChars.count
    )
    // v4.23: bỏ tham số `appLikelySensitive`. Nó chỉ có một người dùng duy nhất
    // là `observeTelemetry` → `TransformationTracker` (đã gỡ, xem MARK
    // InputProcessor). Telemetry trả về giữ nguyên: đó là báo cáo của transport.
    let telemetry = EventSimulator.sendReplacement(
      backspaceCount: backspaceCount,
      diffChars: diffChars,
      strategy: strategy,
      // v4.15: dạng gửi bám theo field — cùng MỘT quyết định `usesNFC` mà
      // caller đã dùng để chọn trục diff. NFC precompose, NFD giữ nguyên.
      normalizeToNFC: usesNFC
    )
    return telemetry
  }

  /// For tiny diffs (common during Telex tone mutation), force immediate batch sending
  /// to avoid async reordering with the next keystroke (e.g. "push" -> "pussh").
  ///
  /// ⚠️ NHÁNH `bs<=1 && diff<=1 → .batch` Ở CUỐI HÀM LÀ CÓ CHỦ Ý, KỂ CẢ KHI APP
  /// ĐƯỢC CẤU HÌNH `.stepByStep`. ĐÃ THỬ MIỄN TRỪ, ĐÃ LÙI (v4.23):
  ///
  /// (a) LỖI GỐC (P5, có thật, vẫn còn): app trong whitelist `.stepByStep`
  ///     (Telegram, Terminal/Warp/Hyper, Claude, Dock…) được chọn CHÍNH VÌ chúng
  ///     cần nhịp nghỉ giữa backspace và ký tự thay thế — `EventSimulator
  ///     .sendReplacement` nhánh `.stepByStep` có `usleep(3000)` chắn hai đầu,
  ///     nhánh `.batch` thì không có khoảng nghỉ nào. Nhưng bs=1/diff=1 lại đúng
  ///     là nhóm phím PHỔ BIẾN NHẤT (dd→đ, aa→â, ee→ê, oo→ô, w→ư/ơ, và mọi phím
  ///     dấu gõ ngay sau nguyên âm cuối), nên ở nhóm đó chúng MẤT cushion.
  /// (b) ĐÃ VÁ THẾ NÀO: thêm `if case .stepByStep = appStrategy { return
  ///     .stepByStep }` ngay TRƯỚC nhánh `bs<=1 && diff<=1`.
  /// (c) HỒI QUY ĐẺ RA — hai tầng, tầng sau nặng hơn tầng trước:
  ///     • Bỏ downgrade là dựng lại đúng race mà docstring trên mô tả: phím 's'
  ///       của "push" nằm ~8ms trên `simulationQueue`, phím 'h' không đổi gì nên
  ///       đi THẲNG qua event tap → app nhận "puh" rồi mới nhận backspace →
  ///       "pussh"/"puú".
  ///     • Vá tiếp bằng cơ chế hoãn phím (`pendingReplacements` +
  ///       `passThroughOrDefer`: nuốt phím thật, phát lại bằng `sendString` ở
  ///       cuối hàng đợi) thì hỏng nặng hơn nữa. Hai chỗ chí mạng: `sendString`
  ///       KHÔNG đi qua đường `.axDirect`, nên trong Spotlight/omnibox — đúng
  ///       những ô phải dùng axDirect vì chúng nuốt synthetic event — ký tự hoãn
  ///       mất hẳn; và Enter/Tab thì KHÔNG hoãn được (chúng mang ngữ nghĩa
  ///       submit/chuyển field mà `sendString` không tái tạo), nên trong app chat
  ///       `.stepByStep` gõ "chaof" rồi Enter là gửi đi tin "chao", còn backspace
  ///       + "ò" rơi vào ô soạn của tin KẾ TIẾP.
  /// (d) QUYẾT ĐỊNH: giữ downgrade. Chấp nhận `.stepByStep` không có cushion ở
  ///     ca diff 1 ký tự — thiếu cushion thì thỉnh thoảng rớt/lặp một ký tự và
  ///     người dùng gõ lại được; còn hai bản vá kia làm mất chữ trong Spotlight
  ///     và gửi tin nhắn dở. Muốn vá lại thì phải giải bài toán THỨ TỰ mà không
  ///     đổi ĐƯỜNG gửi (giữ nguyên axDirect, giữ nguyên event thật cho
  ///     Enter/Tab), và phải kiểm được trên máy thật — không unit test nào ở
  ///     đây chạm tới timing này.
  private func effectiveTypingStrategy(backspaceCount: Int, diffCharCount: Int) -> SendingStrategy {
    // v4.23: tra thẳng bảng per-app. Trước đây giá trị này nằm trong
    // `strategyTracker.currentStrategy`, vốn cũng chỉ được gán bằng đúng lời gọi
    // này ở `resetForApp` và không bao giờ đổi nữa (auto-switch là cơ chế chết,
    // đã gỡ) — nên hành vi chọn chiến lược không đổi.
    let appStrategy = EventSimulator.getStrategy(for: activeApp)

    // axDirect (set qua bundle-id getStrategy) KHÔNG được downgrade — đa số
    // transform dấu là bs=1+diff=1; downgrade về .batch sẽ gửi synthetic event
    // vào Spotlight và loạn chữ trở lại.
    if case .axDirect = appStrategy {
      return .axDirect
    }
    // v3.9: browser-chrome field (thanh địa chỉ Chrome…) có inline autocomplete
    // bôi đen → synthetic backspace lệch. Dùng axDirect (đọc value thật, xử lý
    // suffix-selection như Spotlight). axDirect fail → tự fallback synthetic.
    if focusedFieldIsBrowserChrome() {
      return .axDirect
    }
    // `.stepByStep` KHÔNG được miễn trừ ở đây — xem mục (c)/(d) trong docstring.
    if backspaceCount <= 1 && diffCharCount <= 1 {
      return .batch
    }
    return appStrategy
  }

  /// Chạy spell decision cho phím kết từ RỒI sang từ mới.
  ///
  /// Hai vế phải đi liền nhau nên gộp vào một chỗ: khi hàm trả về true là vkey
  /// vừa THAY chữ trên màn hình — từ Anh gốc ở `.restoreRawEnglish` ("tẽt" →
  /// "text"), từ gợi ý ở `.suggest` ("dịnh" → "định") — trong khi `wordState`
  /// vẫn giữ chữ user gõ. Lưu state lệch đó làm `previousWordState` khiến
  /// Backspace ngay sau đó dựng lại chữ CŨ vào buffer (`WordBuffer.pop`, nhánh
  /// `keys.isEmpty`) trong khi màn hình hiển thị chữ ĐÃ SỬA → diff kế tiếp tính
  /// trên text không tồn tại và phá chữ. Cùng lý do với macro (xem
  /// `expandMacroIfMatch`), nên cũng KHÔNG lưu previous ở đây.
  ///
  /// - Returns: True khi vkey đã tự gửi thay thế — caller phải nuốt phím kết từ.
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

  /// Applies spell/restore/suggestion rules when a word commit key is pressed.
  /// - Parameters:
  ///   - endingChar: Commit key character (space or punctuation).
  ///   - swallowEndingChar: True when commit key should be emitted by vkey and swallowed by the caller.
  /// - Returns: True when a replacement was sent.
  ///
  /// Không gọi thẳng từ đường phím: dùng `applySpellDecisionAndAdvance` để
  /// bước sang từ mới đúng cách sau khi đã thay chữ.
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
      // v4.15: cùng nguyên tắc — dạng gửi bám theo field. Path này chủ yếu cho
      // app NFD (Chromium/Claude/Notes) nên gửi nguyên; field NFC precompose.
      let typed = usesNFCForFocusedField()
        ? target.precomposedStringWithCanonicalMapping
        : target
      EventSimulator.simulationQueueAsync {
        _ = EventSimulator.withAdaptiveFlush {
          EventSimulator.sendOptionBackspace(source: source)
          usleep(10_000)  // 10ms delay — đủ cho app process word deletion
          EventSimulator.sendString(typed, source: source)
        }
      }
      // ⚠️ Đây là chuỗi gửi DÀI NHẤT trong vkey (Option+Backspace + usleep 10ms
      // + gõ lại cả từ), nên cũng là cửa sổ race rộng nhất: phím đầu của TỪ KẾ
      // TIẾP lọt qua event tap trước khi chuỗi này bay xong thì bị chính
      // Option+Backspace xoá luôn. Đã thử đóng cửa sổ đó bằng hàng rào thứ tự
      // (`pendingReplacements`) — đã lùi vì cơ chế hoãn phím đẻ hồi quy nặng
      // hơn; xem `effectiveTypingStrategy`. Race này vì vậy VẪN CÒN, chỉ hiếm
      // (đòi gõ tiếp trong ~10ms sau khi tự sửa chính tả kích hoạt).
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
      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: current, to: target, usesNFC: usesNFC)
      sendTypedReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        usesNFC: usesNFC
      )
      return true
    }
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
    case .webContent, .unknown:
      // 4.21: web content của TRÌNH DUYỆT dùng NFC. Thay cho công tắc thủ công
      // "NFC cho ô tìm kiếm web" của 4.16, vốn dựa trên hai tiền đề đều SAI:
      //   • "Chrome ẩn web content khỏi AX nên không phân loại field được" —
      //     đo lại thì AXWebArea hiện bình thường, và vkey phân biệt được
      //     .webContent với .windowField (thanh địa chỉ).
      //   • "canvas lưu NFD nên bật cờ sẽ hỏng Google Docs" — copy nội dung
      //     Docs ra đếm scalar: 22 scalar precomposed (NFD sẽ là 29). Docs LƯU
      //     NFC. Gõ + Backspace trong Docs trên trục NFC chạy đúng.
      // Chrome giữ nguyên NFC ở <input>, <input type=search> và
      // contenteditable (đo bằng cách gửi U+1EEF U+1EC1 rồi đọc lại AXValue).
      //
      // ⚠️ GIỚI HẠN CỦA PHÉP ĐO — đọc kỹ trước khi lật trục này:
      // Tất cả những gì đã đo ở trên là DẠNG LƯU TRỮ (AXValue / nội dung copy
      // ra). Cái mà `calcKeyStrokes` thật sự cần lại là ĐƠN VỊ XOÁ của một
      // synthetic backspace trong Blink — grapheme hay scalar — và repo CHƯA
      // TỪNG đo con số đó. Hai thứ có thể lệch nhau (AX có thể chuẩn hoá trên
      // đường ra), và có bằng chứng thực địa NGƯỢC chiều: CHANGELOG 4.15 ghi
      // rằng quay về emit NFD + đếm NFD thì HẾT lỗi rụng phụ âm đầu trên
      // Chrome/Electron/Slack/Discord. Nhánh này vì vậy là GIẢ ĐỊNH, không
      // phải kết luận.
      // Phép đo còn thiếu: trong ô web của Chrome, gõ một chữ có dấu (vd "ề"),
      // gửi ĐÚNG 1 synthetic backspace, rồi đọc lại AXValue — nếu còn "e" thì
      // Blink xoá theo scalar (trục NFD đúng), nếu ô rỗng thì xoá theo grapheme
      // (trục NFC đúng). Chưa có số này thì đừng đổi logic ở đây theo cả hai
      // chiều.
      //
      // Giới hạn ở trình duyệt, KHÔNG áp cho mọi web content: Electron
      // (Slack/Discord/Zalo) cũng là web content nhưng chưa đo, nên giữ NFD
      // như cũ — đó cũng chính là phạm vi mà cờ 4.16 phóng quá tay.
      //
      // `.unknown` đi CÙNG nhánh với `.webContent` là có chủ đích: trong một
      // trình duyệt, AX timeout làm fieldKind rơi về .unknown giữa chừng; nếu
      // hai case này khác trục thì một từ đang gõ sẽ bị đổi trục giữa dòng —
      // đúng lớp lỗi 4.14 (đếm một đằng, phát một nẻo).
      return InputProcessor.isBrowserApp(bundleId: activeApp)
    case .nativePanel, .windowField: return true
    }
  }

  /// v4.21: app có phải TRÌNH DUYỆT thật không (không phải web-view nói chung).
  /// Dùng lại `FixAutocompleteApps` — danh sách bundle trình duyệt vốn đã được
  /// duy trì sẵn trong file này. Khớp theo prefix để bao các kênh beta/canary
  /// (vd "com.google.Chrome.beta").
  static func isBrowserApp(bundleId: String) -> Bool {
    FixAutocompleteApps.contains { bundleId.hasPrefix($0) }
  }

  /// v3.9: field hiện tại là browser-chrome (vd thanh địa chỉ Chrome) của app
  /// nhóm NFD — tức `windowField` trong app KHÔNG thuộc whitelist NFC. Các field
  /// này (Chromium Views) có inline autocomplete bôi đen nên backspace synthetic
  /// lệch số ký tự ("trường" → "truường"/"truờng"); phải dùng axDirect.
  func focusedFieldIsBrowserChrome() -> Bool {
    return focusedFieldKind == .windowField
      && !InputProcessor.usesNFCGraphemeStorage(bundleId: activeApp)
  }

  /// Tra macro khớp CHÍNH XÁC từ hiện tại, trả về text thay thế (phần bung ra
  /// + ký tự kết từ). Tách khỏi việc tính diff để caller chỉ phải đọc trạng
  /// thái field khi thực sự có macro khớp.
  static func macroTarget(
    for current: String,
    endingChar: Character,
    macros: [Macro]
  ) -> String? {
    guard !current.isEmpty else { return nil }
    let usable = macros.filter { !$0.from.isEmpty && !$0.to.isEmpty }

    // Khớp CHÍNH XÁC trước: người dùng có thể khai hai macro chỉ khác hoa/thường
    // ("vn" và "VN"), cả hai phải giữ nguyên phần bung riêng của mình.
    if let macro = usable.first(where: { $0.from == current }) {
      return macro.to + String(endingChar)
    }

    // v4.23: rồi mới khớp ĐÚNG MỘT biến thể — bản đã bị auto-capitalize viết
    // hoa chữ đầu. Auto-capitalize chạy TRƯỚC khi macro được tra, mà toàn bộ
    // macro seed sẵn đều chữ thường và cả hai tính năng đều BẬT mặc định — nên
    // ở đầu mỗi câu/dòng "vn" đã thành "Vn", `"vn" != "Vn"`, macro không bao
    // giờ bung: ra "Vn " thay vì "Việt Nam ". Giữa câu thì bung bình thường,
    // nên lỗi chỉ lộ ở đầu câu.
    //
    // ⚠️ KHÔNG được nới thành khớp-bỏ-qua-hoa/thường (bản đầu của bản vá này đã
    // làm thế và đó là hồi quy): cộng với `matchCase` viết HOA TOÀN BỘ khi
    // nguồn all-caps, mọi viết tắt người Việt gõ HOA CÓ CHỦ Ý đều bị nuốt —
    // "PM " (giờ chiều / Project Manager) ra "± ", "VN "→"VIỆT NAM ",
    // "HN "→"HÀ NỘI ", "CTY "→"CÔNG TY ", "ARR "→"→", "DEG "→"°". Trước đây
    // chúng đi qua nguyên vẹn, và lỗi cần vá chỉ đòi biến thể hoa-CHỮ-ĐẦU.
    // ALL-CAPS vì vậy KHÔNG khớp — muốn nó bung thì khai macro all-caps riêng,
    // nhánh khớp chính xác ở trên phục vụ đúng việc đó.
    //
    // `matchCase` vẫn dùng cho phần bung (tiền lệ của nhánh gợi ý chính tả
    // `.suggest`), nhưng ở đây nó chỉ còn đi vào nhánh "hoa chữ đầu".
    guard
      let macro = usable.first(where: { Self.autoCapitalizedVariant(of: $0.from) == current })
    else {
      return nil
    }
    return matchCase(of: current, to: macro.to) + String(endingChar)
  }

  /// Chuỗi mà auto-capitalize tạo ra từ một trigger: viết hoa ĐÚNG chữ cái đầu,
  /// phần còn lại giữ nguyên — khớp chính xác thao tác trong `handleTextChar`
  /// (`String(newChar).uppercased()` cho ký tự ĐẦU TIÊN của từ).
  ///
  /// Trả `nil` khi trigger không mở đầu bằng chữ thường: khi đó auto-capitalize
  /// không đổi được gì, và nhánh khớp chính xác ở trên đã lo.
  static func autoCapitalizedVariant(of trigger: String) -> String? {
    guard let first = trigger.first, first.isLowercase else { return nil }
    return String(first).uppercased() + trigger.dropFirst()
  }

  /// Diff thay từ trigger bằng phần macro bung ra.
  ///
  /// Dùng ĐÚNG helper mà mọi path thay-thế khác dùng
  /// (`calcKeyStrokes(from:to:usesNFC:)`) thay vì tự đếm độ dài trigger. Tự
  /// đếm sinh ra một quy ước thứ ba và sai ở cả hai chiều: đếm grapheme làm
  /// THIẾU backspace trên field NFD khi trigger có dấu ("tớ" = 2 grapheme
  /// nhưng 4 scalar NFD) → sót "to"; còn đếm scalar cho TRỌN từ lại xoá LỐ
  /// sang ký tự đứng trước nếu field bị phân loại nhầm hoặc strategy bị ép
  /// sang axDirect. Diff chung chỉ đụng phần đuôi khác nhau và thừa hưởng
  /// guard v3.6 (không bao giờ mở đầu bằng dấu rời).
  static func macroReplacement(
    for current: String,
    endingChar: Character,
    macros: [Macro],
    usesNFC: Bool
  ) -> (backspaceCount: Int, diffChars: [Character])? {
    guard
      let target = macroTarget(for: current, endingChar: endingChar, macros: macros)
    else {
      return nil
    }
    return EventSimulator.calcKeyStrokes(from: current, to: target, usesNFC: usesNFC)
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

  /// Bung macro cho phím kết từ RỒI sang từ mới.
  ///
  /// Sau khi bung, trên màn hình là PHẦN BUNG chứ không phải trigger, trong khi
  /// `wordState` vẫn giữ trigger. Lưu trigger làm `previousWordState` khiến
  /// Backspace kế tiếp dựng lại trigger vào buffer trong khi màn hình hiển thị
  /// phần bung → diff sau đó tính trên text không tồn tại và phá chữ. Cùng lớp
  /// với spell auto-correct (xem `applySpellDecisionAndAdvance`).
  ///
  /// - Returns: True khi đã bung — caller phải nuốt phím kết từ.
  @discardableResult
  func expandMacroAndAdvance(endingChar: Character) -> Bool {
    guard expandMacroIfMatch(endingChar: endingChar) else { return false }
    newWord(storePrevious: false)
    return true
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
      let target = Self.macroTarget(
        for: current,
        endingChar: endingChar,
        macros: Defaults[.macros]
      )
    else {
      return false
    }

    // Chỉ đọc trạng thái field khi CHẮC CHẮN có macro khớp: path này chạy trên
    // mọi phím kết từ (space + dấu câu) mà không-khớp là trường hợp áp đảo.
    // Một lần đọc, dùng chung cho cả trục diff lẫn dạng emit.
    let usesNFC = usesNFCForFocusedField()
    let (backspaceCount, diffChars) = EventSimulator.calcKeyStrokes(
      from: current, to: target, usesNFC: usesNFC)
    sendTypedReplacement(
      backspaceCount: backspaceCount,
      diffChars: diffChars,
      usesNFC: usesNFC
    )
    return true
  }
}
