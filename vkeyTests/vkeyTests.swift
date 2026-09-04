//
//  vkeyTests.swift
//  vkeyTests
//
//  Created by KhanhIceTea on 20/02/2024.
//

import XCTest
import Defaults
import AppKit
import CryptoKit
import KeyboardShortcuts

@testable import vkey

final class vkeyTests: XCTestCase {

  override func setUp() {
    super.setUp()
    Defaults.reset(.spellCheckEnabled)
    Defaults.reset(.spellCheckInSentenceEnabled)
    Defaults.reset(.englishAutoRestoreEnabled)
    Defaults.reset(.restorePolicy)
    Defaults.reset(.suggestionEnabled)
    Defaults.reset(.autoApplyHighConfidenceSuggestion)
    Defaults.reset(.personalDictionaryEnabled)
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userKeepWords)
    Defaults.reset(.userDenyWords)
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
  }

  override func tearDownWithError() throws {
    try super.tearDownWithError()
  }

  public func transform_text_telex(for text: String) -> String {
    var p_ret: [String] = []
    let inputProcessor = InputProcessor(method: .Telex)

    for word in text.split(separator: " ") {
      inputProcessor.newWord()
      for c in word {
        inputProcessor.push(char: c)
      }
      p_ret.append(inputProcessor.transformed)
    }

    return p_ret.joined(separator: " ")
  }

  public func transform_text_vni(for text: String) -> String {
    var p_ret: [String] = []
    let inputProcessor = InputProcessor(method: .VNI)

    for word in text.split(separator: " ") {
      inputProcessor.newWord()
      for c in word {
        inputProcessor.push(char: c)
      }
      p_ret.append(inputProcessor.transformed)
    }

    return p_ret.joined(separator: " ")
  }

  private func withTonePlacement(_ newStyle: Bool, run assertions: () throws -> Void) throws {
    let oldValue = Defaults[.newStyleTonePlacement]
    Defaults[.newStyleTonePlacement] = newStyle
    defer { Defaults[.newStyleTonePlacement] = oldValue }
    try assertions()
  }

  /// Test paragraph-level transformation with corrected Telex input
  func testExample() throws {
    // Test a simpler sentence with correct Telex sequences
    let sentence = transform_text_telex(for: "xin chaof taats car cacs banj")
    XCTAssertEqual(sentence, "xin chào tất cả các bạn")

    // Test individual common Vietnamese words
    XCTAssertEqual(transform_text_telex(for: "ddieemr"), "điểm")
    XCTAssertEqual(transform_text_telex(for: "phieen"), "phiên")
    XCTAssertEqual(transform_text_telex(for: "ddaauf"), "đầu")
    XCTAssertEqual(transform_text_telex(for: "tieenf"), "tiền")
    XCTAssertEqual(transform_text_telex(for: "ddor"), "đỏ")
    XCTAssertEqual(transform_text_telex(for: "truowcs"), "trước")
    XCTAssertEqual(transform_text_telex(for: "chuwsng"), "chứng")
    XCTAssertEqual(transform_text_telex(for: "khoans"), "khoán")
  }

  /// Regression — Telegram gõ "điều" ra "đều" (mất chữ "i").
  /// Engine LUÔN sinh đúng chuỗi NFC cho cụm nguyên âm mở + dấu muộn (iêu/iểu…);
  /// lỗi thật nằm ở tầng emit (Telegram bị định tuyến nhầm sang NFD scalar diff
  /// nên backspace thừa 1). Test khoá cả hai nửa: (1) engine đúng, (2) Telegram
  /// native nằm trong whitelist NFC grapheme-delete.
  func testDieuTelegramFix() throws {
    // (1) Engine: cụm "iêu"/"iểu" mang dấu — trước đây chưa có test bao phủ.
    XCTAssertEqual(transform_text_telex(for: "ddieeuf"), "điều")
    XCTAssertEqual(transform_text_telex(for: "nhieeuf"), "nhiều")
    XCTAssertEqual(transform_text_telex(for: "chieeuf"), "chiều")
    XCTAssertEqual(transform_text_telex(for: "kieeur"), "kiểu")
    XCTAssertEqual(transform_text_telex(for: "hieeur"), "hiểu")
    // "điểm" (có coda) không thuộc lớp lỗi này — vẫn đúng.
    XCTAssertEqual(transform_text_telex(for: "ddieemr"), "điểm")

    // (2) App-compat: app native NFC grapheme-delete → whitelist (bypass
    // field-kind mong manh). Telegram + ChatGPT cùng lớp Gemini.
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "ru.keepcoder.Telegram"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.openai.chat"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.htl.plume"))
    // KHÔNG whitelist: Qt tdesktop (delete-unit chưa xác minh), Electron/Chromium
    // (Zalo, Cursor, Slack) vốn NFD scalar-delete đúng sẵn — bảo đảm cô lập.
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "org.telegram.desktop"))
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.vng.zalo"))
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.tinyspeck.slackmacgap"))
  }

  /// Regression — Plume (WKWebView Messenger bubble) mất phụ âm khi đặt dấu
  /// trên nguyên âm đã có mũ/móc. Hai lớp:
  /// 1) Trục: NFD snap đếm +1 backspace so với NFC (chư→chứ, đê→để, …).
  /// 2) Transport: `.batch` (delay 0) để Lexical gộp BS liên tiếp của dd/ee/dấu
  ///    → "để"→"ể". Whitelist NFC + stepByStep + giữ cushion ở diff 1 ký tự.
  func testPlumeMessengerBubbleUsesNFC() throws {
    // (1) Số học — cả lớp "thanh trên nguyên âm đã có mũ/móc".
    let toneOnMarked: [(String, String)] = [
      ("chư", "chứ"), ("đê", "để"), ("đê", "đề"), ("vê", "về"),
      ("tô", "tố"), ("gơ", "gở"), ("â", "ấ"), ("ă", "ặ"),
      ("điêu", "điều"), ("tiêng", "tiếng"),
    ]
    for (from, to) in toneOnMarked {
      let (nfcBs, _) = EventSimulator.calcKeyStrokes(from: from, to: to, usesNFC: true)
      let (nfdBs, _) = EventSimulator.calcKeyStrokes(from: from, to: to, usesNFC: false)
      XCTAssertEqual(nfdBs, nfcBs + 1,
        "\(from)→\(to): NFD snap phải thừa đúng 1 so với NFC (nfc=\(nfcBs) nfd=\(nfdBs))")
    }

    XCTAssertTrue(InputProcessor.keepsCushionOnSmallDiffs(bundleId: "com.htl.plume"))
    XCTAssertFalse(InputProcessor.keepsCushionOnSmallDiffs(bundleId: "ru.keepcoder.Telegram"),
      "Telegram giữ P5 — không mở miễn trừ cushion toàn cục")
    guard case .stepByStep = EventSimulator.getStrategy(for: "com.htl.plume") else {
      return XCTFail("Plume phải stepByStep để Lexical không gộp backspace")
    }

    for kind in [Focused.FieldKind.webContent, .unknown, .windowField] {
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp("com.htl.plume")
      p.focusedFieldKind = kind
      XCTAssertTrue(p.usesNFCForFocusedField(), "Plume × \(kind) phải NFC")

      // chứ — regression gốc 4.26
      var last = ""
      p.newWord()
      for c in "chuws" {
        p.push(char: c)
        let r = p.emitPlan().replacement(from: last, to: p.transformed)
        if c == "s" {
          XCTAssertEqual(r.backspaceCount, 1, "Plume chuws@s: bs NFC=1, không phải NFD=2")
        }
        last = p.transformed
      }
      XCTAssertEqual(p.transformed, "chứ")

      // để — regression follow-up (mất đ → "ể"). Telex hỏi = `r`, không phải `f`
      // (f = huyền → "đề").
      last = ""
      p.newWord()
      for c in "ddeer" {
        p.push(char: c)
        let r = p.emitPlan().replacement(from: last, to: p.transformed)
        if c == "r" {
          XCTAssertEqual(r.backspaceCount, 1, "Plume ddeer@r: bs NFC=1 — NFD=2 sẽ ăn mất đ")
        }
        last = p.transformed
      }
      XCTAssertEqual(p.transformed, "để")
    }
  }

  /// Regression — Telegram gõ "gửi" ra "ửi" (mất chữ ĐẦU). Khác lớp với
  /// testDieuTelegramFix: đây KHÔNG phải NFC/NFD (Telegram đã whitelist NFC), mà
  /// là race của synthetic backspace + retype ở `.hybrid` — compose view custom
  /// của Telegram xử lý async nên rớt ký tự đầu khi thay cả cụm. Fix: định tuyến
  /// `.stepByStep` (gửi từng phím) như Dock/Launchpad + Claude. Test khoá entry.
  func testTelegramUsesStepByStep() throws {
    guard case .stepByStep = EventSimulator.getStrategy(for: "ru.keepcoder.Telegram") else {
      return XCTFail("Telegram phải dùng .stepByStep để tránh rớt chữ đầu ('gửi'→'ửi')")
    }
    // Đối chứng: app không khai báo vẫn fallback .hybrid (default).
    guard case .hybrid = EventSimulator.getStrategy(for: "com.example.khongkhaibao") else {
      return XCTFail("App không khai báo phải fallback .hybrid")
    }
  }

  /// v4.10 — overlay latch (chống icon menu bar nháy Việt↔Anh khi gõ Spotlight).
  /// Khoá danh sách overlay dùng cho latch: eventTargetUnixProcessID dao động
  /// overlay↔app nền trên macOS 26 → phải nhận diện đúng overlay để ghim.
  func testIsOverlayBundle() throws {
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.Spotlight"))
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.dock"))
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.systemuiserver"))
    XCTAssertFalse(EventSimulator.isOverlayBundle("com.google.Chrome"))
    XCTAssertFalse(EventSimulator.isOverlayBundle("ru.keepcoder.Telegram"))
    XCTAssertFalse(EventSimulator.isOverlayBundle(""))
  }

  func testPerformance() throws {
    // This is an example of a performance test case.
    //    self.measure {
    //      for _ in 0...1000 {
    //        telex.clear()
    //        let transformed = telex.transform_text(for: "xin chaof tatas car cacs banj")
    //        assert(transformed == "xin chào tất cả các bạn")
    //      }
    //    }
  }

  // MARK: - "gi" Special Case Tests

  /// Test "gi" alone: "gif" -> "gi" (g is consonant, i is vowel with tone)
  func testGiAlone() throws {
    let state = TiengVietState.empty
      .push("g").push("i").withTone(.huyen)
    XCTAssertEqual(state.transformed, "gì")
  }

  /// Test "gi" with following vowel: "gieets" -> "giet" (gi is consonant, e is vowel)
  func testGiWithVowel() throws {
    let state = TiengVietState.empty
      .push("g").push("i").push("e").push("t")
      .withMu(.muUp).withTone(.sac)
    XCTAssertEqual(state.transformed, "giết")
  }

  /// Test "gi" with "a": "gia" -> "gia" (gi is consonant, a is vowel)
  func testGiWithA() throws {
    let state = TiengVietState.empty
      .push("g").push("i").push("a")
    XCTAssertEqual(state.transformed, "gia")
  }

  // MARK: - Advanced "gi" Parsing Tests

  /// Test detailed parsing of "gi" in various contexts based on TiengVietParser logic
  func testGiDetailedParsing() throws {
    // Case 1: "gi" alone -> g (consonant) + i (vowel)
    let res1 = TiengVietParser.parse(Array("gi"))
    XCTAssertEqual(String(res1.phuAmDau), "g")
    XCTAssertEqual(String(res1.nguyenAm), "i")

    // Case 2: "gi" before consonant: "gin" -> g (consonant) + i (vowel) + n (final)
    let res2 = TiengVietParser.parse(Array("gin"))
    XCTAssertEqual(String(res2.phuAmDau), "g")
    XCTAssertEqual(String(res2.nguyenAm), "i")
    XCTAssertEqual(String(res2.phuAmCuoi), "n")

    // Case 3: "gi" before vowel + final consonant: "gieng" -> g + ieng (merges i into vowel)
    let res3 = TiengVietParser.parse(Array("gieng"))
    XCTAssertEqual(String(res3.phuAmDau), "g")
    XCTAssertEqual(String(res3.nguyenAm), "ie")
    XCTAssertEqual(String(res3.phuAmCuoi), "ng")

    // Case 4: "gi" before vowel + final consonant where "i" + vowel is invalid: "giang" -> gi + ang
    let res4 = TiengVietParser.parse(Array("giang"))
    XCTAssertEqual(String(res4.phuAmDau), "gi")
    XCTAssertEqual(String(res4.nguyenAm), "a")
    XCTAssertEqual(String(res4.phuAmCuoi), "ng")

    // Case 5: "gi" before vowel without final consonant: "gia" -> gi + a (gi as consonant for mark placement)
    let res5 = TiengVietParser.parse(Array("gia"))
    XCTAssertEqual(String(res5.phuAmDau), "gi")
    XCTAssertEqual(String(res5.nguyenAm), "a")
  }

  /// Test Telex outputs for complex "gi" cases
  func testTelexGiDetailed() throws {
    XCTAssertEqual(transform_text_telex(for: "gif"), "gì")
    XCTAssertEqual(transform_text_telex(for: "gin"), "gin")
    XCTAssertEqual(transform_text_telex(for: "gieengs"), "giếng")
    XCTAssertEqual(transform_text_telex(for: "giangs"), "giáng")
    XCTAssertEqual(transform_text_telex(for: "gias"), "giá")
    XCTAssertEqual(transform_text_telex(for: "giuwx"), "giữ")
  }

  // MARK: - Functional State Immutability Tests

  /// Test that state mutations return new state without affecting original
  func testImmutability() throws {
    let state1 = TiengVietState.empty.push("a")
    let state2 = state1.withTone(.sac)

    XCTAssertEqual(state1.transformed, "a")   // Original unchanged
    XCTAssertEqual(state2.transformed, "á")   // New state has tone
  }

  /// Test that push returns new state
  func testPushImmutability() throws {
    let state1 = TiengVietState.empty.push("h").push("o")
    let state2 = state1.push("m")

    XCTAssertEqual(state1.transformed, "ho")
    XCTAssertEqual(state2.transformed, "hom")
  }

  /// Test that pop returns new state
  func testPopImmutability() throws {
    let state1 = TiengVietState.empty.push("h").push("o").push("m")
    let state2 = state1.pop()

    XCTAssertEqual(state1.transformed, "hom")
    XCTAssertEqual(state2.transformed, "ho")
  }

  /// Test toggle behavior for tone marks
  func testToneToggle() throws {
    let state1 = TiengVietState.empty.push("a")
    let state2 = state1.withTone(.sac)
    let state3 = state2.withTone(.sac)  // Toggle off

    XCTAssertEqual(state1.transformed, "a")
    XCTAssertEqual(state2.transformed, "á")
    XCTAssertEqual(state3.transformed, "a")  // Tone removed
  }

  /// Test toggle behavior for diacritical marks
  func testMuToggle() throws {
    let state1 = TiengVietState.empty.push("a")
    let state2 = state1.withMu(.muUp)
    let state3 = state2.withMu(.muUp)  // Toggle off

    XCTAssertEqual(state1.transformed, "a")
    XCTAssertEqual(state2.transformed, "â")
    XCTAssertEqual(state3.transformed, "a")  // Mark removed
  }

  // MARK: - Vietnamese Text Transformation Tests

  /// Test basic Telex input
  func testBasicTelex() throws {
    let result = transform_text_telex(for: "xin chaof")
    XCTAssertEqual(result, "xin chào")
  }

  /// Test VNI input
  func testBasicVNI() throws {
    let result = transform_text_vni(for: "xin cha2o")
    XCTAssertEqual(result, "xin chào")
  }

  /// Test "khong" with Telex
  func testKhongTelex() throws {
    let result = transform_text_telex(for: "khoong")
    XCTAssertEqual(result, "không")
  }

  // MARK: - Vietnamese Input Recovery Tests

  /// Test that invalid vowel combination triggers recovery
  func testInvalidVowelRecovery() throws {
    // "ae" is not a valid Vietnamese vowel combination
    let result = transform_text_telex(for: "aes")
    // Should recover to original input since "ae" + tone doesn't make sense
    XCTAssertEqual(result, "aes")
  }

  /// Test that invalid final consonant triggers recovery
  func testInvalidFinalConsonantRecovery() throws {
    // "ai" cannot take final consonant "m" - "aim" is invalid
    let result = transform_text_telex(for: "aimf")
    // Should recover to original input
    XCTAssertEqual(result, "aimf")
  }

  /// Test valid Vietnamese still works correctly
  func testValidVietnameseNoRecovery() throws {
    // "tiếng" is valid Vietnamese
    let result = transform_text_telex(for: "tieengs")
    XCTAssertEqual(result, "tiếng")
  }

  /// Test needsRecovery property directly
  func testNeedsRecoveryProperty() throws {
    // Invalid: "ae" vowel combination
    let invalidState = TiengVietState.empty.push("a").push("e")
    XCTAssertTrue(invalidState.needsRecovery)

    // Valid: "a" simple vowel
    let validState = TiengVietState.empty.push("a")
    XCTAssertFalse(validState.needsRecovery)
  }

  /// Test originalInput property
  func testOriginalInputProperty() throws {
    let state = TiengVietState.empty.push("t").push("h").push("a").push("e")
    XCTAssertEqual(state.originalInput, "thae")
  }

  // MARK: - Transformed Vowel Validation Tests

  /// Test "xuất" - the vowel "ua" with circumflex becomes "uâ" which CAN take "t"
  func testXuatWithCircumflex() throws {
    let result = transform_text_telex(for: "xuaats")
    XCTAssertEqual(result, "xuất")
  }

  /// Test "xuân" - the vowel "ua" with circumflex becomes "uâ" which CAN take "n"
  func testXuanWithCircumflex() throws {
    let result = transform_text_telex(for: "xuaan")
    XCTAssertEqual(result, "xuân")
  }

  /// Test "luật" - similar case with "uâ" + "t"
  func testLuatWithCircumflex() throws {
    let result = transform_text_telex(for: "luaatj")
    XCTAssertEqual(result, "luật")
  }

  /// Test "được" - the vowel "uo" with horn becomes "ươ" which CAN take "c"
  func testDuocWithHorn() throws {
    let result = transform_text_telex(for: "dduowcj")
    XCTAssertEqual(result, "được")
  }

  /// Test "mượn" - the vowel "uo" with horn becomes "ươ" which CAN take "n"
  func testMuonWithHorn() throws {
    let result = transform_text_telex(for: "muownj")
    XCTAssertEqual(result, "mượn")
  }

  /// Test that base "ua" without diacritics still cannot take final consonants
  func testUaWithoutDiacriticRecovery() throws {
    // "uat" with no circumflex should trigger recovery since "ua" can't take "t"
    // (This tests the correct behavior - ua alone cannot have final consonant)
    let state = TiengVietState.empty.push("u").push("a").push("t")
    XCTAssertTrue(state.needsRecovery)
  }

  /// Test that "uâ" with circumflex CAN take final consonants
  func testUaWithCircumflexValid() throws {
    // "uât" with circumflex should be valid since "uâ" can take "t"
    let state = TiengVietState.empty.push("u").push("a").push("t").withMu(.muUp).withTone(.sac)
    XCTAssertFalse(state.needsRecovery)
    XCTAssertEqual(state.transformed, "uất")
  }

  // MARK: - Punctuation Edge Case Note
  //
  // The following edge case is handled in InputProcessor.handleEvent():
  // When punctuation follows a valid Vietnamese word (e.g., "xuất."),
  // the punctuation should NOT trigger recovery.
  //
  // Fix: NewWordKeys (punctuation) are checked BEFORE push() is called,
  // so they pass through naturally without affecting the Vietnamese state.
  //
  // Example: "sản xuất." should remain "sản xuất." not become "sản xuaats."
  // This cannot be easily unit tested here as it requires event simulation.

  // MARK: - ===========================================
  // MARK: - COMPREHENSIVE TELEX TYPING TESTS
  // MARK: - ===========================================

  // MARK: - Telex: Basic Tone Marks (s, f, r, x, j)

  /// Test all 5 tone marks with single vowel 'a'
  func testTelexToneMarksOnA() throws {
    XCTAssertEqual(transform_text_telex(for: "as"), "á")   // sắc
    XCTAssertEqual(transform_text_telex(for: "af"), "à")   // huyền
    XCTAssertEqual(transform_text_telex(for: "ar"), "ả")   // hỏi
    XCTAssertEqual(transform_text_telex(for: "ax"), "ã")   // ngã
    XCTAssertEqual(transform_text_telex(for: "aj"), "ạ")   // nặng
  }

  /// Test tone marks with common words
  func testTelexToneMarksInWords() throws {
    XCTAssertEqual(transform_text_telex(for: "mas"), "má")
    XCTAssertEqual(transform_text_telex(for: "maf"), "mà")
    XCTAssertEqual(transform_text_telex(for: "mar"), "mả")
    XCTAssertEqual(transform_text_telex(for: "max"), "mã")
    XCTAssertEqual(transform_text_telex(for: "maj"), "mạ")
  }

  // MARK: - Telex: Diacritical Marks (aa, ee, oo, aw, ow, uw, w)

  /// Test circumflex (mũ) marks: aa→â, ee→ê, oo→ô
  func testTelexCircumflex() throws {
    XCTAssertEqual(transform_text_telex(for: "caan"), "cân")
    XCTAssertEqual(transform_text_telex(for: "been"), "bên")
    XCTAssertEqual(transform_text_telex(for: "tooi"), "tôi")
  }

  /// Test breve (trăng) mark: aw→ă
  func testTelexBreve() throws {
    XCTAssertEqual(transform_text_telex(for: "awn"), "ăn")
    XCTAssertEqual(transform_text_telex(for: "tawm"), "tăm")   // no tone
    XCTAssertEqual(transform_text_telex(for: "tawms"), "tắm")  // with sắc tone
  }

  /// Test horn (móc) marks: ow→ơ, uw→ư
  func testTelexHorn() throws {
    XCTAssertEqual(transform_text_telex(for: "owi"), "ơi")
    XCTAssertEqual(transform_text_telex(for: "uwa"), "ưa")
    XCTAssertEqual(transform_text_telex(for: "muw"), "mư")
    XCTAssertEqual(transform_text_telex(for: "mow"), "mơ")
  }

  /// Test 'w' key alone (context-dependent)
  func testTelexWKey() throws {
    XCTAssertEqual(transform_text_telex(for: "tuowi"), "tươi")
    XCTAssertEqual(transform_text_telex(for: "nguowif"), "người")
  }

  // MARK: - Telex: Đ Character (dd)

  /// Test dd→đ
  func testTelexStrokedD() throws {
    XCTAssertEqual(transform_text_telex(for: "ddi"), "đi")
    XCTAssertEqual(transform_text_telex(for: "dduowcj"), "được")
    XCTAssertEqual(transform_text_telex(for: "ddangs"), "đáng")
  }

  /// Test that dd only toggles đ immediately after an initial d.
  func testTelexStrokedDOnlyAtInitialDD() throws {
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường")
    XCTAssertEqual(transform_text_telex(for: "dad"), "đa")
    XCTAssertEqual(transform_text_telex(for: "ded"), "đe")
  }

  // MARK: - Telex: Combined Diacritics and Tones

  /// Test combinations of circumflex + tone
  func testTelexCircumflexWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "caanf"), "cần")
    XCTAssertEqual(transform_text_telex(for: "taats"), "tất")
    XCTAssertEqual(transform_text_telex(for: "beenr"), "bển")
    XCTAssertEqual(transform_text_telex(for: "tooix"), "tỗi")
    XCTAssertEqual(transform_text_telex(for: "tooij"), "tội")
  }

  /// Test combinations of horn + tone
  func testTelexHornWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "mowx"), "mỡ")
    XCTAssertEqual(transform_text_telex(for: "muws"), "mứ")
    XCTAssertEqual(transform_text_telex(for: "tuowis"), "tưới")
  }

  /// Test combinations of breve + tone
  func testTelexBreveWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "awns"), "ắn")
    XCTAssertEqual(transform_text_telex(for: "tawmf"), "tằm")
    XCTAssertEqual(transform_text_telex(for: "bawngj"), "bặng")
  }

  // MARK: - Telex: Special Consonant Clusters

  /// Test "gi" special case - gi alone vs gi+vowel
  func testTelexGiCases() throws {
    // gi alone: tone goes on 'i'
    XCTAssertEqual(transform_text_telex(for: "gis"), "gí")
    XCTAssertEqual(transform_text_telex(for: "gif"), "gì")

    // gi + vowel: gi is consonant, tone on following vowel
    XCTAssertEqual(transform_text_telex(for: "gias"), "giá")
    XCTAssertEqual(transform_text_telex(for: "giaof"), "giào")
  }

  /// Test "qu" consonant cluster
  func testTelexQuCases() throws {
    XCTAssertEqual(transform_text_telex(for: "qua"), "qua")
    XCTAssertEqual(transform_text_telex(for: "quas"), "quá")
    XCTAssertEqual(transform_text_telex(for: "quaans"), "quấn")
    XCTAssertEqual(transform_text_telex(for: "quaans"), "quấn")
  }

  /// Test "ngh" consonant cluster
  func testTelexNghCases() throws {
    XCTAssertEqual(transform_text_telex(for: "nghif"), "nghì")
    XCTAssertEqual(transform_text_telex(for: "ngheef"), "nghề")
    XCTAssertEqual(transform_text_telex(for: "nghieengj"), "nghiệng")
  }

  /// Test other consonant clusters: ch, kh, ng, nh, ph, th, tr
  func testTelexConsonantClusters() throws {
    XCTAssertEqual(transform_text_telex(for: "chas"), "chá")
    XCTAssertEqual(transform_text_telex(for: "khoong"), "không")  // oo=ô, ngang tone
    XCTAssertEqual(transform_text_telex(for: "ngans"), "ngán")
    XCTAssertEqual(transform_text_telex(for: "nhanf"), "nhàn")
    XCTAssertEqual(transform_text_telex(for: "phos"), "phó")
    XCTAssertEqual(transform_text_telex(for: "thaays"), "thấy")
    XCTAssertEqual(transform_text_telex(for: "trongs"), "tróng")
  }

  // MARK: - Telex: Common Vietnamese Words

  /// Test frequently used Vietnamese words
  func testTelexCommonWords() throws {
    XCTAssertEqual(transform_text_telex(for: "xin"), "xin")
    XCTAssertEqual(transform_text_telex(for: "chaof"), "chào")
    XCTAssertEqual(transform_text_telex(for: "camr"), "cảm")
    XCTAssertEqual(transform_text_telex(for: "own"), "ơn")
    XCTAssertEqual(transform_text_telex(for: "vieejt"), "việt")
    XCTAssertEqual(transform_text_telex(for: "nam"), "nam")
    XCTAssertEqual(transform_text_telex(for: "hanhj"), "hạnh")
    XCTAssertEqual(transform_text_telex(for: "phucs"), "phúc")
  }

  /// Test more complex words
  func testTelexComplexWords() throws {
    XCTAssertEqual(transform_text_telex(for: "nguoiwf"), "người")
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường")
    XCTAssertEqual(transform_text_telex(for: "chuowng"), "chương")
    XCTAssertEqual(transform_text_telex(for: "trinhf"), "trình")
    XCTAssertEqual(transform_text_telex(for: "ruoujw"), "rượu")
    XCTAssertEqual(transform_text_telex(for: "huouw"), "hươu")
    XCTAssertEqual(transform_text_telex(for: "khuyur"), "khuỷu")
    XCTAssertEqual(transform_text_telex(for: "khuya"), "khuya")
  }

  func testTelexTheemTransformation() throws {
    XCTAssertEqual(transform_text_telex(for: "theem"), "thêm")
    XCTAssertEqual(transform_text_telex(for: "them"), "them")
  }

  /// 1.9.7: anywhere `dd` ↔ `đ` toggle trong recovery state.
  /// State machine:
  /// - Stage 0 → 1: 2nd 'd' liên tiếp → toggle ON ('d' → 'đ').
  /// - Stage 1 → 2: 3rd 'd' → toggle OFF ('đ' → 'dd').
  /// - Stage 2: subsequent 'd' = no-op (frozen, giữ nguyên "dd").
  /// Reset stage trên non-'d' char hoặc newWord.
  func testTelexAnywhereDDToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "vcdd"), "vcđ")
    XCTAssertEqual(transform_text_telex(for: "vcddd"), "vcdd")    // toggle off
    XCTAssertEqual(transform_text_telex(for: "vcdddd"), "vcdd")   // frozen
    XCTAssertEqual(transform_text_telex(for: "vcddddd"), "vcdd")  // frozen
    // "add" trigger anywhere-dd vì 'd' sau 'a' rơi conLai (recovery).
    XCTAssertEqual(transform_text_telex(for: "add"), "ađ")
    XCTAssertEqual(transform_text_telex(for: "addd"), "add")
    XCTAssertEqual(transform_text_telex(for: "adddd"), "add")  // frozen
  }

  /// 1.9.7: regression — initial 'dd' (Telex chuẩn `dd → đ` ở đầu từ) phải
  /// vẫn work bình thường, không bị anywhere-toggle override.
  func testTelexInitialDDStillWorks() throws {
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường")
    XCTAssertEqual(transform_text_telex(for: "ddi"), "đi")
  }

  /// v2.3.8 — NFD scalar-aware diff cho autocomplete apps (Chrome).
  /// Bug: "google" trong Chrome ra "gooogle" do Chrome store "ô" decomposed
  /// (o + ̂) — Shift+Left grapheme count thiếu so với scalar storage.
  /// Fix: `calcKeyStrokesNFD` compute diff trong NFD scalar space.
  func testCalcKeyStrokesNFDForCombiningDiacritic() throws {
    // Test 1: "gôg" → "googl" (case chính của bug "google → gooogle")
    // NFC: from=3 chars, to=5 chars, common prefix=1 (chỉ 'g').
    //   backspace=2, diff="oogl" (4 chars).
    // NFD: from=4 scalars (g,o,◌̂,g), to=5 scalars (g,o,o,g,l), common=2 (g,o).
    //   backspace=2, diff="ogl" (3 scalars).
    let (nfcBs, nfcDiff) = EventSimulator.calcKeyStrokes(from: "gôg", to: "googl")
    XCTAssertEqual(nfcBs, 2)
    XCTAssertEqual(String(nfcDiff), "oogl")

    let (nfdBs, nfdDiff) = EventSimulator.calcKeyStrokesNFD(from: "gôg", to: "googl")
    XCTAssertEqual(nfdBs, 2, "NFD backspace count khớp với Chrome scalar storage")
    XCTAssertEqual(String(nfdDiff), "ogl", "NFD diff không chứa 'o' thừa")

    // Test 2: "go" → "gô" (step thêm dấu mũ).
    // v2.3.8–v3.5: append combining mark TRẦN (0 bs + ◌̂) — đúng với field NFD
    // thật nhưng PHÁ CHỮ nếu field hoá ra là NFC ("nhập" → "nḥ̂p" ở save panel
    // của Chrome). v3.6: snap về đầu cụm — xoá "o" + retype "ô" hoàn chỉnh,
    // đúng ở CẢ field NFD lẫn NFC.
    let (gôBs, gôDiff) = EventSimulator.calcKeyStrokesNFD(from: "go", to: "gô")
    XCTAssertEqual(gôBs, 1, "xoá 'o' rồi retype nguyên cụm — không gửi dấu trần")
    XCTAssertEqual(gôDiff, ["ô"], "retype cụm grapheme hoàn chỉnh")

    // Test 3: ASCII-only — NFD bằng NFC khi không có combining marks.
    let (a1, d1) = EventSimulator.calcKeyStrokes(from: "hello", to: "hello world")
    let (a2, d2) = EventSimulator.calcKeyStrokesNFD(from: "hello", to: "hello world")
    XCTAssertEqual(a1, a2)
    XCTAssertEqual(String(d1), String(d2))

    // Test 4: Common prefix với "ô" — NFD vs NFC khác nhau.
    // "gô" → "go": NFC common=1, NFD common=2.
    let (nfcBs2, _) = EventSimulator.calcKeyStrokes(from: "gô", to: "go")
    let (nfdBs2, _) = EventSimulator.calcKeyStrokesNFD(from: "gô", to: "go")
    XCTAssertEqual(nfcBs2, 1, "NFC: backspace 1 grapheme 'ô'")
    XCTAssertEqual(nfdBs2, 1, "NFD: backspace 1 scalar (combining ̂)")
  }

  /// v2.3.21 — Telex mu cancellation pattern detect.
  /// User gõ 3 nguyên âm liên tiếp để cancel Telex mu → engine produces 2-vowel
  /// English-like word. Pattern detection cho phép keep transformed mà không
  /// cần word trong English lexicon (catches "foooter→footer", etc.).
  func testTelexCancellationPatternDetect() throws {
    // Match cases
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "gooogle", transformed: "google"))
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "foooter", transformed: "footer"))
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "nooose", transformed: "noose"))
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "aaab", transformed: "aab"))
    // Case-insensitive
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "GOOOGLE", transformed: "GOOGLE"))

    // Non-match cases
    XCTAssertFalse(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "google", transformed: "google"))  // No triple
    XCTAssertFalse(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "gooogle", transformed: "googlo"))  // Triple but not the collapse
    XCTAssertFalse(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "abc", transformed: "abc"))
  }

  /// v2.3.7 — Universal anywhere-DD: hoạt động ngay cả khi Free Mark Mode bật.
  /// Free Mark Mode bypass `needsRecovery` → `stopProcessing` không được set →
  /// existing anywhere-DD (gated bởi stopProcessing) không fire. Universal rule
  /// mới đặt ở pre-check fire bất kể state.
  func testTelexAnywhereDDWithFreeMarkMode() throws {
    let oldFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.freeMarkModeEnabled] = true
    defer { Defaults[.freeMarkModeEnabled] = oldFreeMark }

    // Anywhere-DD vẫn phải hoạt động:
    XCTAssertEqual(transform_text_telex(for: "vcdd"), "vcđ", "vcdd phải ra vcđ kể cả Free Mark")
    XCTAssertEqual(transform_text_telex(for: "QDD"), "QĐ", "QDD phải ra QĐ kể cả Free Mark")
    XCTAssertEqual(transform_text_telex(for: "BCTDD"), "BCTĐ", "BCTDD phải ra BCTĐ kể cả Free Mark")

    // Initial dd vẫn ok (Telex chuẩn):
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường", "Initial dd vẫn → đ kể cả Free Mark")
  }

  /// v2.3.7 — All-caps abbreviations với DD trailing → Đ.
  /// User report: gõ `QDD` muốn ra `QĐ` (Quyết Định), `BCTDD` muốn ra `BCTĐ`,…
  /// Đây là anywhere-DD toggle nhưng cho all-uppercase abbreviation.
  func testTelexAllCapsAbbreviationDD() throws {
    // Print actual output để debug — verify chính xác behavior.
    let qdd = transform_text_telex(for: "QDD")
    let bctdd = transform_text_telex(for: "BCTDD")
    let ndd = transform_text_telex(for: "NDD")
    let qddMixed = transform_text_telex(for: "Qdd")
    print("DEBUG QDD: '\(qdd)' (expect 'QĐ')")
    print("DEBUG BCTDD: '\(bctdd)' (expect 'BCTĐ')")
    print("DEBUG NDD: '\(ndd)' (expect 'NĐ')")
    print("DEBUG Qdd: '\(qddMixed)' (expect 'Qđ')")

    // QDD → QĐ (Quyết Định)
    XCTAssertEqual(qdd, "QĐ", "QDD phải ra QĐ")
    // BCTDD → BCTĐ
    XCTAssertEqual(bctdd, "BCTĐ", "BCTDD phải ra BCTĐ")
    // NĐDD — type "NDD" thì "NĐ" (mid-stream all-caps)
    XCTAssertEqual(ndd, "NĐ", "NDD phải ra NĐ")
    // Mixed-case không bị uppercase hóa: Qdd → Qđ
    XCTAssertEqual(qddMixed, "Qđ", "Qdd (mixed) → Qđ giữ case")
  }

  /// 1.8.4: Telex regression — gõ "teen" (t + ee→ê + n) phải ra "tên" VN,
  /// không lock raw "teen". Bug v1.7.9: post-replay check dùng full enLexicon
  /// 9826 từ — "teen" match → override sang raw. Fix: dùng isInstantRestoreEnglish
  /// (narrow 126 + userAllow). Verify VN typing chính xác cho các stem ngắn.
  func testTelexPostReplayKeepsVN() throws {
    XCTAssertEqual(transform_text_telex(for: "teen"), "tên")
    // Regression check: tees vẫn ra tế (tee là embedded English nhưng tees
    // không phải English word → replay → keep VN).
    XCTAssertEqual(transform_text_telex(for: "tees"), "tế")
    // theem → thêm (the là English nhưng theem không) — đã có ở testV146BugFixes.
    XCTAssertEqual(transform_text_telex(for: "theem"), "thêm")
  }

  /// 1.8.3: các từ tiếng Anh có "oo" mà engine tự recovery (raw output)
  /// nhờ vowel+final cluster không hợp lệ VN. Đảm bảo những từ này KHÔNG
  /// bị nhầm sang VN khi gõ. Một số từ khác như "room"/"door"/"foot" mà
  /// "ôm"/"ổ"/"ôt" đều là VN valid → engine transform sang VN, fix bằng
  /// select-and-replace strategy ở commit-time (xem applySpellDecisionOnCommit).
  func testTelexEnglishOORecovery() throws {
    XCTAssertEqual(transform_text_telex(for: "footer"), "footer")
    XCTAssertEqual(transform_text_telex(for: "book"), "book")
    XCTAssertEqual(transform_text_telex(for: "books"), "books")
    XCTAssertEqual(transform_text_telex(for: "look"), "look")
    XCTAssertEqual(transform_text_telex(for: "wood"), "wood")
    XCTAssertEqual(transform_text_telex(for: "food"), "food")
  }

  // MARK: - 2.0.2 (J2): Regression cho bug class "toools"
  //
  // Trước 2.0.2 có bug: gõ "text tools" + Space → ra "toools" (thừa 1 'o')
  // do logic `transformed.count == lastTransformedForStep.count` trong
  // InputProcessor.swift (3 sites) append raw 'o' khi engine vừa apply
  // combining diacritic (cùng grapheme count nhưng NFD scalar count tăng).
  // Fix: dùng `WordBuffer.shouldAppendRawKey(...)` so sánh NFD scalars.

  /// v2.2.0: bug "theme" → "themee" (thừa ký tự). Bản chất bug là engine LEAK
  /// raw key khi `isInstantRestoreEnglish` hit ở mid-word → output dài hơn input.
  /// Test này canh giữ điều đó: output KHÔNG được dài hơn input.
  /// (v2.9: "theme" đã được bỏ khỏi instant-restore → Telex ra "thêm" — vẫn
  /// thoả ≤ input.count. "scheme/scene/phone/type" vẫn giữ raw English.)
  func testTelex_2_2_0_theme_no_extra_char() throws {
    XCTAssertEqual(transform_text_telex(for: "theme"), "thêm")  // v2.9: từ VN
    XCTAssertEqual(transform_text_telex(for: "scheme"), "scheme")
    for input in ["theme", "scheme", "scene", "phone", "type"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(
        output.count, input.count,
        "Bug v2.2.0 theme-class: '\(input)' → '\(output)' (thừa ký tự!)"
      )
    }
  }

  /// Test bug "tools" — verify NO EXTRA char appended.
  /// Trước fix: "tools" (5 chars) → "toools" (6 chars, thừa 'o').
  /// Sau fix: output có ≤5 graphemes (có thể là "tools" raw English, hoặc
  /// "tols", hoặc VN transform — quan trọng là KHÔNG dài hơn input).
  /// "tools" cụ thể nằm trong English lexicon → ra "tools".
  func testTelex_J2_oo_class_no_extra_char() throws {
    // Cases có trong English lexicon → restore raw English:
    XCTAssertEqual(transform_text_telex(for: "tools"), "tools")
    // Cases khác — verify count: input.count chars in, output count ≤ input
    // (không thừa ký tự do bug oo). Output có thể là VN transform.
    for input in ["boot", "boost", "bloom", "shoot", "loop", "stoop", "goose"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(
        output.count, input.count,
        "Bug J2 regression: '\(input)' → '\(output)' (thừa ký tự!). Output should be ≤ \(input.count) graphemes."
      )
    }
  }

  /// Test bug class "aa" trigger: KHÔNG thừa ký tự.
  func testTelex_J2_aa_class_no_extra_char() throws {
    for input in ["baa", "naan", "saari"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(output.count, input.count, "Bug J2 aa: '\(input)' → '\(output)'")
    }
  }

  /// Test bug class "ee" trigger: KHÔNG thừa ký tự.
  func testTelex_J2_ee_class_no_extra_char() throws {
    // "see", "fee", "bee" có thể có trong lexicon — verify count không tăng.
    for input in ["bee", "see", "fee", "wee"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(output.count, input.count, "Bug J2 ee: '\(input)' → '\(output)'")
    }
  }

  /// Test path replay (J2 site 2): từ tiếng Anh có 'oo' qua replay path.
  func testTelex_J2_replay_path_no_extra_char() throws {
    XCTAssertEqual(transform_text_telex(for: "footer"), "footer")
    for input in ["tooth", "smooth", "bloom"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(output.count, input.count, "Bug J2 replay: '\(input)' → '\(output)'")
    }
  }

  /// Test VNI bug class — toggle digit cancel VẪN cho ký tự thô '1','6','8','9'.
  /// Đây là path tốt cho `shouldAppendRawKey` cần TRẢ TRUE (NFD giảm).
  func testVNI_J2_digit_toggle_preserved() throws {
    XCTAssertEqual(transform_text_vni(for: "a11"), "a1")  // tone sac cancel
    XCTAssertEqual(transform_text_vni(for: "a66"), "a6")  // circumflex cancel
    XCTAssertEqual(transform_text_vni(for: "a88"), "a8")  // breve cancel
    XCTAssertEqual(transform_text_vni(for: "d99"), "d9")  // d stroked cancel
  }

  /// Test Telex triple-toggle vẫn đúng (không bị over-fix).
  func testTelex_J2_triple_toggle_preserved() throws {
    XCTAssertEqual(transform_text_telex(for: "aaa"), "aa")  // â cancel
    XCTAssertEqual(transform_text_telex(for: "ooo"), "oo")  // ô cancel
    XCTAssertEqual(transform_text_telex(for: "eee"), "ee")  // ê cancel
    XCTAssertEqual(transform_text_telex(for: "aww"), "aw")  // ơ→aw cancel
    XCTAssertEqual(transform_text_telex(for: "uww"), "uw")  // ư→uw cancel
  }

  /// Test Vietnamese đúng cách (không break engine Telex chuẩn).
  func testTelex_J2_vietnamese_typing_preserved() throws {
    XCTAssertEqual(transform_text_telex(for: "tieengs"), "tiếng")
    XCTAssertEqual(transform_text_telex(for: "ddoongf"), "đồng")
    XCTAssertEqual(transform_text_telex(for: "khoer"), "khoẻ")
    XCTAssertEqual(transform_text_telex(for: "vieejt"), "việt")
  }

  /// Test v1.4.6 bug fixes: English word restoration replay, uo horn handling, and common words
  func testV146BugFixes() throws {
    // English word restoration replay fixes
    XCTAssertEqual(transform_text_telex(for: "tees"), "tế")       // "tee" is English, but tees → tế
    XCTAssertEqual(transform_text_telex(for: "heest"), "hết")     // "he" is English, but heest → hết
    XCTAssertEqual(transform_text_telex(for: "theem"), "thêm")    // "the" is English, but theem → thêm

    // Horn mark (muMoc) on uo pattern - always apply to both vowels
    XCTAssertEqual(transform_text_telex(for: "dduwowcj"), "được") // uo horn should persist through second w
    XCTAssertEqual(transform_text_telex(for: "dduowcj"), "được")  // Standard form without extra w

    // Basic Telex transformations (regression)
    XCTAssertEqual(transform_text_telex(for: "soats"), "soát")
    XCTAssertEqual(transform_text_telex(for: "gox"), "gõ")
    XCTAssertEqual(transform_text_telex(for: "tooi"), "tôi")
    XCTAssertEqual(transform_text_telex(for: "Goiwj"), "Gợi")
    XCTAssertEqual(transform_text_telex(for: "vieetj"), "việt")
    XCTAssertEqual(transform_text_telex(for: "chinhs"), "chính")
    XCTAssertEqual(transform_text_telex(for: "nhuwng"), "nhưng")
    XCTAssertEqual(transform_text_telex(for: "ddang"), "đang")
    XCTAssertEqual(transform_text_telex(for: "looix"), "lỗi")
    XCTAssertEqual(transform_text_telex(for: "looij"), "lội")
    XCTAssertEqual(transform_text_telex(for: "cuax"), "cũa")
    XCTAssertEqual(transform_text_telex(for: "cuar"), "của")
  }

  // MARK: - Telex: Toggle Behavior (Double Typing)

  /// Test tone toggle (typing same tone twice removes it)
  /// 1.7.5: tone-cancel ưu tiên hơn English doubled-tone preservation —
  /// gõ "ar" + "r" = cancel hỏi tone (a + r tạo dấu hỏi rồi r thứ 2 xoá),
  /// kết quả "ar" (raw a + raw r append). Trade-off: từ tiếng Anh hiếm
  /// như "ass"/"arr"/"aff" không còn được preserve khi gõ tuần tự.
  func testTelexToneToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "ass"), "as")
    XCTAssertEqual(transform_text_telex(for: "aff"), "af")
    XCTAssertEqual(transform_text_telex(for: "arr"), "ar")
    XCTAssertEqual(transform_text_telex(for: "axx"), "ax")
    XCTAssertEqual(transform_text_telex(for: "ajj"), "aj")
  }

  /// Test diacritical mark toggle
  func testTelexDiacriticToggle() throws {
    // Triple 'a' should result in 'aa' (â toggle off + a)
    XCTAssertEqual(transform_text_telex(for: "aaa"), "aa")
    XCTAssertEqual(transform_text_telex(for: "ooo"), "oo")
    XCTAssertEqual(transform_text_telex(for: "eee"), "ee")
  }

  /// Test 'w' toggle
  func testTelexWToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "aww"), "aw")
    XCTAssertEqual(transform_text_telex(for: "oww"), "ow")
    XCTAssertEqual(transform_text_telex(for: "uww"), "uw")
  }

  /// Test 'dd' toggle (triple d)
  func testTelexDToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "ddd"), "dd")
  }

  // MARK: - Telex: Recovery Cases (Invalid Vietnamese)

  /// Test invalid vowel combinations trigger recovery
  func testTelexInvalidVowelRecovery() throws {
    XCTAssertEqual(transform_text_telex(for: "aes"), "aes")
    XCTAssertEqual(transform_text_telex(for: "eas"), "eas")
    XCTAssertEqual(transform_text_telex(for: "yis"), "yis")
  }

  /// Test invalid final consonant triggers recovery
  func testTelexInvalidFinalConsonantRecovery() throws {
    // "ai" cannot have final consonants
    XCTAssertEqual(transform_text_telex(for: "aims"), "aims")
    XCTAssertEqual(transform_text_telex(for: "aotn"), "aotn")
  }

  /// Test foreign/loanwords that bypass Vietnamese rules
  func testTelexForeignWords() throws {
    // Words starting with non-Vietnamese patterns
    XCTAssertEqual(transform_text_telex(for: "macro"), "macro")
    XCTAssertEqual(transform_text_telex(for: "wifi"), "wifi")
  }

  func testAllowedZWJF() throws {
    // Save current state
    let oldPhuAmDau = TiengViet.PhuAmDau
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldAllowedZWJF = Defaults[.allowedZWJF]
    Defaults[.spellCheckEnabled] = false
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.allowedZWJF] = oldAllowedZWJF
    }
    
    // Simulate allowedZWJF = false
    Defaults[.allowedZWJF] = false
    TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon
    TiengViet.updatePhuAmDauTrie()
    XCTAssertEqual(transform_text_telex(for: "zas"), "zas")
    XCTAssertEqual(transform_text_telex(for: "fair"), "fair")
    
    // Simulate allowedZWJF = true
    Defaults[.allowedZWJF] = true
    TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon + TiengViet.PhuAmDonNuocNgoai
    TiengViet.updatePhuAmDauTrie()
    XCTAssertEqual(transform_text_telex(for: "zas"), "zá")
    XCTAssertEqual(transform_text_telex(for: "fair"), "fải")
    
    // Restore
    TiengViet.PhuAmDau = oldPhuAmDau
    TiengViet.updatePhuAmDauTrie()
  }

  // MARK: - Telex: Edge Cases

  /// Test single vowels with tone
  func testTelexSingleVowels() throws {
    XCTAssertEqual(transform_text_telex(for: "as"), "á")
    XCTAssertEqual(transform_text_telex(for: "es"), "é")
    XCTAssertEqual(transform_text_telex(for: "is"), "í")
    XCTAssertEqual(transform_text_telex(for: "os"), "ó")
    XCTAssertEqual(transform_text_telex(for: "us"), "ú")
    XCTAssertEqual(transform_text_telex(for: "ys"), "ý")
  }

  /// Test words ending with valid consonants
  func testTelexValidFinalConsonants() throws {
    XCTAssertEqual(transform_text_telex(for: "acs"), "ác")   // -c
    XCTAssertEqual(transform_text_telex(for: "achj"), "ạch") // -ch
    XCTAssertEqual(transform_text_telex(for: "ams"), "ám")   // -m
    XCTAssertEqual(transform_text_telex(for: "anf"), "àn")   // -n
    XCTAssertEqual(transform_text_telex(for: "angf"), "àng") // -ng
    XCTAssertEqual(transform_text_telex(for: "anhf"), "ành") // -nh
    XCTAssertEqual(transform_text_telex(for: "aps"), "áp")   // -p
    XCTAssertEqual(transform_text_telex(for: "ats"), "át")   // -t
  }

  /// Test uppercase handling
  func testTelexUppercase() throws {
    XCTAssertEqual(transform_text_telex(for: "VIEEJT"), "VIỆT")
    XCTAssertEqual(transform_text_telex(for: "NAM"), "NAM")
    XCTAssertEqual(transform_text_telex(for: "DDUOWNGF"), "ĐƯỜNG")
  }

  /// Regression 1.7.10: v1.7.9 bump EN dict 126 → 9826 từ làm các telex
  /// stem ngắn ("cos", "hop", "the", "tie") match English → lock raw,
  /// bỏ qua telex transform. Fix: instant-restore dùng list HẸP (embedded
  /// 126 + userAllow) thay vì full lexicon.
  func testTelexEnglishCollisionHotfix() throws {
    XCTAssertEqual(transform_text_telex(for: "cos"), "có")
    XCTAssertEqual(transform_text_telex(for: "hopwj"), "hợp")
    XCTAssertEqual(transform_text_telex(for: "tieengs"), "tiếng")
    XCTAssertEqual(transform_text_telex(for: "theer"), "thể")
    XCTAssertEqual(transform_text_telex(for: "thoongs"), "thống")
    XCTAssertEqual(transform_text_telex(for: "cof"), "cò")
    XCTAssertEqual(transform_text_telex(for: "cor"), "cỏ")
  }

  /// Regression 1.7.10: instant-restore vẫn hoạt động cho các từ trong
  /// embedded EmbeddedLexiconData.englishWords (off/class/staff).
  func testEnglishInstantRestoreEmbeddedStillWorks() throws {
    XCTAssertEqual(transform_text_telex(for: "off"), "off")
    XCTAssertEqual(transform_text_telex(for: "class"), "class")
    XCTAssertEqual(transform_text_telex(for: "staff"), "staff")
  }

  /// Regression 1.7.5: gõ "a r r m" (a + r tạo dấu hỏi + r xoá dấu + m)
  /// phải ra "arm" thay vì "arrm". Bug do English-word "arr" lock raw bypass
  /// tone-cancel. Fix: detect tone-cancel intent (state có tone + char là
  /// tone key) → skip English-word preservation, để engine.push toggle tone.
  func testTelexToneCancelArrm() throws {
    XCTAssertEqual(transform_text_telex(for: "arrm"), "arm")
    XCTAssertEqual(transform_text_telex(for: "ARRM"), "ARM")
    // Tương tự với các tone keys khác
    XCTAssertEqual(transform_text_telex(for: "assm"), "asm")  // a + s sắc + s cancel + m
    XCTAssertEqual(transform_text_telex(for: "affm"), "afm")  // huyền cancel
    XCTAssertEqual(transform_text_telex(for: "axxm"), "axm")  // ngã cancel
    XCTAssertEqual(transform_text_telex(for: "ajjm"), "ajm")  // nặng cancel
  }

  /// Regression 1.7.7: gõ "dùng" (telex: dungf) phải ra "dùng", không phải
  /// "đùng". Trước đây tryLateDToggle có thể trigger nhầm khi user gõ thêm
  /// 'd' trong/cuối từ chưa hoàn chỉnh hoặc khi state cho phép quá rộng.
  /// Pattern "dinjhd" (telex của "định") vẫn phải toggle gạch D đúng.
  func testTelexLateDToggleGated() throws {
    XCTAssertEqual(transform_text_telex(for: "dungf"), "dùng")
    XCTAssertEqual(transform_text_telex(for: "dung"), "dung")
    XCTAssertEqual(transform_text_telex(for: "dinjhd"), "định")
    XCTAssertEqual(transform_text_telex(for: "dd"), "đ")  // toggle dd vẫn đúng
    XCTAssertEqual(transform_text_telex(for: "ddungf"), "đùng")  // intentional đ
  }

  /// Test late D toggle for syllables of length 2 (Telex and VNI)
  func testLateDToggleLength2() throws {
    XCTAssertEqual(transform_text_telex(for: "did"), "đi")
    XCTAssertEqual(transform_text_vni(for: "di9"), "đi")
    
    // Non-syllable boundary should not trigger
    XCTAssertEqual(transform_text_telex(for: "d"), "d")
    XCTAssertEqual(transform_text_telex(for: "di"), "di")
  }

  /// Test backspace rollback for late-D and complex syllables
  func testBackspaceRollback() throws {
    // Telex
    let processor = InputProcessor(method: .Telex)
    
    // test "did" -> backspace -> "di"
    processor.newWord()
    processor.push(char: "d")
    processor.push(char: "i")
    processor.push(char: "d")
    XCTAssertEqual(processor.transformed, "đi")
    
    let (backspaces1, diff1) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(backspaces1, 2)
    XCTAssertEqual(String(diff1), "di")
    XCTAssertEqual(processor.transformed, "di")
    
    // test "dinjhd" -> backspace -> "dịnh"
    processor.newWord()
    processor.push(char: "d")
    processor.push(char: "i")
    processor.push(char: "n")
    processor.push(char: "h")
    processor.push(char: "j")
    XCTAssertEqual(processor.transformed, "dịnh")
    processor.push(char: "h")
    XCTAssertEqual(processor.transformed, "dinhjh") // enters recovery/stopProcessing
    processor.push(char: "d")
    XCTAssertEqual(processor.transformed, "dinhjhd") // recovery continues
    
    // Backspace once to get "dinhjh" (keys: "dinhjh")
    let (backspaces2, diff2) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(backspaces2, 0) // lets OS handle it (1-char delete)
    XCTAssertEqual(String(diff2), "")
    XCTAssertEqual(processor.transformed, "dinhjh")
    
    // Backspace again to restore "dịnh" (keys: "dinjh", from snapshot)
    let (backspaces3, diff3) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(backspaces3, 5) // deletes "inhjh" (5 chars)
    XCTAssertEqual(String(diff3), "ịnh")
    XCTAssertEqual(processor.transformed, "dịnh")
    
    // VNI
    let vniProcessor = InputProcessor(method: .VNI)
    
    // test "di9" -> backspace -> "di"
    vniProcessor.newWord()
    vniProcessor.push(char: "d")
    vniProcessor.push(char: "i")
    vniProcessor.push(char: "9")
    XCTAssertEqual(vniProcessor.transformed, "đi")
    
    let (vniB1, vniD1) = vniProcessor.pop(usesNFC: vniProcessor.usesNFCForFocusedField())
    XCTAssertEqual(vniB1, 2)
    XCTAssertEqual(String(vniD1), "di")
    XCTAssertEqual(vniProcessor.transformed, "di")
  }

  /// Regression 1.7.4: gõ ARM (initialism English) khi commit phải restore
  /// về "ARM" thay vì giữ "Ảm" (vkey vô tình áp tone hỏi cho R). Fix ở
  /// SpellDecisionEngine: detect all-caps ASCII alphabetic ≥2-≤5 chars,
  /// không có double-letter Telex signal, không kết bằng tone key → coi
  /// là English acronym → restoreRawEnglish.
  func testSpellDecisionArmAcronymRestore() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true

    // 4.12: acronym restore khi transformed là từ VN hợp lệ (ARM→Ảm, USA→Úa)
    // giờ yêu cầu raw là từ EN thật. Embedded EN chỉ 126 từ (không có
    // arm/usa) → inject package hermetic thay vì phụ thuộc lexicon-update
    // .json đã tải trên máy chạy test.
    let path = URL(fileURLWithPath: "/tmp/vkey-lexicon-acronym-test.json")
    let manager = LexiconManager(updatePackageURL: path)
    let package = """
    {
      "version": 5,
      "vietnamese": ["ảm","úa","đỏ","đo","việt"],
      "english": ["arm","usa"],
      "keep": []
    }
    """
    try manager.setUpdatePackageData(Data(package.utf8))
    manager.reload()
    defer { try? FileManager.default.removeItem(at: path) }
    let engine = SpellDecisionEngine(lexiconManager: manager)

    XCTAssertEqual(
      engine.evaluate(rawInput: "ARM", transformed: "Ảm", needsRecovery: false),
      .restoreRawEnglish("ARM")
    )
    XCTAssertEqual(
      engine.evaluate(rawInput: "USA", transformed: "Úa", needsRecovery: false),
      .restoreRawEnglish("USA")
    )
    XCTAssertEqual(
      engine.evaluate(rawInput: "API", transformed: "Apí", needsRecovery: false),
      .restoreRawEnglish("API")
    )
    // Không acronym (length > 5):
    XCTAssertNotEqual(
      engine.evaluate(rawInput: "VIEEJT", transformed: "VIỆT", needsRecovery: false),
      .restoreRawEnglish("VIEEJT")
    )
    // Không acronym (last char là tone key):
    XCTAssertNotEqual(
      engine.evaluate(rawInput: "DDOR", transformed: "Đỏ", needsRecovery: false),
      .restoreRawEnglish("DDOR")
    )
    // Không acronym (chứa double-letter Telex pattern "dd"):
    XCTAssertNotEqual(
      engine.evaluate(rawInput: "DDO", transformed: "Đo", needsRecovery: false),
      .restoreRawEnglish("DDO")
    )
  }

  /// Regression 4.12: từ tiếng Việt viết HOA (Caps Lock heading) với phím
  /// dấu GIỮA từ khớp pattern acronym → từng bị restore nhầm thành phím thô:
  /// "TOÁN" + Space → "TOASN" (tương tự BÁN/HỌC/VÀNG/PHÁP/SÁCH). Acronym
  /// giờ chỉ restore khi transformed KHÔNG phải từ VN hợp lệ hoặc raw là từ
  /// EN thật — từ VN hợp lệ với raw vô nghĩa phải giữ nguyên.
  func testSpellDecisionAllCapsVietnameseWordKept() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true

    // Engine mặc định: VN lexicon từ syllables asset (có đủ toán/bán/học/
    // vàng/pháp/sách), raw "toasn"… không có trong bất kỳ list EN nào.
    let engine = SpellDecisionEngine.shared
    let cases: [(raw: String, transformed: String)] = [
      ("TOASN", "TOÁN"),
      ("BASN", "BÁN"),
      ("HOJC", "HỌC"),
      ("VAFNG", "VÀNG"),
      ("PHASP", "PHÁP"),
      ("SASCH", "SÁCH"),
    ]
    for c in cases {
      XCTAssertEqual(
        engine.evaluate(rawInput: c.raw, transformed: c.transformed, needsRecovery: false),
        .keepVietnamese,
        "\(c.raw) → \(c.transformed) phải giữ tiếng Việt, không restore raw"
      )
    }
  }

  /// 4.12: matchCase — auto-suggestion từ lexicon là chữ thường; thay thế
  /// phải giữ kiểu hoa/thường của từ user gõ (ALL-CAPS / hoa chữ đầu).
  func testMatchCasePreservesSourceCapitalization() throws {
    XCTAssertEqual(InputProcessor.matchCase(of: "TOASN", to: "toán"), "TOÁN")
    XCTAssertEqual(InputProcessor.matchCase(of: "Dinhj", to: "định"), "Định")
    XCTAssertEqual(InputProcessor.matchCase(of: "dinhj", to: "định"), "định")
    XCTAssertEqual(InputProcessor.matchCase(of: "ĐINHJ", to: "định"), "ĐỊNH")
    // 1 chữ cái hoa → chỉ viết hoa chữ đầu (không đủ tín hiệu ALL-CAPS).
    XCTAssertEqual(InputProcessor.matchCase(of: "A", to: "à"), "À")
    XCTAssertEqual(InputProcessor.matchCase(of: "", to: "định"), "định")
  }

  /// Test mixed case
  func testTelexMixedCase() throws {
    XCTAssertEqual(transform_text_telex(for: "Vieejt"), "Việt")
    XCTAssertEqual(transform_text_telex(for: "DDuowngf"), "Đường")
  }

  /// Bất biến 4.13 — quét TOÀN BỘ instant-restore list bằng engine thật:
  /// từ EN nào mà Telex thuần biến ra từ VN hợp lệ ≥2 ký tự VÀ vẫn thắng
  /// lúc gõ (giữ raw EN) thì PHẢI nằm trong danh sách ngoại lệ đã quyết
  /// định bên dưới. Thêm từ EN mới tạo xung đột chưa quyết → test này fail,
  /// buộc phải cân nhắc (VN thắng qua guard toneKeyCompletesVietnameseWord /
  /// gỡ khỏi list, hay EN thắng có chủ đích thì thêm vào ngoại lệ).
  func testInstantRestoreConflictsAreAllDecided() throws {
    // EN thắng CÓ CHỦ ĐÍCH: hể/thể/thế/sê chỉ bị chiếm khi gõ dấu-TRƯỚC-mũ
    // (thứ tự hiếm; kiểu chuẩn heer/theer/thees không ảnh hưởng), còn
    // here/there/these/three/see là từ EN cực phổ biến. 4.14: pass/horses
    // — phím tone lặp CANCEL dấu + keys khớp list → khoá raw đầy đủ (fix
    // "pas"/"hoe"); pure transform "pa"/"hoe" là VN nhưng chỉ gõ được qua
    // thứ tự phím vô nghĩa với người gõ VN.
    let intendedEnglishWinners: Set<String> = [
      "here", "there", "these", "three", "see", "pass", "horses",
    ]

    let engine = Telex()
    var undecided: [String] = []
    for w in EmbeddedLexiconData.englishWords.sorted() {
      var state = TiengVietState.empty
      var broke = false
      for c in w {
        let r = engine.push(char: c, state: state)
        state = r.state
        if state.needsRecovery { broke = true; break }
      }
      if broke { continue }
      let pure = state.transformed
      guard pure != w, pure.count >= 2,
            LexiconManager.shared.isVietnameseWord(pure) else { continue }
      // EN vẫn thắng lúc gõ (raw giữ nguyên) mà chưa có trong ngoại lệ?
      if transform_text_telex(for: w) == w, !intendedEnglishWinners.contains(w) {
        undecided.append("\(w) -> \(pure)")
      }
    }
    XCTAssertTrue(
      undecided.isEmpty,
      "Từ EN trong instant-restore đè từ VN hợp lệ mà chưa được quyết định: \(undecided)"
    )
  }

  /// Regression 4.14: phím tone lặp lại CANCEL dấu + toàn bộ keys khớp
  /// instant-restore EN → khoá raw ĐẦY ĐỦ. Trước đây "pass" ra "pas" (mất
  /// 1 chữ s — phím s đầu bị consume làm dấu), "horses" ra "hoe", "nurses"
  /// ra sai tương tự. Escape hatch VN ("thiss"→"this", "lisst"→"list",
  /// không khớp list) và các từ đi đường khác (off/staff/class qua instant
  /// lock/cluster) giữ nguyên.
  func testDoubledToneEnglishWordsKeptFull() throws {
    XCTAssertEqual(transform_text_telex(for: "pass"), "pass")
    XCTAssertEqual(transform_text_telex(for: "PASS"), "PASS")
    XCTAssertEqual(transform_text_telex(for: "horses"), "horses")
    XCTAssertEqual(transform_text_telex(for: "nurses"), "nurses")
    XCTAssertEqual(transform_text_telex(for: "business"), "business")
    // Không đổi hành vi cũ:
    XCTAssertEqual(transform_text_telex(for: "off"), "off")
    XCTAssertEqual(transform_text_telex(for: "staff"), "staff")
    XCTAssertEqual(transform_text_telex(for: "class"), "class")
    XCTAssertEqual(transform_text_telex(for: "thiss"), "this")
    XCTAssertEqual(transform_text_telex(for: "lisst"), "list")
    // Cancel ngắn (< 4 phím) giữ semantics cũ — double-tap xoá dấu rồi gõ
    // tiếp vẫn hoạt động (xem testTelexToneToggle/testTelexToneCancelArrm):
    XCTAssertEqual(transform_text_telex(for: "ass"), "as")
    XCTAssertEqual(transform_text_telex(for: "arrm"), "arm")
  }

  /// Regression 4.14: sau tone-cancel EN lock, backspace phải về raw prefix
  /// ("pass"→"pas"), không rollback về state Telex còn dấu ("pá").
  func testToneCancelEnglishLockBackspaceKeepsRawPrefix() throws {
    var buffer = WordBuffer()
    let engine = Telex()

    for c in "pass" { buffer.push(char: c, engine: engine) }
    XCTAssertEqual(buffer.transformed, "pass")
    XCTAssertTrue(buffer.stopProcessing)
    XCTAssertTrue(buffer.stoppedByEnglishWord)

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "pas")
    XCTAssertEqual(String(buffer.keys), "pas")
    XCTAssertTrue(buffer.stopProcessing)
    XCTAssertTrue(buffer.stoppedByEnglishWord)

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "pa")
    XCTAssertEqual(String(buffer.keys), "pa")

    buffer = WordBuffer()
    for c in "horses" { buffer.push(char: c, engine: engine) }
    XCTAssertEqual(buffer.transformed, "horses")
    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "horse")
    XCTAssertEqual(String(buffer.keys), "horse")
  }

  /// Regression 4.15: field NFD (web content Chromium/Electron — gồm ô chat
  /// claude.ai) — chuỗi diff NFD kế tiếp khi gõ một từ có dấu phải DỰNG LẠI
  /// ĐÚNG từ đó, KHÔNG rụng phụ âm đầu. Bug 4.14 ("Chrome tìm kiếm NFC") ép
  /// emit NFC vào field NFD → field lưu ít scalar hơn model → backspace dư ăn
  /// mất ký tự trước nguyên âm mang dấu ("gửi"→"ửi", "sửa"→"ửa", "mất"→"ất").
  /// Mô phỏng field bằng buffer scalar NFD, áp đúng (backspaceCount, emit) mà
  /// InputProcessor sinh ra qua calcKeyStrokesNFD + emittedCharacters.
  ///
  /// ⚠️ PHẠM VI (đọc trước khi trích dẫn test này làm bằng chứng): `replayNFDField`
  /// mô phỏng field bằng `fieldScalars.removeLast(bs)`, tức GIẢ ĐỊNH SẴN rằng một
  /// backspace xoá MỘT SCALAR. Đó chính là giả thuyết đang cần kiểm chứng (xem
  /// khối ⚠️ trong `InputProcessor.usesNFCForFocusedField`), nên test này KHÔNG
  /// chứng minh Chromium xoá theo scalar — nó chỉ chứng minh: *nếu* field xoá
  /// theo scalar thì trục diff phải là NFD. Mô hình còn lại (backspace xoá cả
  /// cụm grapheme — app native NFC như Notes/Telegram/ChatGPT) nằm ở
  /// `testNFCGraphemeFieldReplayKeepsLeadingConsonant` ngay bên dưới. Hai test
  /// là hai NỬA của cùng một bất biến "đơn vị xoá của field == trục diff", và
  /// phải luôn đi thành cặp; sửa một cái mà không sửa cái kia là dấu hiệu ai đó
  /// vừa lẫn hai mô hình với nhau.
  func testNFDFieldReplayKeepsLeadingConsonant() throws {
    let engine = Telex()
    // (keys Telex, kết quả kỳ vọng) — mỗi từ 1 phụ âm đầu + nguyên âm mang dấu.
    let cases: [(String, String)] = [
      ("guiwr", "gửi"),
      ("suawr", "sửa"),
      ("nooij", "nội"),
      ("looix", "lỗi"),
      ("maast", "mất"),
    ]

    func replayNFDField(states: [String], normalizeToNFC: Bool) -> String {
      var fieldScalars: [Unicode.Scalar] = []
      var prev = ""
      for s in states {
        let (bs, diff) = EventSimulator.calcKeyStrokesNFD(from: prev, to: s)
        fieldScalars.removeLast(min(bs, fieldScalars.count))
        let emit = EventSimulator.emittedCharacters(diff, normalizeToNFC: normalizeToNFC)
        fieldScalars.append(contentsOf: String(emit).unicodeScalars)
        prev = s
      }
      return String(String.UnicodeScalarView(fieldScalars))
        .precomposedStringWithCanonicalMapping
    }

    for (keys, expected) in cases {
      var buffer = WordBuffer()
      var states: [String] = []
      for c in keys {
        buffer.push(char: c, engine: engine)
        states.append(buffer.transformed)
      }
      XCTAssertEqual(
        states.last?.precomposedStringWithCanonicalMapping, expected,
        "Sanity: engine gõ '\(keys)' phải ra '\(expected)'")

      // Fix 4.15: field NFD nhận emit NFD → dựng đúng, giữ phụ âm đầu.
      XCTAssertEqual(
        replayNFDField(states: states, normalizeToNFC: false), expected,
        "Emit NFD vào field NFD phải dựng đúng '\(expected)'")

      // Tài liệu hoá regression 4.14: emit NFC vào field NFD → rụng phụ âm đầu.
      XCTAssertNotEqual(
        replayNFDField(states: states, normalizeToNFC: true), expected,
        "Emit NFC vào field NFD rụng chữ đầu (bug 4.14) — không được để tái diễn")
    }
  }

  /// NỬA CÒN LẠI của `testNFDFieldReplayKeepsLeadingConsonant`: mô hình field
  /// xoá theo CỤM GRAPHEME (app native lưu NFC — Notes, Telegram, ChatGPT,
  /// Gemini). Ở đây `field.removeLast(bs)` bỏ nguyên một `Character`, nên
  /// backspace đếm theo scalar (NFD) sẽ xoá LỐ: đúng bug "điều"→"đều" và
  /// "gửi"→"ửi" đã gặp trên Telegram.
  ///
  /// Hai test cạnh nhau làm cho cả hai mô hình hiện diện tường minh, và cho
  /// thấy bất biến thật không phải "NFC tốt hơn NFD" mà là: TRỤC ĐẾM BACKSPACE
  /// PHẢI TRÙNG ĐƠN VỊ XOÁ CỦA FIELD. Trục nào đúng cho app nào là câu hỏi đo
  /// đạc riêng — hai test này chỉ khoá phần số học, không khẳng định thay
  /// `usesNFCForFocusedField`.
  func testNFCGraphemeFieldReplayKeepsLeadingConsonant() throws {
    let engine = Telex()
    let cases: [(String, String)] = [
      ("guiwr", "gửi"),
      ("suawr", "sửa"),
      ("nooij", "nội"),
      ("looix", "lỗi"),
      ("maast", "mất"),
      // Ca Telegram/ChatGPT gốc: đếm scalar làm mất chữ "i" giữa từ.
      ("ddieeuf", "điều"),
    ]

    // Field lưu grapheme: 1 backspace = 1 `Character`, emit luôn precompose.
    func replayGraphemeField(states: [String], useNFDDiff: Bool) -> String {
      var field: [Character] = []
      var prev = ""
      for s in states {
        let (bs, diff) = useNFDDiff
          ? EventSimulator.calcKeyStrokesNFD(from: prev, to: s)
          : EventSimulator.calcKeyStrokes(from: prev, to: s)
        field.removeLast(min(bs, field.count))
        field.append(contentsOf: EventSimulator.emittedCharacters(diff, normalizeToNFC: true))
        prev = s
      }
      return String(field).precomposedStringWithCanonicalMapping
    }

    for (keys, expected) in cases {
      var buffer = WordBuffer()
      var states: [String] = []
      for c in keys {
        buffer.push(char: c, engine: engine)
        states.append(buffer.transformed)
      }
      XCTAssertEqual(
        states.last?.precomposedStringWithCanonicalMapping, expected,
        "Sanity: engine gõ '\(keys)' phải ra '\(expected)'")

      XCTAssertEqual(
        replayGraphemeField(states: states, useNFDDiff: false), expected,
        "Field xoá-grapheme + diff NFC phải dựng đúng '\(expected)'")

      XCTAssertNotEqual(
        replayGraphemeField(states: states, useNFDDiff: true), expected,
        "Diff NFD vào field xoá-grapheme xoá lố → mất chữ ('điều'→'đều')")
    }
  }

  /// Regression 4.13: "list" đã gỡ khỏi instant-restore ("lít" là từ VN phổ
  /// biến, kết bằng 't' nên guard phím-tone không cover). Escape hatch cho
  /// EN: "lisst" (double-s). Cặp legacy "tê"→"tee" không còn restore ở
  /// commit (gõ "tê tay" + Space từng thành "tee tay"); "ò"→"of" 1 ký tự
  /// giữ nguyên.
  func testLitNotHijackedAndLegacyTeKeptVietnamese() throws {
    XCTAssertEqual(transform_text_telex(for: "list"), "lít")
    XCTAssertEqual(transform_text_telex(for: "lits"), "lít")
    XCTAssertEqual(transform_text_telex(for: "lisst"), "list")

    XCTAssertFalse(
      LexiconManager.shared.shouldApplyLegacyRestore(transformed: "tê", rawInput: "tee")
    )
    XCTAssertTrue(
      LexiconManager.shared.shouldApplyLegacyRestore(transformed: "ò", rawInput: "of")
    )

    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldPolicy = Defaults[.restorePolicy]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.restorePolicy] = oldPolicy
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.restorePolicy] = .vietnameseFirst

    let engine = SpellDecisionEngine.shared
    XCTAssertEqual(
      engine.evaluate(rawInput: "tee", transformed: "tê", needsRecovery: false),
      .keepVietnamese
    )
    XCTAssertEqual(
      engine.evaluate(rawInput: "of", transformed: "ò", needsRecovery: false),
      .restoreRawEnglish("of")
    )
  }

  /// Regression 4.13: "thi"+s phải ra "thí" — trước đây keys "this" khớp
  /// list instant-restore EN (thêm từ v1.5.0, sót quy tắc dọn v2.8/v2.9)
  /// nên gõ "thí điểm" ra "this điểm". Phím tone hoàn thành từ VN hợp lệ
  /// ≥ 2 ký tự → tiếng Việt thắng instant-restore.
  func testTelexThiNotHijackedByThisInstantRestore() throws {
    XCTAssertEqual(transform_text_telex(for: "this"), "thí")
    XCTAssertEqual(transform_text_telex(for: "THIS"), "THÍ")
    XCTAssertEqual(transform_text_telex(for: "This"), "Thí")
    // Escape hatch giữ nguyên: double-s cancel tone → literal "this".
    XCTAssertEqual(transform_text_telex(for: "thiss"), "this")
    // of/if (từ VN 1 ký tự ò/ì) giữ instant-restore như cũ.
    XCTAssertEqual(transform_text_telex(for: "of"), "of")
    XCTAssertEqual(transform_text_telex(for: "if"), "if")
    // Instant-restore không kết bằng phím tone vẫn hoạt động bình thường.
    XCTAssertEqual(transform_text_telex(for: "google"), "google")
    XCTAssertEqual(transform_text_telex(for: "these"), "these")
    XCTAssertEqual(transform_text_telex(for: "there"), "there")
  }

  // MARK: - Telex: Tricky Words That Previously Had Bugs

  /// Test "xuất" and similar words
  func testTelexXuatFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "xuaats"), "xuất")
    XCTAssertEqual(transform_text_telex(for: "xuaan"), "xuân")
    XCTAssertEqual(transform_text_telex(for: "luaatj"), "luật")
    XCTAssertEqual(transform_text_telex(for: "tuaans"), "tuấn")
  }

  /// Test "được" and similar words
  func testTelexDuocFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "dduowcj"), "được")
    XCTAssertEqual(transform_text_telex(for: "muownj"), "mượn")
    XCTAssertEqual(transform_text_telex(for: "luowts"), "lướt")
    XCTAssertEqual(transform_text_telex(for: "huowng"), "hương")
  }

  /// Test words with "iê"
  func testTelexIeFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "tieengs"), "tiếng")
    XCTAssertEqual(transform_text_telex(for: "bieets"), "biết")
    XCTAssertEqual(transform_text_telex(for: "kieems"), "kiếm")
    XCTAssertEqual(transform_text_telex(for: "ddieenj"), "điện")
  }

  // MARK: - ===========================================
  // MARK: - COMPREHENSIVE VNI TYPING TESTS
  // MARK: - ===========================================

  // MARK: - VNI: Basic Tone Marks (1, 2, 3, 4, 5)

  /// Test all 5 tone marks with single vowel 'a'
  func testVNIToneMarksOnA() throws {
    XCTAssertEqual(transform_text_vni(for: "a1"), "á")   // sắc
    XCTAssertEqual(transform_text_vni(for: "a2"), "à")   // huyền
    XCTAssertEqual(transform_text_vni(for: "a3"), "ả")   // hỏi
    XCTAssertEqual(transform_text_vni(for: "a4"), "ã")   // ngã
    XCTAssertEqual(transform_text_vni(for: "a5"), "ạ")   // nặng
  }

  /// Test tone marks with common words
  func testVNIToneMarksInWords() throws {
    XCTAssertEqual(transform_text_vni(for: "ma1"), "má")
    XCTAssertEqual(transform_text_vni(for: "ma2"), "mà")
    XCTAssertEqual(transform_text_vni(for: "ma3"), "mả")
    XCTAssertEqual(transform_text_vni(for: "ma4"), "mã")
    XCTAssertEqual(transform_text_vni(for: "ma5"), "mạ")
  }

  // MARK: - VNI: Diacritical Marks (6, 7, 8)

  /// Test circumflex (mũ) mark: 6 for a, e, o → â, ê, ô
  func testVNICircumflex() throws {
    XCTAssertEqual(transform_text_vni(for: "ca6n"), "cân")
    XCTAssertEqual(transform_text_vni(for: "be6n"), "bên")
    XCTAssertEqual(transform_text_vni(for: "to6i"), "tôi")
  }

  /// Test horn (móc) mark: 7 for u, o → ư, ơ
  func testVNIHorn() throws {
    XCTAssertEqual(transform_text_vni(for: "o7i"), "ơi")
    XCTAssertEqual(transform_text_vni(for: "u7a"), "ưa")
    XCTAssertEqual(transform_text_vni(for: "mu7"), "mư")
    XCTAssertEqual(transform_text_vni(for: "mo7"), "mơ")
  }

  /// Test breve (trăng) mark: 8 for a → ă
  func testVNIBreve() throws {
    XCTAssertEqual(transform_text_vni(for: "a8n"), "ăn")
    XCTAssertEqual(transform_text_vni(for: "ta8m1"), "tắm")
  }

  // MARK: - VNI: Đ Character (d9)

  /// Test d9→đ
  func testVNIStrokedD() throws {
    XCTAssertEqual(transform_text_vni(for: "d9i"), "đi")
    XCTAssertEqual(transform_text_vni(for: "d9uo7c5"), "được")
    XCTAssertEqual(transform_text_vni(for: "d9a1ng"), "đáng")
  }

  /// Test that d9 only toggles đ immediately after an initial d.
  func testVNIStrokedDOnlyAtInitialD9() throws {
    XCTAssertEqual(transform_text_vni(for: "d9uo7ng2"), "đường")
    XCTAssertEqual(transform_text_vni(for: "da9"), "đa")
  }

  // MARK: - VNI: Combined Diacritics and Tones

  /// Test combinations of circumflex + tone
  func testVNICircumflexWithTone() throws {
    XCTAssertEqual(transform_text_vni(for: "ca62n"), "cần")
    XCTAssertEqual(transform_text_vni(for: "ta61t"), "tất")
    XCTAssertEqual(transform_text_vni(for: "be63n"), "bển")
    XCTAssertEqual(transform_text_vni(for: "to64i"), "tỗi")
    XCTAssertEqual(transform_text_vni(for: "to65i"), "tội")
  }

  /// Test combinations of horn + tone
  func testVNIHornWithTone() throws {
    XCTAssertEqual(transform_text_vni(for: "mo74"), "mỡ")
    XCTAssertEqual(transform_text_vni(for: "mu71"), "mứ")
    XCTAssertEqual(transform_text_vni(for: "tuo71i"), "tưới")
  }

  /// Test combinations of breve + tone
  func testVNIBreveWithTone() throws {
    XCTAssertEqual(transform_text_vni(for: "a8n1"), "ắn")
    XCTAssertEqual(transform_text_vni(for: "ta82m"), "tằm")
    XCTAssertEqual(transform_text_vni(for: "ba8ng5"), "bặng")
  }

  // MARK: - VNI: Special Consonant Clusters

  /// Test "gi" special case
  func testVNIGiCases() throws {
    XCTAssertEqual(transform_text_vni(for: "gi1"), "gí")
    XCTAssertEqual(transform_text_vni(for: "gi2"), "gì")
    XCTAssertEqual(transform_text_vni(for: "gia1"), "giá")
  }

  /// Test "qu" consonant cluster
  func testVNIQuCases() throws {
    XCTAssertEqual(transform_text_vni(for: "qua"), "qua")
    XCTAssertEqual(transform_text_vni(for: "qua1"), "quá")
    XCTAssertEqual(transform_text_vni(for: "qua61n"), "quấn")
  }

  /// Test "ngh" consonant cluster
  func testVNINghCases() throws {
    XCTAssertEqual(transform_text_vni(for: "nghi2"), "nghì")
    XCTAssertEqual(transform_text_vni(for: "nghe62"), "nghề")
  }

  // MARK: - VNI: Common Vietnamese Words

  /// Test frequently used Vietnamese words
  func testVNICommonWords() throws {
    XCTAssertEqual(transform_text_vni(for: "xin"), "xin")
    XCTAssertEqual(transform_text_vni(for: "cha2o"), "chào")
    XCTAssertEqual(transform_text_vni(for: "ca3m"), "cảm")
    XCTAssertEqual(transform_text_vni(for: "o7n"), "ơn")
    XCTAssertEqual(transform_text_vni(for: "vie65t"), "việt")
    XCTAssertEqual(transform_text_vni(for: "nam"), "nam")
  }

  /// Test more complex words in VNI
  func testVNIComplexWords() throws {
    XCTAssertEqual(transform_text_vni(for: "nguo7i2"), "người")
    XCTAssertEqual(transform_text_vni(for: "d9uo7ng2"), "đường")
    XCTAssertEqual(transform_text_vni(for: "chuo7ng"), "chương")
    XCTAssertEqual(transform_text_vni(for: "tri2nh"), "trình")
  }

  // MARK: - VNI: Toggle Behavior (Double Typing)

  /// Test tone toggle in VNI (typing same tone key twice removes it)
  func testVNIToneToggle() throws {
    XCTAssertEqual(transform_text_vni(for: "a11"), "a1")
    XCTAssertEqual(transform_text_vni(for: "a22"), "a2")
    XCTAssertEqual(transform_text_vni(for: "a33"), "a3")
    XCTAssertEqual(transform_text_vni(for: "a44"), "a4")
    XCTAssertEqual(transform_text_vni(for: "a55"), "a5")
  }

  /// Test circumflex toggle
  func testVNICircumflexToggle() throws {
    XCTAssertEqual(transform_text_vni(for: "a66"), "a6")
    XCTAssertEqual(transform_text_vni(for: "o66"), "o6")
    XCTAssertEqual(transform_text_vni(for: "e66"), "e6")
  }

  /// Test breve toggle
  func testVNIBreveToggle() throws {
    XCTAssertEqual(transform_text_vni(for: "a88"), "a8")
  }

  /// Test d9 toggle
  func testVNIDToggle() throws {
    XCTAssertEqual(transform_text_vni(for: "d99"), "d9")
  }

  // MARK: - VNI: Recovery Cases (Invalid Vietnamese)

  /// Test invalid vowel combinations trigger recovery
  func testVNIInvalidVowelRecovery() throws {
    XCTAssertEqual(transform_text_vni(for: "ae1"), "ae1")
    XCTAssertEqual(transform_text_vni(for: "ea1"), "ea1")
    XCTAssertEqual(transform_text_vni(for: "yi1"), "yi1")
  }

  /// Test invalid final consonant triggers recovery
  func testVNIInvalidFinalConsonantRecovery() throws {
    XCTAssertEqual(transform_text_vni(for: "aim1"), "aim1")
    XCTAssertEqual(transform_text_vni(for: "aotn"), "aotn")
  }

  // MARK: - VNI: Edge Cases

  /// Test single vowels with tone
  func testVNISingleVowels() throws {
    XCTAssertEqual(transform_text_vni(for: "a1"), "á")
    XCTAssertEqual(transform_text_vni(for: "e1"), "é")
    XCTAssertEqual(transform_text_vni(for: "i1"), "í")
    XCTAssertEqual(transform_text_vni(for: "o1"), "ó")
    XCTAssertEqual(transform_text_vni(for: "u1"), "ú")
    XCTAssertEqual(transform_text_vni(for: "y1"), "ý")
  }

  /// Test words ending with valid consonants
  func testVNIValidFinalConsonants() throws {
    XCTAssertEqual(transform_text_vni(for: "a1c"), "ác")   // -c
    XCTAssertEqual(transform_text_vni(for: "a5ch"), "ạch") // -ch
    XCTAssertEqual(transform_text_vni(for: "a1m"), "ám")   // -m
    XCTAssertEqual(transform_text_vni(for: "a2n"), "àn")   // -n
    XCTAssertEqual(transform_text_vni(for: "a2ng"), "àng") // -ng
    XCTAssertEqual(transform_text_vni(for: "a2nh"), "ành") // -nh
    XCTAssertEqual(transform_text_vni(for: "a1p"), "áp")   // -p
    XCTAssertEqual(transform_text_vni(for: "a1t"), "át")   // -t
  }

  /// Test uppercase handling
  func testVNIUppercase() throws {
    XCTAssertEqual(transform_text_vni(for: "VIE65T"), "VIỆT")
    XCTAssertEqual(transform_text_vni(for: "NAM"), "NAM")
  }

  // MARK: - VNI: Tricky Words

  /// Test "xuất" and similar words in VNI
  func testVNIXuatFamily() throws {
    XCTAssertEqual(transform_text_vni(for: "xua61t"), "xuất")
    XCTAssertEqual(transform_text_vni(for: "xua6n"), "xuân")
    XCTAssertEqual(transform_text_vni(for: "lua65t"), "luật")
  }

  /// Test "được" and similar words in VNI
  func testVNIDuocFamily() throws {
    XCTAssertEqual(transform_text_vni(for: "d9uo7c5"), "được")
    XCTAssertEqual(transform_text_vni(for: "muo7n5"), "mượn")
    XCTAssertEqual(transform_text_vni(for: "huo7ng"), "hương")
  }

  // MARK: - GoNhanh Engine Innovations Tests

  func testGoNhanhEngineInnovations() throws {
    let oldPolicy = Defaults[.restorePolicy]
    Defaults[.restorePolicy] = .balanced
    defer {
      Defaults[.restorePolicy] = oldPolicy
    }

    // 1. Inclusion Vowel Pairs Matrix (VALID_VOWEL_PAIRS)
    // English words should not get transformed or recovered improperly
    XCTAssertEqual(transform_text_telex(for: "claus"), "claus")
    XCTAssertEqual(transform_text_telex(for: "beyond"), "beyond")
    XCTAssertEqual(transform_text_telex(for: "house"), "house")
    XCTAssertEqual(transform_text_telex(for: "metric"), "metric")
    
    // Ethnic minority names support
    XCTAssertEqual(transform_text_telex(for: "krong"), "krong") // kr initials
    XCTAssertEqual(transform_text_vni(for: "d9ak1"), "đắk") // k final consonant
    
    // 2. Doubled Tone Mark Preservation
    // 1.7.5: tone-cancel có priority hơn doubled-tone preservation. "off"
    // vẫn pass do "of" được lexicon nhận diện sớm ở line 286 (lock raw
    // trước khi second f tới). "class" và "staff" cũng pass vì prefix
    // "cl"/"st" là impossible-cluster → vào path raw từ sớm.
    // 4.14: "pass" hết trade-off "pas" — cancel dấu + keys ≥ 4 phím khớp
    // instant-restore EN → khoá raw đầy đủ (xem testDoubledToneEnglishWordsKeptFull).
    XCTAssertEqual(transform_text_telex(for: "off"), "off")
    XCTAssertEqual(transform_text_telex(for: "class"), "class")
    XCTAssertEqual(transform_text_telex(for: "pass"), "pass")
    XCTAssertEqual(transform_text_telex(for: "staff"), "staff")
  }

  // MARK: - ===========================================
  // MARK: - STATE MUTATION TESTS
  // MARK: - ===========================================

  // MARK: - State: Parse Correctness

  /// Test parsing of syllable components
  func testStateParsing() throws {
    // Test initial consonant parsing
    let state1 = TiengVietState.empty.push("t").push("h").push("a")
    XCTAssertEqual(String(state1.thanhPhanTieng.phuAmDau), "th")
    XCTAssertEqual(String(state1.thanhPhanTieng.nguyenAm), "a")

    // Test final consonant parsing
    let state2 = TiengVietState.empty.push("a").push("n").push("h")
    XCTAssertEqual(String(state2.thanhPhanTieng.nguyenAm), "a")
    XCTAssertEqual(String(state2.thanhPhanTieng.phuAmCuoi), "nh")

    // Test complex syllable
    let state3 = TiengVietState.empty.push("n").push("g").push("h").push("i").push("e").push("n").push("g")
    XCTAssertEqual(String(state3.thanhPhanTieng.phuAmDau), "ngh")
    XCTAssertEqual(String(state3.thanhPhanTieng.nguyenAm), "ie")
    XCTAssertEqual(String(state3.thanhPhanTieng.phuAmCuoi), "ng")
  }

  /// Test tone mark placement
  func testStateTonePlacement() throws {
    // Single vowel: tone on that vowel
    let state1 = TiengVietState.empty.push("m").push("a").withTone(.sac)
    XCTAssertEqual(state1.transformed, "má")

    // Multiple vowels: tone on correct position
    let state2 = TiengVietState.empty.push("t").push("o").push("a").push("n").withTone(.sac)
    XCTAssertEqual(state2.transformed, "toán")

    // ươ combination
    let state3 = TiengVietState.empty.push("t").push("u").push("o").push("i").withMu(.muMoc).withTone(.sac)
    XCTAssertEqual(state3.transformed, "tưới")
  }

  // MARK: - State: Chaining Operations

  /// Test chaining multiple state operations
  func testStateChaining() throws {
    let state = TiengVietState.empty
      .push("t").push("i").push("e").push("n").push("g")
      .withMu(.muUp)
      .withTone(.sac)
    XCTAssertEqual(state.transformed, "tiếng")
  }

  /// Test pop operation resets correctly
  func testStatePopReset() throws {
    let state1 = TiengVietState.empty.push("m").push("a").withTone(.sac)
    let state2 = state1.pop() // remove 'a'
    XCTAssertEqual(state2.transformed, "m")
    XCTAssertEqual(state2.dauThanh, .bang) // tone should be reset when vowel removed
  }

  // MARK: - ===========================================
  // MARK: - REGRESSION TESTS
  // MARK: - ===========================================

  /// Test case: typing common greeting
  func testRegressionXinChao() throws {
    XCTAssertEqual(transform_text_telex(for: "xin chaof"), "xin chào")
    XCTAssertEqual(transform_text_vni(for: "xin cha2o"), "xin chào")
  }

  /// Test case: typing "tất cả"
  func testRegressionTatCa() throws {
    XCTAssertEqual(transform_text_telex(for: "taats car"), "tất cả")
    XCTAssertEqual(transform_text_vni(for: "ta61t ca3"), "tất cả")
  }

  /// Test case: typing "các bạn"
  func testRegressionCacBan() throws {
    XCTAssertEqual(transform_text_telex(for: "cacs banj"), "các bạn")
    XCTAssertEqual(transform_text_vni(for: "ca1c ba5n"), "các bạn")
  }

  /// Test case: typing "không" - multiple valid approaches
  func testRegressionKhong() throws {
    XCTAssertEqual(transform_text_telex(for: "khoong"), "không")  // oo=ô, no tone = ngang
    XCTAssertEqual(transform_text_vni(for: "kho6ng"), "không")
  }

  /// Test case: sentences with mixed content
  func testRegressionMixedSentence() throws {
    let telex = transform_text_telex(for: "toi yeeu vieejt nam")
    XCTAssertEqual(telex, "toi yêu việt nam")

    let vni = transform_text_vni(for: "toi ye6u vie65t nam")
    XCTAssertEqual(vni, "toi yêu việt nam")
  }

  func testOldStylePlacement() throws {
    try withTonePlacement(false) {
      XCTAssertEqual(transform_text_telex(for: "hoaf"), "hòa")
      XCTAssertEqual(transform_text_telex(for: "thuyr"), "thủy")
      XCTAssertEqual(transform_text_telex(for: "khoer"), "khỏe")
    }
  }
  
  func testNewStylePlacement() throws {
    try withTonePlacement(true) {
      XCTAssertEqual(transform_text_telex(for: "hoaf"), "hoà")
      XCTAssertEqual(transform_text_telex(for: "thuyr"), "thuỷ")
      XCTAssertEqual(transform_text_telex(for: "khoer"), "khoẻ")
    }
  }

  func testReviewedTypoCorrectionRegressions() throws {
    XCTAssertEqual(transform_text_telex(for: "tuyetj"), "tuyệt")
    XCTAssertEqual(transform_text_telex(for: "veeitj"), "việt")
    XCTAssertEqual(transform_text_telex(for: "phuowgn"), "phương")
    XCTAssertEqual(transform_text_telex(for: "phuwowgn"), "phương")  // Second w preserves horn on uo pattern
  }

  func testNewTypoCorrections() throws {
    // Rule 1: "ou" -> "uo"
    XCTAssertEqual(transform_text_telex(for: "bouts"), "buót")
    XCTAssertEqual(transform_text_telex(for: "boutos"), "buốt")
    XCTAssertEqual(transform_text_vni(for: "bout1"), "buót")
    XCTAssertEqual(transform_text_vni(for: "bout61"), "buốt")
    
    // Rule 2: "aoi" -> "oai"
    XCTAssertEqual(transform_text_telex(for: "haois"), "hoái")
    XCTAssertEqual(transform_text_vni(for: "haoi1"), "hoái")
    
    // Rule 3: "ao" + final consonant -> "oa" + final consonant
    XCTAssertEqual(transform_text_telex(for: "haocj"), "hoạc")
    XCTAssertEqual(transform_text_telex(for: "haong"), "hoang")
    XCTAssertEqual(transform_text_telex(for: "haongf"), "hoàng")
    XCTAssertEqual(transform_text_vni(for: "haoc5"), "hoạc")
    
    // Guarantee that standard "ao" words with no final consonant are preserved
    XCTAssertEqual(transform_text_telex(for: "baos"), "báo")
    XCTAssertEqual(transform_text_telex(for: "caof"), "cào")
  }

  func testReviewedTypoCorrectionParsing() throws {
    let swappedEi = TiengVietParser.parse(Array("veit"))
    XCTAssertEqual(String(swappedEi.nguyenAm), "ie")
    XCTAssertEqual(String(swappedEi.phuAmCuoi), "t")
    XCTAssertTrue(swappedEi.conLai.isEmpty)

    let swappedGn = TiengVietParser.parse(Array("phuogn"))
    XCTAssertEqual(String(swappedGn.nguyenAm), "uo")
    XCTAssertEqual(String(swappedGn.phuAmCuoi), "ng")
    XCTAssertTrue(swappedGn.conLai.isEmpty)

    let swappedOu = TiengVietParser.parse(Array("bou"))
    XCTAssertEqual(String(swappedOu.nguyenAm), "uo")
    XCTAssertTrue(swappedOu.conLai.isEmpty)

    let swappedAoi = TiengVietParser.parse(Array("haoi"))
    XCTAssertEqual(String(swappedAoi.nguyenAm), "oai")
    XCTAssertTrue(swappedAoi.conLai.isEmpty)

    let swappedAoFinal = TiengVietParser.parse(Array("haoc"))
    XCTAssertEqual(String(swappedAoFinal.nguyenAm), "oa")
    XCTAssertEqual(String(swappedAoFinal.phuAmCuoi), "c")
    XCTAssertTrue(swappedAoFinal.conLai.isEmpty)
  }

  /// Regression: gõ 2 âm tiết "DaoTao" bị đảo nhầm "ao"→"oa" thành "DoaTao".
  /// Rule "ao" + phụ âm cuối chỉ được swap khi reparse tiêu hoá HẾT (conLai rỗng);
  /// ở đây "tao" là âm tiết MỚI (còn "ao" dư trong conLai) nên KHÔNG được đảo
  /// âm tiết "Dao".
  func testAoSwapNotAppliedAcrossSyllableBoundary() throws {
    // Repro chính (camelCase): gõ "DaoTao" phải giữ nguyên, KHÔNG thành "DoaTao".
    // Ở bước gõ tới "DaoT", phụ âm cuối 'T' viết HOA sau nguyên âm "ao" viết
    // thường = ranh giới âm tiết mới → không được đảo "ao"→"oa".
    XCTAssertEqual(transform_text_telex(for: "DaoTao"), "DaoTao")
    XCTAssertEqual(transform_text_telex(for: "BaoCao"), "BaoCao")

    // Cấp parser: cả cụm "daotao" (âm tiết 'tao' làm conLai dư) không được đảo.
    XCTAssertEqual(String(TiengVietParser.parse(Array("daotao")).nguyenAm), "ao",
      "‘daotao’ (2 âm tiết) không được đảo ‘ao’→‘oa’")

    // Regression: "ao" + phụ âm cuối hợp lệ (toàn chữ thường, conLai rỗng) VẪN đảo đúng.
    XCTAssertEqual(transform_text_telex(for: "haong"), "hoang")
    XCTAssertEqual(transform_text_telex(for: "haocj"), "hoạc")
    XCTAssertEqual(transform_text_telex(for: "baos"), "báo")
  }

  /// v4.6 Regression: bug "gõ DaoTao, ấn space → DaoTaao" khi bật **Free Mark Mode**.
  /// Free Mark Mode nuốt recovery ⇒ engine bịa dấu ("DaoTa"→"DaôT") rồi phát
  /// replacement (xoá+gõ lại dấu đa-scalar, gửi bất đồng bộ) → hỏng hiển thị ở
  /// mọi app. Fix: input có ranh giới hoa/thường giữa từ (camelCase) vẫn recover
  /// về raw ngay cả khi Free Mark Mode bật.
  func testFreeMarkModeKeepsCamelCaseWords() throws {
    let old = Defaults[.freeMarkModeEnabled]
    Defaults[.freeMarkModeEnabled] = true
    defer { Defaults[.freeMarkModeEnabled] = old }

    // camelCase phải giữ nguyên (không bịa dấu) kể cả khi Free Mark Mode bật.
    XCTAssertEqual(transform_text_telex(for: "DaoTao"), "DaoTao")
    XCTAssertEqual(transform_text_telex(for: "BaoCao"), "BaoCao")
    // v4.7: từ thường nhiều âm tiết (loanword/English) cũng phải recover về raw —
    // trước đây bị bịa dấu: banana→"bânna", cooperate→"côperate", area→"ảea".
    XCTAssertEqual(transform_text_telex(for: "banana"), "banana")
    XCTAssertEqual(transform_text_telex(for: "cooperate"), "cooperate")
    XCTAssertEqual(transform_text_telex(for: "coordinate"), "coordinate")
    XCTAssertEqual(transform_text_telex(for: "area"), "area")
    XCTAssertEqual(transform_text_telex(for: "kangaroo"), "kangaroo")
    // Free Mark Mode KHÔNG đụng từ tiếng Việt hợp lệ / âm tiết đơn.
    XCTAssertEqual(transform_text_telex(for: "tieengs"), "tiếng")
    XCTAssertEqual(transform_text_telex(for: "xin"), "xin")
  }

  /// v4.7 Regression: viết hoa đầu câu KHÔNG được "rò" qua thao tác dời con trỏ.
  /// Sau ". " (đầu câu), nếu user dời con trỏ (mũi tên/Esc/click/Cmd) rồi gõ chữ
  /// thường ở vị trí mới thì chữ đó KHÔNG được viết hoa nhầm ("sviet"→"Sviet").
  func testAutoCapitalizeClearedOnCaretJump() throws {
    let old = Defaults[.autoCapitalizeEnabled]
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults[.autoCapitalizeEnabled] = old }
    func key(_ p: InputProcessor, _ code: UInt16) {
      let ev = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
      _ = p.handleEvent(event: ev)
    }
    // Gõ "a. " → pendingCapitalize = true; rồi <jump>; rồi 's'.
    func typeThenJump(_ jumpCode: UInt16) -> String {
      let p = InputProcessor(method: .Telex)
      key(p, 0); key(p, 47); key(p, 49)   // a . <space>
      key(p, jumpCode)                     // dời con trỏ
      key(p, 1)                            // s
      return p.transformed
    }
    XCTAssertEqual(typeThenJump(123), "s", "Sau mũi tên trái, 's' không được viết hoa")
    XCTAssertEqual(typeThenJump(53), "s", "Sau Escape, 's' không được viết hoa")

    // Kiểm soát: KHÔNG dời con trỏ thì đầu câu VẪN viết hoa (tính năng còn nguyên).
    let p = InputProcessor(method: .Telex)
    key(p, 0); key(p, 47); key(p, 49)      // a . <space>
    key(p, 1)                              // s (ngay đầu câu)
    XCTAssertEqual(p.transformed, "S", "Đầu câu (không dời con trỏ) phải viết hoa")
  }

  // MARK: - E1: luật auto-ă cho "a…k" chỉ áp cho địa danh d/đ/l (Đắk/Lắk)

  func testAutoBreveAkRestrictedToPlaceNameInitials() throws {
    // Giữ tính năng: phụ âm đầu d/l → vẫn thêm ă (Đắk Lắk).
    XCTAssertEqual(transform_text_telex(for: "dak"), "dăk")
    XCTAssertEqual(transform_text_telex(for: "lak"), "lăk")
    // Fix: phụ âm đầu khác / không có → KHÔNG thêm ă (tránh phá tên/loanword).
    XCTAssertEqual(transform_text_telex(for: "ak"), "ak")     // AK-47
    XCTAssertEqual(transform_text_telex(for: "tak"), "tak")
    XCTAssertEqual(transform_text_telex(for: "mak"), "mak")
    XCTAssertEqual(transform_text_telex(for: "nak"), "nak")
  }

  // MARK: - P1: lọc pasteboard bí mật (mật khẩu) khỏi clipboard history

  @MainActor
  func testClipboardSkipsConcealedPasteboardType() throws {
    let concealed = NSPasteboardItem()
    concealed.setString("hunter2", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    XCTAssertTrue(ClipboardHistoryService.containsSecretPasteboardType([concealed]))

    let normal = NSPasteboardItem()
    normal.setString("xin chào", forType: .string)
    XCTAssertFalse(ClipboardHistoryService.containsSecretPasteboardType([normal]))
  }

  // MARK: - L1: verify chữ ký Ed25519 gói từ điển

  func testLexiconSignatureVerifier() throws {
    let vi = ["và", "của"], en = ["the"], keep = ["an"]
    func pkg(vietnamese: [String], sig: String?) -> LexiconUpdatePackage {
      LexiconUpdatePackage(version: 2, vietnamese: vietnamese, english: en, keep: keep,
                           enVnMapping: nil, vnEnMapping: nil, macrosRecommended: nil,
                           meta: nil, signature: sig)
    }
    let key = Curve25519.Signing.PrivateKey()
    let pubB64 = key.publicKey.rawRepresentation.base64EncodedString()
    let base = pkg(vietnamese: vi, sig: nil)
    let sig = try key.signature(for: LexiconSignatureVerifier.canonicalPayload(for: base))
    let signed = pkg(vietnamese: vi, sig: sig.base64EncodedString())

    // Public key rỗng = verify TẮT → luôn chấp nhận (không phá kênh update hiện tại).
    XCTAssertTrue(LexiconSignatureVerifier.verify(package: signed, publicKeyBase64: ""))
    // Đã cấu hình key: chữ ký hợp lệ → chấp nhận.
    XCTAssertTrue(LexiconSignatureVerifier.verify(package: signed, publicKeyBase64: pubB64))
    // Nội dung bị sửa (thêm từ) → chữ ký cũ không còn khớp → từ chối.
    let tampered = pkg(vietnamese: vi + ["HACKED"], sig: sig.base64EncodedString())
    XCTAssertFalse(LexiconSignatureVerifier.verify(package: tampered, publicKeyBase64: pubB64))
    // Thiếu chữ ký khi đã bật verify → từ chối.
    XCTAssertFalse(LexiconSignatureVerifier.verify(package: base, publicKeyBase64: pubB64))
  }

  /// L1 (fix #1): chữ ký phải phủ CẢ en_vn/vn_en mapping và macros — sửa riêng
  /// một trong các trường này (giữ nguyên word-list) vẫn phải bị phát hiện.
  func testLexiconSignatureCoversMappingsAndMacros() throws {
    let key = Curve25519.Signing.PrivateKey()
    let pubB64 = key.publicKey.rawRepresentation.base64EncodedString()
    func pkg(enVn: [String: [String]]?, macros: [MacroSeed]?, sig: String?) -> LexiconUpdatePackage {
      LexiconUpdatePackage(version: 3, vietnamese: ["và"], english: ["the"], keep: ["an"],
                           enVnMapping: enVn, vnEnMapping: nil, macrosRecommended: macros,
                           meta: nil, signature: sig)
    }
    let enVn = ["hello": ["xin chào"]]
    let macros = [MacroSeed(from: "@@", to: "email@x.com")]
    let base = pkg(enVn: enVn, macros: macros, sig: nil)
    let sig = try key.signature(for: LexiconSignatureVerifier.canonicalPayload(for: base)).base64EncodedString()
    let signed = pkg(enVn: enVn, macros: macros, sig: sig)
    XCTAssertTrue(LexiconSignatureVerifier.verify(package: signed, publicKeyBase64: pubB64))

    // Sửa candidate trong en_vn mapping → chữ ký cũ hết khớp.
    let tamperedMap = pkg(enVn: ["hello": ["HACKED"]], macros: macros, sig: sig)
    XCTAssertFalse(LexiconSignatureVerifier.verify(package: tamperedMap, publicKeyBase64: pubB64))
    // Sửa macro `to` → chữ ký cũ hết khớp.
    let tamperedMacro = pkg(enVn: enVn, macros: [MacroSeed(from: "@@", to: "evil@x.com")], sig: sig)
    XCTAssertFalse(LexiconSignatureVerifier.verify(package: tamperedMacro, publicKeyBase64: pubB64))
  }

  // MARK: - L4: giới hạn cấu trúc gói từ điển

  func testLexiconPackageBoundsValidation() throws {
    func pkg(_ vietnamese: [String] = [],
             enVn: [String: [String]]? = nil,
             macros: [MacroSeed]? = nil) -> LexiconUpdatePackage {
      LexiconUpdatePackage(version: 1, vietnamese: vietnamese, english: [], keep: [],
                           enVnMapping: enVn, vnEnMapping: nil, macrosRecommended: macros,
                           meta: nil, signature: nil)
    }
    XCTAssertNoThrow(try pkg(["và", "của"]).validated())
    XCTAssertThrowsError(try pkg(Array(repeating: "x", count: LexiconUpdatePackage.maxEntries + 1)).validated())
    let longWord = String(repeating: "a", count: LexiconUpdatePackage.maxStringLength + 1)
    XCTAssertThrowsError(try pkg([longWord]).validated())

    // Fix #3: mapping candidate quá dài & macro `from` quá dài → chặn; macro `to`
    // (đoạn mở rộng) hợp lệ tới `maxMacroExpansionLength` rồi mới chặn.
    XCTAssertThrowsError(try pkg(enVn: ["k": [longWord]]).validated())
    XCTAssertThrowsError(try pkg(macros: [MacroSeed(from: longWord, to: "x")]).validated())
    XCTAssertNoThrow(try pkg(macros: [MacroSeed(from: "@@", to: String(repeating: "x", count: 1000))]).validated())
    XCTAssertThrowsError(try pkg(macros: [MacroSeed(
      from: "@@",
      to: String(repeating: "x", count: LexiconUpdatePackage.maxMacroExpansionLength + 1))]).validated())
  }

  // MARK: - U3: import thống kê phân biệt null / thiếu / hỏng / hợp lệ

  func testStatisticsImportDistinguishesNullAbsentAndCorrupt() throws {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    func decode(_ json: String) throws -> UserDataExport {
      try dec.decode(UserDataExport.self, from: Data(json.utf8))
    }
    // Khóa không có → statistics nil, không ném.
    XCTAssertNil(try decode(#"{}"#).statistics)
    // JSON null tường minh → coi như "không có", KHÔNG ném (regression guard).
    XCTAssertNil(try decode(#"{"statistics": null}"#).statistics)
    // Có value nhưng sai kiểu (hỏng) → ném lỗi thay vì âm thầm bỏ.
    XCTAssertThrowsError(try decode(#"{"statistics": 42}"#))
    // Có value hợp lệ (mảng rỗng) → decode được.
    XCTAssertEqual(try decode(#"{"statistics": []}"#).statistics?.count, 0)
  }

  /// v2.3.6 — Loanword consonants (w/z/j/f) KHÔNG được áp swap typo-correction.
  /// Bug: gõ "weight" trong ô tìm kiếm → "wieght" vì rule veit→viet swap "ei" → "ie".
  /// Tiếng Việt không có từ bản địa bắt đầu bằng w/z/j/f → mọi từ w-/z-/j-/f- là loanword.
  func testForeignConsonantSkipsVowelSwapTypoCorrection() throws {
    // Setup: bật allowedZWJF để w/z/j/f thành phụ âm đầu (như default).
    let oldPhuAmDau = TiengViet.PhuAmDau
    let oldAllowed = Defaults[.allowedZWJF]
    Defaults[.allowedZWJF] = true
    TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon + TiengViet.PhuAmDonNuocNgoai
    TiengViet.updatePhuAmDauTrie()
    defer {
      Defaults[.allowedZWJF] = oldAllowed
      TiengViet.PhuAmDau = oldPhuAmDau
      TiengViet.updatePhuAmDauTrie()
    }

    // veit→viet rule: KHÔNG fire cho phụ âm đầu loanword.
    // "wei" — nguyenAm phải giữ là "e", "i" ở conLai (raw). KHÔNG được swap thành "ie".
    let wei = TiengVietParser.parse(Array("wei"))
    XCTAssertEqual(String(wei.phuAmDau), "w")
    XCTAssertEqual(String(wei.nguyenAm), "e")
    XCTAssertEqual(String(wei.conLai), "i", "wei phải giữ 'i' ở conLai, không bị swap")

    // "weight" full word — phải giữ raw, output từ transformer = "weight" (qua thanhPhanTieng).
    let weight = TiengVietParser.parse(Array("weight"))
    XCTAssertEqual(String(weight.phuAmDau), "w")
    XCTAssertEqual(String(weight.nguyenAm), "e")
    // "ight" không phải PhuAmCuoi → conLai
    XCTAssertEqual(String(weight.conLai), "ight", "weight phải giữ 'ight' ở conLai, không swap thành 'ieght'")

    // bous→buos rule: KHÔNG fire cho loanword. "four" phải giữ raw.
    let four = TiengVietParser.parse(Array("four"))
    XCTAssertEqual(String(four.phuAmDau), "f")
    XCTAssertEqual(String(four.nguyenAm), "o")
    XCTAssertEqual(String(four.conLai), "ur", "four phải giữ 'ur' ở conLai, không swap thành 'uor'")

    // Regression check: native consonant vẫn fire swap như cũ.
    let veit = TiengVietParser.parse(Array("veit"))
    XCTAssertEqual(String(veit.nguyenAm), "ie", "veit (v native) vẫn swap → viet")
    XCTAssertEqual(String(veit.phuAmCuoi), "t")
  }

  func testAdvancedEarlyTonesAndLateStrokes() throws {
    // 1. Test Misplaced Tone Marks (Early Tone Marks)
    XCTAssertEqual(transform_text_telex(for: "thfi"), "thì")
    XCTAssertEqual(transform_text_telex(for: "thfis"), "thí")
    XCTAssertEqual(transform_text_vni(for: "th2i"), "thì")
    XCTAssertEqual(transform_text_vni(for: "th1i"), "thí")

    // 2. Test Late-Stroke "d" (Telex) & "9" (VNI) to yield "đ"
    XCTAssertEqual(transform_text_telex(for: "dinhjd"), "định")
    XCTAssertEqual(transform_text_vni(for: "dinh59"), "định")
    XCTAssertEqual(transform_text_vni(for: "dinh95"), "định")

    // 2.5 Test Existing Typo Corrections (ei -> ie, gn -> ng)
    XCTAssertEqual(transform_text_telex(for: "veeitj"), "việt")
    XCTAssertEqual(transform_text_telex(for: "phuowgn"), "phương")

    // 2.6 Test transient "g" after a vowel allowing "n" to correct to "ng"
    let processor = InputProcessor(method: .Telex)
    processor.push(char: "p")
    processor.push(char: "h")
    processor.push(char: "u")
    processor.push(char: "o")
    processor.push(char: "w")
    // Now they have typed "phươ"
    processor.push(char: "g")
    // Trailing "g" should not trigger recovery
    XCTAssertFalse(processor.stopProcessing)
    processor.push(char: "n")
    // Corrected to "phương"
    XCTAssertEqual(processor.transformed, "phương")

    // 3. Test autoTypoCorrection user toggle disabled/enabled behavior
    Defaults[.autoTypoCorrection] = false
    XCTAssertEqual(transform_text_telex(for: "thfi"), "thfi")
    XCTAssertEqual(transform_text_telex(for: "dinhjd"), "dinhjd")
    XCTAssertEqual(transform_text_vni(for: "th2i"), "th2i")
    XCTAssertEqual(transform_text_vni(for: "dinh59"), "dinh59")

    // Restore default setting
    Defaults[.autoTypoCorrection] = true
    XCTAssertEqual(transform_text_telex(for: "thfi"), "thì")
    XCTAssertEqual(transform_text_telex(for: "dinhjd"), "định")
  }


  func testBugTesst() throws {
    let inputProcessor = InputProcessor(method: .Telex)
    inputProcessor.push(char: "t")
    inputProcessor.push(char: "e")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.transformed, "té")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.transformed, "tes")
    XCTAssertTrue(inputProcessor.stopProcessing)
    inputProcessor.push(char: "t")
    XCTAssertEqual(inputProcessor.transformed, "test")
  }

  func testBugTesstBackspace() throws {
    let inputProcessor = InputProcessor(method: .Telex)
    inputProcessor.push(char: "t")
    inputProcessor.push(char: "e")
    inputProcessor.push(char: "s")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.transformed, "tes")
    XCTAssertTrue(inputProcessor.stopProcessing)
    inputProcessor.push(char: "t")
    XCTAssertEqual(inputProcessor.transformed, "test")
    
    // Backspace from "test"
    let _ = inputProcessor.pop(usesNFC: inputProcessor.usesNFCForFocusedField())
    XCTAssertEqual(inputProcessor.transformed, "tes")
    XCTAssertTrue(inputProcessor.stopProcessing)
  }

  // MARK: - InputProcessor Recovery Rollback Tests

  func testInputProcessorRecoveryRollback() throws {
    let inputProcessor = InputProcessor(method: .Telex)

    // Type "hồ" (hoof)
    inputProcessor.push(char: "h")
    inputProcessor.push(char: "o")
    inputProcessor.push(char: "o")
    inputProcessor.push(char: "f")
    XCTAssertEqual(inputProcessor.transformed, "hồ")
    XCTAssertFalse(inputProcessor.stopProcessing)

    // Type "z" -> triggers recovery
    inputProcessor.push(char: "z")
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "hoofz")

    // Backspace
    let (numBackspaces, diffChars) = inputProcessor.pop(usesNFC: inputProcessor.usesNFCForFocusedField())

    // "hoofz" and "hồ" share "h"
    // "hoofz" is ["h", "o", "o", "f", "z"] (5 chars)
    // "hồ" is ["h", "ồ"] (2 chars)
    // Common prefix "h" (1 char)
    // Backspaces: 5 - 1 = 4
    XCTAssertEqual(numBackspaces, 4, "numBackspaces should be 4")
    XCTAssertEqual(String(diffChars), "ồ", "diffChars should be ồ")
    XCTAssertEqual(inputProcessor.transformed, "hồ", "transformed should be hồ")
    XCTAssertFalse(inputProcessor.stopProcessing, "stopProcessing should be false")
  }

  func testImpossibleConsonantClustersTelex() throws {
    let oldAllowed = Defaults[.allowedZWJF]
    Defaults[.allowedZWJF] = false
    defer { Defaults[.allowedZWJF] = oldAllowed }

    // 1. Double letter impossible prefixes (e.g. street, plural, class, block)
    XCTAssertEqual(transform_text_telex(for: "street"), "street")
    XCTAssertEqual(transform_text_telex(for: "plural"), "plural")
    XCTAssertEqual(transform_text_telex(for: "clear"), "clear")
    XCTAssertEqual(transform_text_telex(for: "block"), "block")
    XCTAssertEqual(transform_text_telex(for: "fly"), "fly")
    XCTAssertEqual(transform_text_telex(for: "green"), "green")

    // 2. Letters f, j, z starting a word (e.g. fast, jail, zone)
    XCTAssertEqual(transform_text_telex(for: "fast"), "fast")
    XCTAssertEqual(transform_text_telex(for: "jail"), "jail")
    XCTAssertEqual(transform_text_telex(for: "zone"), "zone")

    // 3. Normal Telex words are processed fine (e.g. ddieemr -> điểm, song -> song)
    XCTAssertEqual(transform_text_telex(for: "song"), "song")
    XCTAssertEqual(transform_text_telex(for: "ddieemr"), "điểm")
  }

  func testImpossibleConsonantClustersVni() throws {
    let oldAllowed = Defaults[.allowedZWJF]
    Defaults[.allowedZWJF] = false
    defer { Defaults[.allowedZWJF] = oldAllowed }

    // 1. Double letter impossible prefixes in VNI
    XCTAssertEqual(transform_text_vni(for: "street"), "street")
    XCTAssertEqual(transform_text_vni(for: "plural"), "plural")
    XCTAssertEqual(transform_text_vni(for: "clear"), "clear")

    // 2. Starting letter 'w' is bypassed in VNI (w is impossible in VNI)
    XCTAssertEqual(transform_text_vni(for: "word"), "word")

    // 3. Normal VNI words work fine (e.g. d9ie6m3 -> điểm)
    XCTAssertEqual(transform_text_vni(for: "d9ie6m3"), "điểm")
  }

  func testImpossibleConsonantClusterRollback() throws {
    let inputProcessor = InputProcessor(method: .Telex)
    
    // Type "s" -> valid Vietnamese consonant prefix so far
    inputProcessor.push(char: "s")
    XCTAssertFalse(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "s")
    
    // Type "t" -> "st" becomes an impossible consonant prefix! It enters recovery/bypass
    inputProcessor.push(char: "t")
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "st")
    
    // Type "r" -> still in recovery/bypass
    inputProcessor.push(char: "r")
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "str")
    
    // Press backspace -> rolls back to "st", still in recovery/bypass
    let (bs1, diff1) = inputProcessor.pop(usesNFC: inputProcessor.usesNFCForFocusedField())
    XCTAssertEqual(bs1, 0)
    XCTAssertEqual(diff1, [])
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "st")
    
    // Press backspace again -> rolls back to "s", which is valid, so recovery disarms!
    let (bs2, diff2) = inputProcessor.pop(usesNFC: inputProcessor.usesNFCForFocusedField())
    XCTAssertEqual(bs2, 0)
    XCTAssertEqual(diff2, [])
    XCTAssertFalse(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "s")
  }
}

// MARK: - ===========================================
// MARK: - WordBuffer Tests
// MARK: - ===========================================

/// Tests for the WordBuffer struct that manages the word state during typing.
/// Covers push/pop/newWord lifecycle, recovery rollback, and previous-word restore.
final class WordBufferTests: XCTestCase {

  private func telexEngine() -> TypingMethod { Telex() }

  /// New buffer is blank and not in recovery.
  func testNewBufferIsEmpty() throws {
    let buffer = WordBuffer()
    XCTAssertTrue(buffer.keys.isEmpty)
    XCTAssertTrue(buffer.wordState.isBlank)
    XCTAssertEqual(buffer.transformed, "")
    XCTAssertFalse(buffer.stopProcessing)
    XCTAssertNil(buffer.previousWordState)
  }

  /// push accumulates raw keys and updates transformed.
  func testPushAccumulatesKeysAndTransforms() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chaof" {
      buffer.push(char: char, engine: engine)
    }
    XCTAssertEqual(String(buffer.keys), "chaof")
    XCTAssertEqual(buffer.transformed, "chào")
    XCTAssertFalse(buffer.stopProcessing)
  }

  /// newWord clears all state but keeps engine reusable.
  func testNewWordClearsState() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chaof" { buffer.push(char: char, engine: engine) }
    XCTAssertEqual(buffer.transformed, "chào")

    buffer.newWord()
    XCTAssertTrue(buffer.keys.isEmpty)
    XCTAssertEqual(buffer.transformed, "")
    XCTAssertNil(buffer.previousWordState)
    XCTAssertFalse(buffer.stopProcessing)
  }

  /// newWord(storePrevious: true) preserves the prior word so backspace can restore it.
  func testNewWordStoresPrevious() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chaof" { buffer.push(char: char, engine: engine) }
    let prior = buffer.transformed

    buffer.newWord(storePrevious: true)
    XCTAssertNotNil(buffer.previousWordState, "previousWordState should be retained")
    XCTAssertEqual(buffer.previousWordState?.transformed, prior)
  }

  /// pop on empty buffer with a previous word restores that word.
  func testPopRestoresPreviousWord() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chaof" { buffer.push(char: char, engine: engine) }
    buffer.newWord(storePrevious: true)

    let (backspaces, diff) = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(backspaces, 0, "OS handles the backspace that triggered restore")
    XCTAssertTrue(diff.isEmpty)
    XCTAssertEqual(buffer.transformed, "chào")
    XCTAssertNil(buffer.previousWordState, "previousWordState consumed on restore")
  }

  /// Single-step rollback: after recovery, a backspace returns to the last valid state.
  func testRecoveryRollbackUndoesRecovery() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "hoof" { buffer.push(char: char, engine: engine) }
    XCTAssertEqual(buffer.transformed, "hồ")
    XCTAssertFalse(buffer.stopProcessing)

    // Typing 'z' triggers recovery (invalid Vietnamese syllable continuation).
    buffer.push(char: "z", engine: engine)
    XCTAssertTrue(buffer.stopProcessing)
    XCTAssertEqual(buffer.transformed, "hoofz")

    // First pop should rollback the recovery, restoring "hồ".
    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertFalse(buffer.stopProcessing)
    XCTAssertEqual(buffer.transformed, "hồ")
  }

  /// Pop without prior recovery removes the last character normally.
  func testPopRemovesLastChar() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chao" { buffer.push(char: char, engine: engine) }
    XCTAssertEqual(buffer.transformed, "chao")

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "cha")
    XCTAssertEqual(String(buffer.keys), "cha")
  }
}

// MARK: - ===========================================
// MARK: - KeyboardUS Layout Tests
// MARK: - ===========================================

/// Tests for the US keyboard layout key-code → character mapping.
/// Guards against regressions when adding new layout support (QWERTZ/AZERTY).
final class KeyboardUSTests: XCTestCase {

  func testLetterMappingLowercase() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapText(keyCode: 0, withShift: false), "a")
    XCTAssertEqual(layout.mapText(keyCode: 6, withShift: false), "z")
    XCTAssertEqual(layout.mapText(keyCode: 16, withShift: false), "y")
    XCTAssertEqual(layout.mapText(keyCode: 38, withShift: false), "j")
  }

  func testLetterMappingShifted() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapText(keyCode: 0, withShift: true), "A")
    XCTAssertEqual(layout.mapText(keyCode: 6, withShift: true), "Z")
  }

  func testNumberRowMapping() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapText(keyCode: 18, withShift: false), "1")
    XCTAssertEqual(layout.mapText(keyCode: 18, withShift: true), "!")
    XCTAssertEqual(layout.mapText(keyCode: 29, withShift: false), "0")
    XCTAssertEqual(layout.mapText(keyCode: 29, withShift: true), ")")
  }

  func testPunctuationMapping() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapText(keyCode: 41, withShift: false), ";")
    XCTAssertEqual(layout.mapText(keyCode: 41, withShift: true), ":")
    XCTAssertEqual(layout.mapText(keyCode: 47, withShift: false), ".")
    XCTAssertEqual(layout.mapText(keyCode: 47, withShift: true), ">")
  }

  func testUnknownKeyCodeReturnsNil() throws {
    let layout = KeyboardUS()
    XCTAssertNil(layout.mapText(keyCode: 9999, withShift: false))
  }

  func testTaskKeyMapping() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapTask(keyCode: 36), .Enter)
    XCTAssertEqual(layout.mapTask(keyCode: 48), .Tab)
    XCTAssertEqual(layout.mapTask(keyCode: 49), .Space)
    XCTAssertEqual(layout.mapTask(keyCode: 51), .Delete)
    XCTAssertEqual(layout.mapTask(keyCode: 53), .Escape)
    XCTAssertEqual(layout.mapTask(keyCode: 123), .ArrowLeft)
    XCTAssertEqual(layout.mapTask(keyCode: 126), .ArrowUp)
    XCTAssertEqual(layout.mapTask(keyCode: 122), .F1)
    XCTAssertNil(layout.mapTask(keyCode: 0))
  }

  /// v4.23 (F4): Enter của BÀN PHÍM SỐ là 0x4C = 76 (`kVK_ANSI_KeypadEnter`)
  /// và trước đây KHÔNG có trong `taskMap` — `mapTask` lẫn `mapText` đều nil
  /// nên phím đi qua nguyên trạng: app xuống dòng mà bộ đệm vẫn giữ từ cũ, ký
  /// tự đầu dòng mới diff với `lastTransformed` của dòng trước → backspace phát
  /// NGƯỢC LÊN dòng trên. Mã 52 (0x34) từng được coi là "Enter bàn phím số"
  /// nhưng nó không có trong Events.h (Enter của PowerBook đời cũ) — giữ nhưng
  /// KHÔNG thay thế được 76.
  func testKeypadEnterMapsToEnterTaskKey() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapTask(keyCode: 76), .Enter,
      "0x4C kVK_ANSI_KeypadEnter phải cắt từ như Enter thường")
    XCTAssertNil(layout.mapText(keyCode: 76, withShift: false),
      "Enter bàn phím số không được map thành ký tự văn bản")
    // Hai mã Enter cũ vẫn nguyên vẹn.
    XCTAssertEqual(layout.mapTask(keyCode: 36), .Enter)
    XCTAssertEqual(layout.mapTask(keyCode: 52), .Enter)
  }

  /// v4.23 (F4) + v4.24: Page Up/Down (0x74 = 116, 0x79 = 121) dời con trỏ y hệt
  /// Home/End nên cũng phải cắt từ. `TaskKey` chưa có case riêng nên phải MƯỢN
  /// một case của nhóm `JumpTaskKeys` (cả nhóm chạy đúng một nhánh: `newWord()`
  /// + `resetSentenceCapitalizeState()`).
  ///
  /// KỲ VỌNG ĐÃ SỬA: v4.23 mượn `.ArrowUp`/`.ArrowDown` → nay `.Home`/`.End`.
  /// Mũi tên lên/xuống là ứng viên số một cho một xử lý riêng trong tương lai
  /// (điều hướng HUD gợi ý / chọn candidate); khi đó Page Up sẽ đi nhờ theo và
  /// gây lỗi rất khó truy vì bảng keycode chẳng liên quan gì tới HUD.
  /// `.Home`/`.End` cùng nghĩa "nhảy con trỏ một quãng lớn" (Page Up lùi về đầu,
  /// Page Down tiến về cuối) và không phím nào trong hai là ứng viên cho xử lý
  /// đặc thù của bộ gõ. Vẫn là MƯỢN — fix đúng bài phải thêm `.PageUp`/`.PageDown`
  /// vào `KeyLayout/Keys.swift` VÀ `InputProcessor.JumpTaskKeys` cùng lúc.
  func testPageUpDownMapToJumpTaskKeys() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapTask(keyCode: 116), .Home, "PageUp phải cắt từ")
    XCTAssertEqual(layout.mapTask(keyCode: 121), .End, "PageDown phải cắt từ")
    XCTAssertNotEqual(layout.mapTask(keyCode: 116), .ArrowUp,
      "KHÔNG mượn mũi tên: xử lý riêng cho .ArrowUp sau này sẽ tóm nhầm Page Up")
    XCTAssertNotEqual(layout.mapTask(keyCode: 121), .ArrowDown)
    // Điều kiện SỐNG CÒN của việc mượn: case được mượn phải nằm trong
    // `JumpTaskKeys`. Rơi khỏi danh sách đó là phím trượt hết mọi nhánh của
    // `handleTaskKey` và KHÔNG cắt từ nữa — tệ hơn cả trước khi map.
    for key in [TaskKey.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight] {
      XCTAssertTrue(InputProcessor.JumpTaskKeys.contains(key),
        "\(key) phải nằm trong JumpTaskKeys thì việc map mới có tác dụng")
    }
    // Home/End (đã có từ trước) không được đụng.
    XCTAssertEqual(layout.mapTask(keyCode: 115), .Home)
    XCTAssertEqual(layout.mapTask(keyCode: 119), .End)
  }

  /// v4.23 (F4): dấu câu trên bàn phím số. Không map thì phím đi qua nguyên
  /// trạng — app chèn ký tự trong khi bộ đệm vẫn giữ từ cũ → ký tự kế tiếp diff
  /// với `lastTransformed` đã lệch → backspace ăn ngược vào chữ đã gõ. Map vào
  /// `keyMap` là đủ vì mọi ký tự này đều nằm trong `NewWordKeys`.
  /// Keypad KHÔNG có biến thể shift trên macOS → hai chiều phải giống nhau.
  func testKeypadPunctuationMapsToCharacters() throws {
    let layout = KeyboardUS()
    let expected: [(Int64, Character)] = [
      (65, "."), (67, "*"), (69, "+"), (75, "/"), (78, "-"), (81, "="),
    ]
    for (code, want) in expected {
      XCTAssertEqual(layout.mapText(keyCode: code, withShift: false), want,
        "keypad \(code) phải ra '\(want)'")
      XCTAssertEqual(layout.mapText(keyCode: code, withShift: true), want,
        "keypad \(code) + Shift vẫn ra '\(want)' (keypad không có shift-variant)")
      XCTAssertNil(layout.mapTask(keyCode: code),
        "keypad \(code) là ký tự văn bản, không phải task key")
    }
    // Đối chứng: chữ số bàn phím số vẫn như cũ (VNI dùng chúng làm phím dấu).
    XCTAssertEqual(layout.mapText(keyCode: 82, withShift: false), "0")
    XCTAssertEqual(layout.mapText(keyCode: 92, withShift: false), "9")
  }

  func testIsNumberKey() throws {
    let layout = KeyboardUS()
    XCTAssertTrue(layout.isNumberKey(keyCode: 18)) // 1
    XCTAssertTrue(layout.isNumberKey(keyCode: 29)) // 0
    XCTAssertFalse(layout.isNumberKey(keyCode: 0)) // A
    XCTAssertFalse(layout.isNumberKey(keyCode: 49)) // Space
    
    // Keypad numbers
    XCTAssertTrue(layout.isNumberKey(keyCode: 83)) // Keypad 1
    XCTAssertTrue(layout.isNumberKey(keyCode: 82)) // Keypad 0
    XCTAssertEqual(layout.mapText(keyCode: 83, withShift: false), "1")
    // Shift + keypad vẫn ra chữ số trên macOS (không ra ký hiệu như hàng số)
    XCTAssertEqual(layout.mapText(keyCode: 83, withShift: true), "1")

    // isLetterKey: chỉ phím chữ cái (Caps Lock chỉ tác động nhóm này)
    XCTAssertTrue(layout.isLetterKey(keyCode: 0))   // A
    XCTAssertFalse(layout.isLetterKey(keyCode: 18)) // 1
    XCTAssertFalse(layout.isLetterKey(keyCode: 83)) // Keypad 1
    XCTAssertFalse(layout.isLetterKey(keyCode: 43)) // Comma
    XCTAssertFalse(layout.isLetterKey(keyCode: 49)) // Space
  }

  func testNumericKeypadVNI() throws {
    let processor = InputProcessor(method: .VNI)
    processor.newWord()
    
    // Simulate typing "a" (keycode 0)
    let eventA = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    _ = processor.handleEvent(event: eventA)
    XCTAssertEqual(processor.transformed, "a")
    
    // Simulate typing Keypad 1 (keycode 83)
    let eventKeypad1 = CGEvent(keyboardEventSource: nil, virtualKey: 83, keyDown: true)!
    _ = processor.handleEvent(event: eventKeypad1)
    XCTAssertEqual(processor.transformed, "á")
  }

  func testCapsLockAndShiftInteraction() throws {
    let processor = InputProcessor(method: .Telex)
    processor.newWord()
    
    // Case 1: Shift OFF, Caps Lock OFF -> lowercase "a"
    let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    event1.flags = []
    _ = processor.handleEvent(event: event1)
    XCTAssertEqual(processor.transformed, "a")
    processor.newWord()
    
    // Case 2: Shift ON, Caps Lock OFF -> uppercase "A"
    let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    event2.flags = [.maskShift]
    _ = processor.handleEvent(event: event2)
    XCTAssertEqual(processor.transformed, "A")
    processor.newWord()
    
    // Case 3: Shift OFF, Caps Lock ON -> uppercase "A"
    let event3 = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    event3.flags = [.maskAlphaShift]
    _ = processor.handleEvent(event: event3)
    XCTAssertEqual(processor.transformed, "A")
    processor.newWord()
    
    // Case 4: Shift ON, Caps Lock ON -> lowercase "a" (inversion)
    let event4 = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    event4.flags = [.maskShift, .maskAlphaShift]
    _ = processor.handleEvent(event: event4)
    XCTAssertEqual(processor.transformed, "a")
  }

  func testPredictionEngineEnhancements() throws {
    let oldAllow = Defaults[.userAllowWords]
    let oldKeep = Defaults[.userKeepWords]
    defer {
      Defaults[.userAllowWords] = oldAllow
      Defaults[.userKeepWords] = oldKeep
    }
    
    Defaults[.userAllowWords] = ["dựán"]
    Defaults[.userKeepWords] = ["thànhcông"]
    
    let allowSet = Set(Defaults[.userAllowWords].map { $0.lowercased() })
    
    // Verify isValidCandidate filter
    XCTAssertTrue(PredictionEngine.isValidCandidate("dựán", allowedSet: allowSet))
    XCTAssertFalse(PredictionEngine.isValidCandidate("t%", allowedSet: allowSet))
    XCTAssertFalse(PredictionEngine.isValidCandidate("f", allowedSet: allowSet))
    XCTAssertTrue(PredictionEngine.isValidCandidate("à", allowedSet: allowSet))
    // Từ đơn 1 chữ có dấu thanh trên ô/ơ/ư phải hợp lệ ("ở" cực phổ biến)
    XCTAssertTrue(PredictionEngine.isValidCandidate("ở", allowedSet: []))
    XCTAssertTrue(PredictionEngine.isValidCandidate("ừ", allowedSet: []))
    XCTAssertTrue(PredictionEngine.isValidCandidate("ồ", allowedSet: []))
    XCTAssertFalse(PredictionEngine.isValidCandidate("b", allowedSet: []))

    // Layer 4: phrase completion từ embedded corpus
    let phraseCandidates = PredictionEngine.shared.collectCandidates(
      prev2: "kính",
      prev1: "gửi"
    )
    XCTAssertTrue(phraseCandidates.contains { $0.word == "anh" && $0.freq > 0 })
  }

  func testMeaningfulVietnamesePhraseFilter() {
    XCTAssertTrue(UsageStatistics.isMeaningfulVietnamesePhrase(["công", "ty"]))
    XCTAssertTrue(UsageStatistics.isMeaningfulVietnamesePhrase(["xin", "chào"]))
    XCTAssertFalse(UsageStatistics.isMeaningfulVietnamesePhrase(["hello", "world"]))
    XCTAssertFalse(UsageStatistics.isMeaningfulVietnamesePhrase(["asdf", "ghjk"]))
  }

  func testPhraseCompletionIndexBuildAndLookup() {
    let index = UsageStatistics.buildPhraseSuffixIndex(
      phrases2: ["công ty": 5],
      phrases3: [
        "kính gửi anh": 4,
        "kính gửi chị": 2,
        "xin chào bạn": 3,
      ],
      phrases4: ["kính gửi anh chị": 2]
    )
    XCTAssertEqual(index["kính gửi"]?["anh"], 4)
    XCTAssertEqual(index["kính gửi"]?["chị"], 2)
    XCTAssertEqual(index["kính gửi"]?["anh chị"], 2)
    XCTAssertEqual(index["xin chào"]?["bạn"], 3)
    XCTAssertEqual(index["công"]?["ty"], 5)
  }

  func testTopPhrasePredictionPrefersMultiWordWhenConfigured() {
    Defaults[.predictionMaxWords] = 2
    defer { Defaults.reset(.predictionMaxWords) }
    let prediction = PredictionEngine.shared.topPhrasePrediction(
      prev2: "kính",
      prev1: "gửi",
      maxWords: 2
    )
    XCTAssertNotNil(prediction)
    XCTAssertGreaterThanOrEqual(prediction?.split(separator: " ").count ?? 0, 1)
  }
}

// MARK: - ===========================================
// MARK: - Word Prediction Exclusion Tests
// MARK: - ===========================================

final class WordPredictionExclusionTests: XCTestCase {

  override func tearDown() {
    Defaults.reset(.wordPredictionEnabled)
    Defaults.reset(.wordPredictionExcludedApps)
    super.tearDown()
  }

  func test_isWordPredictionActive_respectsGlobalToggle() {
    Defaults[.wordPredictionEnabled] = false
    XCTAssertFalse(InputProcessor.isWordPredictionActive(bundleId: "com.apple.Notes"))
    Defaults[.wordPredictionEnabled] = true
    XCTAssertTrue(InputProcessor.isWordPredictionActive(bundleId: "com.apple.Notes"))
  }

  func test_isWordPredictionActive_respectsExcludedApps_caseInsensitive() {
    Defaults[.wordPredictionEnabled] = true
    Defaults[.wordPredictionExcludedApps] = ["com.google.chrome"]
    XCTAssertFalse(InputProcessor.isWordPredictionActive(bundleId: "com.google.Chrome"))
    XCTAssertFalse(InputProcessor.isWordPredictionActive(bundleId: " COM.GOOGLE.CHROME "))
    XCTAssertTrue(InputProcessor.isWordPredictionActive(bundleId: "com.apple.Notes"))
  }

  func test_isWordPredictionActive_respectsRuleDisablePrediction() {
    Defaults[.wordPredictionEnabled] = true
    var overrides = ResolvedRuleOverrides()
    overrides.disablePrediction = true
    XCTAssertFalse(InputProcessor.isWordPredictionActive(
      bundleId: "com.apple.Notes", ruleOverrides: overrides))
  }

  func test_isWordPredictionActive_inactiveForEmptyBundleId() {
    Defaults[.wordPredictionEnabled] = true
    XCTAssertFalse(InputProcessor.isWordPredictionActive(bundleId: ""))
  }
}

// MARK: - ===========================================
// MARK: - Word Prediction Tab Acceptance Tests
// MARK: - ===========================================

final class WordPredictionTabAcceptanceTests: XCTestCase {

  override func setUp() {
    super.setUp()
    Defaults[.spellCheckEnabled] = true
    Defaults[.wordPredictionEnabled] = true
    Defaults[.wordPredictionExcludedApps] = []
  }

  override func tearDown() {
    Defaults.reset(.spellCheckEnabled)
    Defaults.reset(.wordPredictionEnabled)
    Defaults.reset(.wordPredictionExcludedApps)
    super.tearDown()
  }

  func testTabImmediatelyAfterSpaceAcceptsFreshPrediction() {
    let processor = makeNotesProcessor()

    typeKeys([40, 34, 45, 4, 1], into: processor) // kinhs -> kính
    _ = typeKey(49, into: processor) // Space creates a prediction from "kính".

    let tabResult = typeKey(48, into: processor)
    XCTAssertTrue(tabResult == nil, "Fresh prediction after Space should be accepted by Tab")
  }

  func testTabAfterEnterPassesThroughInsteadOfAcceptingStalePrediction() {
    let processor = makeNotesProcessor()

    typeKeys([40, 34, 45, 4, 1], into: processor) // kinhs -> kính
    XCTAssertEqual(processor.transformed, "kính")

    _ = typeKey(49, into: processor) // Space creates a prediction from "kính".
    XCTAssertEqual(processor.transformed, "")
    XCTAssertTrue(typeKey(36, into: processor) != nil) // Enter starts a new line.

    let tabResult = typeKey(48, into: processor)
    XCTAssertTrue(tabResult != nil, "Tab at a new line must pass through for indentation")
  }

  func testTabAfterExplicitWordBoundaryPassesThrough() {
    let processor = makeNotesProcessor()

    typeKeys([40, 34, 45, 4, 1], into: processor) // kinhs -> kính
    _ = typeKey(49, into: processor) // Space creates a prediction from "kính".
    processor.newWord()

    let tabResult = typeKey(48, into: processor)
    XCTAssertTrue(tabResult != nil, "Tab after a caret/mouse boundary must not accept stale text")
  }

  private func makeNotesProcessor() -> InputProcessor {
    let processor = InputProcessor(method: .Telex)
    processor.changeActiveApp("com.apple.Notes")
    return processor
  }

  private func typeKeys(_ codes: [UInt16], into processor: InputProcessor) {
    for code in codes {
      _ = typeKey(code, into: processor)
    }
  }

  @discardableResult
  private func typeKey(_ code: UInt16, into processor: InputProcessor) -> Unmanaged<CGEvent>? {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
    return processor.handleEvent(event: event)
  }
}

// MARK: - ===========================================
// MARK: - Prediction HUD Layout Tests
// MARK: - ===========================================

final class PredictionHUDWindowTests: XCTestCase {

  func testContentSizeHasMinimumDimensions() {
    let size = PredictionHUDWindow.contentSize(for: "→ theo   ⇥ Tab", fontSize: 16)

    XCTAssertGreaterThanOrEqual(size.width, 160)
    XCTAssertGreaterThanOrEqual(size.height, 36)
  }

  func testContentSizeExpandsForLongText() {
    let shortSize = PredictionHUDWindow.contentSize(for: "→ theo   ⇥ Tab", fontSize: 16)
    let longSize = PredictionHUDWindow.contentSize(
      for: "→ phương pháp   ⇥ Tab",
      fontSize: 16
    )

    XCTAssertGreaterThan(longSize.width, shortSize.width)
    XCTAssertEqual(longSize.height, shortSize.height)
  }

  func testContentSizeExpandsForLargerFont() {
    let smallSize = PredictionHUDWindow.contentSize(for: "→ theo   ⇥ Tab", fontSize: 12)
    let largeSize = PredictionHUDWindow.contentSize(for: "→ theo   ⇥ Tab", fontSize: 24)

    XCTAssertGreaterThan(largeSize.width, smallSize.width)
    XCTAssertGreaterThan(largeSize.height, smallSize.height)
  }

  func testNormalizedCaretRectClampsWideLineBounds() {
    let wide = CGRect(x: 100, y: 400, width: 900, height: 22)
    let normalized = PredictionHUDWindow.normalizedCaretRect(wide)
    XCTAssertLessThanOrEqual(normalized.width, 8)
    XCTAssertGreaterThanOrEqual(normalized.maxX, wide.maxX - 4)
  }

  func testComputeVisualFramePlacesHUDAboveCaretNearScreenBottom() {
    let contentSize = CGSize(width: 200, height: 36)
    let caret = CGRect(x: 420, y: 820, width: 2, height: 20)
    let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    guard let frame = PredictionHUDWindow.computeVisualFrame(
      caretAX: caret,
      contentSize: contentSize,
      lineOffset: 4,
      visibleFrame: screen,
      primaryDisplayHeight: 900
    ) else {
      return XCTFail("expected a frame")
    }

    let caretTopCocoa = 900 - caret.minY
    let caretBottomCocoa = 900 - caret.maxY
    let hudTop = frame.origin.y + frame.height
    XCTAssertFalse(frame.origin.y < caretTopCocoa && hudTop > caretBottomCocoa)
    XCTAssertGreaterThanOrEqual(frame.origin.y, caretTopCocoa + 8)
    // Căn giữa theo bề ngang màn hình.
    XCTAssertEqual(frame.midX, screen.midX, accuracy: 1)
  }

  func testComputeVisualFrameRespectsLineOffset() {
    let contentSize = CGSize(width: 200, height: 36)
    let caret = CGRect(x: 420, y: 820, width: 2, height: 20)
    let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    guard let near = PredictionHUDWindow.computeVisualFrame(
      caretAX: caret,
      contentSize: contentSize,
      lineOffset: 2,
      visibleFrame: screen,
      primaryDisplayHeight: 900
    ), let far = PredictionHUDWindow.computeVisualFrame(
      caretAX: caret,
      contentSize: contentSize,
      lineOffset: 10,
      visibleFrame: screen,
      primaryDisplayHeight: 900
    ) else {
      return XCTFail("expected frames")
    }
    XCTAssertGreaterThan(far.origin.y, near.origin.y)
  }

  func testComputeVisualFrameAvoidsBelowCaretForChatInputAtBottom() {
    let contentSize = CGSize(width: 200, height: 36)
    let caret = CGRect(x: 420, y: 820, width: 2, height: 20)
    let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    guard let frame = PredictionHUDWindow.computeVisualFrame(
      caretAX: caret,
      contentSize: contentSize,
      lineOffset: 4,
      visibleFrame: screen,
      primaryDisplayHeight: 900
    ) else {
      return XCTFail("expected a frame")
    }

    let caretTopCocoa = 900 - caret.minY
    let caretBottomCocoa = 900 - caret.maxY
    // Không đặt HUD dưới dòng đang gõ (bug cũ khi thiếu chỗ phía trên).
    XCTAssertGreaterThanOrEqual(frame.origin.y + frame.height, caretBottomCocoa + 4)
    XCTAssertGreaterThanOrEqual(frame.origin.y, caretTopCocoa + 4)
  }
}

// MARK: - Clipboard history

@MainActor
final class ClipboardHistoryTests: XCTestCase {

  override func setUp() {
    super.setUp()
    Defaults.reset(.clipboardHistoryEnabled)
    Defaults.reset(.clipboardHistoryCapacity)
    Defaults.reset(.clipboardHistoryContentMode)
    Defaults.reset(.clipboardHistoryMaxEntryMegabytes)
    Defaults.reset(.clipboardHistoryModifierOnlyHotkey)
    ClipboardHistoryService.shared.clear()
  }

  func testPreviewTextTruncatesLongString() {
    let long = String(repeating: "a", count: 100)
    let preview = ClipboardHistoryService.previewText(long)
    XCTAssertEqual(preview.count, 70)
    XCTAssertTrue(preview.hasSuffix("…"))
  }

  func testBuildSnapshotTextOnlySkipsEmpty() {
    let pb = NSPasteboard.general
    pb.clearContents()
    XCTAssertNil(ClipboardHistoryService.buildSnapshot(from: pb, mode: .textOnly))
    pb.setString("xin chào", forType: .string)
    let snap = ClipboardHistoryService.buildSnapshot(from: pb, mode: .textOnly)
    XCTAssertNotNil(snap)
    XCTAssertEqual(snap?.preview, "xin chào")
    XCTAssertFalse(snap?.isFileEntry ?? true)
  }

  func testCaptureRespectsCapacity() {
    Defaults[.clipboardHistoryEnabled] = true
    Defaults[.clipboardHistoryCapacity] = 3
    let pb = NSPasteboard.general
    for i in 1...5 {
      pb.clearContents()
      pb.setString("item \(i)", forType: .string)
      ClipboardHistoryService.shared.captureCurrentPasteboard(pb)
    }
    XCTAssertEqual(ClipboardHistoryService.shared.entries.count, 3)
    XCTAssertEqual(ClipboardHistoryService.shared.entries.first?.preview, "item 5")
    XCTAssertEqual(ClipboardHistoryService.shared.entries.last?.preview, "item 3")
  }

  func testDedupSkipsIdenticalConsecutiveCapture() {
    Defaults[.clipboardHistoryEnabled] = true
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString("same", forType: .string)
    ClipboardHistoryService.shared.captureCurrentPasteboard(pb)
    ClipboardHistoryService.shared.captureCurrentPasteboard(pb)
    XCTAssertEqual(ClipboardHistoryService.shared.entries.count, 1)
  }

  func testDifferentContentWithSamePreviewCreatesTwoEntries() {
    Defaults[.clipboardHistoryEnabled] = true
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString("hello", forType: .string)
    ClipboardHistoryService.shared.captureCurrentPasteboard(pb)
    pb.clearContents()
    let item = NSPasteboardItem()
    item.setString("hello", forType: .string)
    item.setString("extra", forType: NSPasteboard.PasteboardType("org.vkey.test-meta"))
    pb.writeObjects([item])
    ClipboardHistoryService.shared.captureCurrentPasteboard(pb)
    XCTAssertEqual(ClipboardHistoryService.shared.entries.count, 2)
  }

  func testMarkInternalPasteboardWriteSkipsNextCapture() {
    Defaults[.clipboardHistoryEnabled] = true
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString("internal", forType: .string)
    let before = pb.changeCount
    ClipboardHistoryService.shared.markInternalPasteboardWrite(pb)
    ClipboardHistoryService.shared.captureIfPasteboardChanged(since: before)
    XCTAssertTrue(ClipboardHistoryService.shared.entries.isEmpty)
  }

  func testFingerprintDiffersForDifferentStrings() {
    let a = NSPasteboardItem()
    a.setString("a", forType: .string)
    let b = NSPasteboardItem()
    b.setString("b", forType: .string)
    XCTAssertNotEqual(
      ClipboardHistoryService.fingerprint(for: [a]),
      ClipboardHistoryService.fingerprint(for: [b])
    )
  }

  func testMaxEntryBytesFromSettingsDefaultsTo10MB() {
    Defaults[.clipboardHistoryMaxEntryMegabytes] = 10
    XCTAssertEqual(ClipboardHistoryService.maxEntryBytesFromSettings(), 10 * 1024 * 1024)
  }

  func testOversizedCaptureDoesNotAddEntry() {
    Defaults[.clipboardHistoryEnabled] = true
    Defaults[.clipboardHistoryMaxEntryMegabytes] = 1
    let pb = NSPasteboard.general
    pb.clearContents()
    let big = String(repeating: "x", count: 2 * 1024 * 1024)
    pb.setString(big, forType: .string)
    XCTAssertGreaterThan(
      ClipboardHistoryService.estimatedCaptureBytes(from: pb, mode: .textOnly),
      ClipboardHistoryService.maxEntryBytesFromSettings()
    )
    ClipboardHistoryService.shared.captureCurrentPasteboard(pb)
    XCTAssertTrue(ClipboardHistoryService.shared.entries.isEmpty)
  }

  func testEstimatedBytesSumsPasteboardAndFilePayload() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("vkey-clip-\(UUID().uuidString).txt")
    try String(repeating: "z", count: 4096).write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString("caption", forType: .string)
    pb.writeObjects([fileURL as NSURL])

    let pasteBytes = ClipboardHistoryService.pasteboardPayloadBytes(from: pb, allowFiles: true)
    let fileBytes = ClipboardHistoryService.filePayloadBytes(from: [fileURL])
    let estimated = ClipboardHistoryService.estimatedCaptureBytes(from: pb, mode: .textAndFiles)
    XCTAssertGreaterThan(pasteBytes, 0)
    XCTAssertGreaterThan(fileBytes, 0)
    XCTAssertEqual(estimated, pasteBytes + fileBytes)
  }

  func testPasteboardPayloadBytesSkipsFilesInTextOnlyMode() {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString("only text", forType: .string)
    let withFiles = ClipboardHistoryService.pasteboardPayloadBytes(from: pb, allowFiles: true)
    let textOnly = ClipboardHistoryService.pasteboardPayloadBytes(from: pb, allowFiles: false)
    XCTAssertEqual(withFiles, textOnly)
  }
}

// MARK: - Clipboard history hotkey

final class ClipboardHistoryHotkeyTests: XCTestCase {

  override func setUp() {
    super.setUp()
    Defaults.reset(.clipboardHistoryModifierOnlyHotkey)
    KeyboardShortcuts.setShortcut(nil, for: .pasteClipboardHistory)
  }

  private func keyDown(keyCode: UInt16, flags: CGEventFlags = []) -> CGEvent {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)!
    event.flags = flags
    return event
  }

  func testDefaultShiftCommandVMatches() {
    Defaults[.clipboardHistoryModifierOnlyHotkey] = 0
    let event = keyDown(keyCode: 9, flags: [.maskCommand, .maskShift])
    XCTAssertTrue(ClipboardHistoryHotkey.matchesKeyDown(event))
  }

  func testDoesNotMatchWhenModifierOnlyHotkeyConfigured() {
    Defaults[.clipboardHistoryModifierOnlyHotkey] = 456
    let event = keyDown(keyCode: 9, flags: [.maskCommand, .maskShift])
    XCTAssertFalse(ClipboardHistoryHotkey.matchesKeyDown(event))
  }

  func testDoesNotMatchPlainCommandV() {
    Defaults[.clipboardHistoryModifierOnlyHotkey] = 0
    let event = keyDown(keyCode: 9, flags: [.maskCommand])
    XCTAssertFalse(ClipboardHistoryHotkey.matchesKeyDown(event))
  }

  func testDoesNotMatchWhenOptionHeld() {
    Defaults[.clipboardHistoryModifierOnlyHotkey] = 0
    let event = keyDown(keyCode: 9, flags: [.maskCommand, .maskShift, .maskAlternate])
    XCTAssertFalse(ClipboardHistoryHotkey.matchesKeyDown(event))
  }

  func testInstallDefaultIfNeededSetsShiftCommandV() {
    Defaults[.clipboardHistoryModifierOnlyHotkey] = 0
    ClipboardHistoryHotkey.installDefaultIfNeeded()
    let shortcut = KeyboardShortcuts.getShortcut(for: .pasteClipboardHistory)
    XCTAssertNotNil(shortcut)
    XCTAssertEqual(shortcut?.key?.rawValue, KeyboardShortcuts.Key.v.rawValue)
    XCTAssertEqual(shortcut?.modifiers, [.shift, .command])
  }

  func testCustomShortcutMatchesKeyDown() {
    Defaults[.clipboardHistoryModifierOnlyHotkey] = 0
    KeyboardShortcuts.setShortcut(
      KeyboardShortcuts.Shortcut(.c, modifiers: [.command, .option]),
      for: .pasteClipboardHistory
    )
    let event = keyDown(keyCode: 8, flags: [.maskCommand, .maskAlternate])
    XCTAssertTrue(ClipboardHistoryHotkey.matchesKeyDown(event))
  }
}

// MARK: - ===========================================
// MARK: - TiengVietValidator Rule Tests
// MARK: - ===========================================

/// Focused unit tests for the syllable validator.
/// The integration tests above exercise validator indirectly through transform_text_*.
/// These tests pin down individual rules so regressions are easy to diagnose.
final class TiengVietValidatorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    Defaults.reset(.spellCheckEnabled)
    Defaults.reset(.spellCheckInSentenceEnabled)
    Defaults.reset(.englishAutoRestoreEnabled)
    Defaults.reset(.restorePolicy)
    Defaults.reset(.suggestionEnabled)
    Defaults.reset(.autoApplyHighConfidenceSuggestion)
    Defaults.reset(.personalDictionaryEnabled)
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userKeepWords)
    Defaults.reset(.userDenyWords)
  }

  /// Helper: parse raw characters into ThanhPhanTieng without diacritics applied.
  private func parse(_ text: String) -> ThanhPhanTieng {
    return TiengVietParser.parse(Array(text))
  }

  // MARK: - Valid syllables

  func testValidSyllablesDoNotNeedRecovery() throws {
    XCTAssertFalse(TiengVietValidator.needsRecovery(parse("a")))
    XCTAssertFalse(TiengVietValidator.needsRecovery(parse("ma")))
    XCTAssertFalse(TiengVietValidator.needsRecovery(parse("xin")))
    XCTAssertFalse(TiengVietValidator.needsRecovery(parse("chao")))
    XCTAssertFalse(TiengVietValidator.needsRecovery(parse("nghieng")))
  }

  func testValidFinalConsonants() throws {
    for ending in ["ac", "ach", "am", "an", "ang", "anh", "ap", "at"] {
      XCTAssertFalse(
        TiengVietValidator.needsRecovery(parse(ending)),
        "\(ending) should be a valid syllable"
      )
    }
  }

  // MARK: - Invalid vowel combinations

  func testInvalidVowelCombinationsTriggerRecovery() throws {
    for invalid in ["ae", "ea", "ey", "iy", "yi", "yo", "yu"] {
      XCTAssertTrue(
        TiengVietValidator.needsRecovery(parse(invalid)),
        "\(invalid) should require recovery (invalid vowel combo)"
      )
    }
  }

  // MARK: - Invalid vowel+ending combinations

  func testDiphthongsWithoutFinalConsonant() throws {
    // "ai", "ao", "au", "ay" cannot take a final consonant.
    XCTAssertTrue(TiengVietValidator.needsRecovery(parse("aim")))
    XCTAssertTrue(TiengVietValidator.needsRecovery(parse("ain")))
    XCTAssertTrue(TiengVietValidator.needsRecovery(parse("aut")))
  }

  func testBaseUaCannotTakeFinal() throws {
    // "ua" alone has no final consonant; "uat" must recover unless circumflex is applied.
    XCTAssertTrue(TiengVietValidator.needsRecovery(parse("uat")))
    XCTAssertTrue(TiengVietValidator.needsRecovery(parse("uan")))
  }

  func testUaWithCircumflexAllowsFinal() throws {
    // "uâ" (after circumflex) takes "n" or "t".
    XCTAssertFalse(
      TiengVietValidator.needsRecovery(parse("uat"), dauMu: .muUp),
      "uâ + t should be valid"
    )
    XCTAssertFalse(
      TiengVietValidator.needsRecovery(parse("uan"), dauMu: .muUp),
      "uâ + n should be valid"
    )
  }

  func testUoWithHornAllowsFinal() throws {
    // "ươ" (after horn) takes "c", "n", "ng", "t", "p", "m".
    XCTAssertFalse(
      TiengVietValidator.needsRecovery(parse("uoc"), dauMu: .muMoc),
      "ươ + c should be valid"
    )
    XCTAssertFalse(
      TiengVietValidator.needsRecovery(parse("uon"), dauMu: .muMoc),
      "ươ + n should be valid"
    )
  }

  // MARK: - Invalid final consonants

  func testInvalidFinalConsonantTriggersRecovery() throws {
    // 'b', 'd', 'f', 'g', 'h', 'j' etc are not valid final consonants.
    XCTAssertTrue(TiengVietValidator.needsRecovery(parse("ab")))
    XCTAssertTrue(TiengVietValidator.needsRecovery(parse("ad")))
    XCTAssertTrue(TiengVietValidator.needsRecovery(parse("af")))
  }

  // MARK: - Edge: "ie" (which becomes "iê" with circumflex)

  func testIeWithCircumflexAllowsCommonFinals() throws {
    // "tiếng" → iê + ng: should be valid.
    XCTAssertFalse(
      TiengVietValidator.needsRecovery(parse("tieng"), dauMu: .muUp),
      "iê + ng should be valid"
    )
  }

  // MARK: - Macro Replacement Tests

  func testMacroReplacementWithSpace() throws {
    let macros = [Macro(from: "dc", to: "địa chỉ")]
    let replacement = InputProcessor.macroReplacement(
      for: "dc",
      endingChar: " ",
      macros: macros,
      usesNFC: true
    )

    XCTAssertEqual(replacement?.backspaceCount, 2)
    XCTAssertEqual(String(replacement?.diffChars ?? []), "địa chỉ ")
  }

  func testMacroReplacementWithPunctuation() throws {
    let macros = [Macro(from: "email", to: "long@example.com")]
    let replacement = InputProcessor.macroReplacement(
      for: "email",
      endingChar: ".",
      macros: macros,
      usesNFC: true
    )

    XCTAssertEqual(replacement?.backspaceCount, 5)
    XCTAssertEqual(String(replacement?.diffChars ?? []), "long@example.com.")
  }

  func testMacroReplacementNoMatch() throws {
    let macros = [Macro(from: "dc", to: "địa chỉ")]

    XCTAssertNil(InputProcessor.macroReplacement(
        for: "dt", endingChar: " ", macros: macros, usesNFC: true))
  }

  func testMacroReplacementIgnoresEmptyCurrentAndFields() throws {
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "",
        endingChar: " ",
        macros: [Macro(from: "dc", to: "địa chỉ")],
        usesNFC: true
      )
    )
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "dc",
        endingChar: " ",
        macros: [Macro(from: "", to: "địa chỉ")],
        usesNFC: true
      )
    )
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "dc",
        endingChar: " ",
        macros: [Macro(from: "dc", to: "")],
        usesNFC: true
      )
    )
  }

  /// Macro phải dùng CHUNG trục diff với mọi path thay-thế khác: grapheme cho
  /// field NFC, scalar NFD cho field NFD (Chromium/Electron/Slack). Trigger có
  /// dấu là chỗ hai trục lệch nhau — "tớ" là 2 grapheme nhưng 4 scalar NFD
  /// (t + o + ◌̛ + ◌́). Dùng số đếm của trục sai thì field NFD xoá thiếu và sót
  /// ký tự rơi lại trước phần macro bung ra.
  func testMacroReplacementFollowsFieldAxis() throws {
    let macros = [Macro(from: "tớ", to: "tôi")]

    // Diff chung giữ nguyên tiền tố chung "t" thay vì xoá trọn từ.
    let nfc = InputProcessor.macroReplacement(
      for: "tớ", endingChar: " ", macros: macros, usesNFC: true)
    XCTAssertEqual(nfc?.backspaceCount, 1, "Field NFC: grapheme, chung tiền tố 't'")
    XCTAssertEqual(String(nfc?.diffChars ?? []), "ôi ")

    let nfd = InputProcessor.macroReplacement(
      for: "tớ", endingChar: " ", macros: macros, usesNFC: false)
    XCTAssertEqual(nfd?.backspaceCount, 3, "Field NFD: scalar o+◌̛+◌́ sau tiền tố 't'")

    // Mô phỏng field NFD, KHÔNG chuẩn hoá kết quả — để sai lệch dạng lộ ra.
    func replayNFDField(_ r: (backspaceCount: Int, diffChars: [Character])?) -> String {
      var field = Array("tớ".decomposedStringWithCanonicalMapping.unicodeScalars)
      guard let r else { return String(String.UnicodeScalarView(field)) }
      field.removeLast(min(r.backspaceCount, field.count))
      // Field NFD nhận đúng dạng mà sendReplacement sẽ phát ra.
      let emitted = EventSimulator.emittedCharacters(
        r.diffChars, normalizeToNFC: r.backspaceCount == nfc?.backspaceCount)
      field.append(contentsOf: String(emitted).unicodeScalars)
      return String(String.UnicodeScalarView(field))
    }

    XCTAssertEqual(
      replayNFDField(nfd), "tôi ".decomposedStringWithCanonicalMapping,
      "Trục NFD dựng lại đúng 'tôi ' ở dạng NFD của field")
    XCTAssertEqual(
      replayNFDField(nfc).precomposedStringWithCanonicalMapping, "tơôi ",
      "Trục NFC áp lên field NFD xoá thiếu 1 scalar → sót 'ơ' (bug đã vá)")
  }

  /// Trigger ASCII (đại đa số macro) phải giữ nguyên hành vi trên cả hai trục —
  /// grapheme và scalar bằng nhau nên diff không đổi.
  func testMacroReplacementIdenticalForASCIITrigger() throws {
    let macros = [Macro(from: "dc", to: "địa chỉ")]
    for usesNFC in [true, false] {
      let r = InputProcessor.macroReplacement(
        for: "dc", endingChar: " ", macros: macros, usesNFC: usesNFC)
      XCTAssertEqual(r?.backspaceCount, 2, "Trigger ASCII: xoá 2 dù trục nào")
      XCTAssertEqual(String(r?.diffChars ?? []), "địa chỉ ")
    }
  }

  func testCommitReplacementTargetIncludesEndingWhenCallerSwallowsIt() throws {
    XCTAssertEqual(
      InputProcessor.commitReplacementTarget(
        word: "of",
        endingChar: " ",
        includeEndingChar: true
      ),
      "of "
    )
    XCTAssertEqual(
      InputProcessor.commitReplacementTarget(
        word: "of",
        endingChar: ".",
        includeEndingChar: true
      ),
      "of."
    )
    XCTAssertEqual(
      InputProcessor.commitReplacementTarget(
        word: "of",
        endingChar: ".",
        includeEndingChar: false
      ),
      "of"
    )
  }

  // MARK: - Lexicon / Spell Decision / Suggestion

  func testLexiconManagerEmbeddedDefaults() throws {
    let manager = LexiconManager(updatePackageURL: URL(fileURLWithPath: "/tmp/vkey-lexicon-no-file.json"))
    manager.reload()

    XCTAssertTrue(manager.isVietnameseWord("việt"))
    XCTAssertTrue(manager.isEnglishWord("text"))
    XCTAssertTrue(manager.shouldApplyLegacyRestore(transformed: "ò", rawInput: "of"))
  }

  func testLexiconManagerHybridPrefersHigherVersionPackage() throws {
    let path = URL(fileURLWithPath: "/tmp/vkey-lexicon-update-test.json")
    let manager = LexiconManager(updatePackageURL: path)
    let package = """
    {
      "version": 5,
      "vietnamese": ["thành","công"],
      "english": ["deploy"],
      "keep": ["sara"]
    }
    """
    try manager.setUpdatePackageData(Data(package.utf8))
    manager.reload()

    let versions = manager.snapshotVersions()
    let sources = manager.snapshotSources()
    XCTAssertEqual(versions.vn, 5)
    XCTAssertEqual(sources.vn, .updatePackage)
    XCTAssertTrue(manager.isVietnameseWord("thành"))
    XCTAssertTrue(manager.isEnglishWord("deploy"))
  }

  /// Fix #2: gói ĐÃ LƯU trên đĩa cũng phải qua cổng kiểm tra khi load — gói vi
  /// phạm giới hạn cấu trúc (L4) bị từ chối, lexicon rơi về bản embedded thay vì
  /// nuốt gói không an toàn (embedded version = 2 < 999 nên nếu bỏ qua kiểm tra
  /// thì gói này SẼ được adopt — chứng minh cổng load thực sự chặn).
  func testLexiconLoadRejectsInvalidOnDiskPackage() throws {
    let path = URL(fileURLWithPath: "/tmp/vkey-lexicon-invalid-ondisk.json")
    let longWord = String(repeating: "a", count: LexiconUpdatePackage.maxStringLength + 1)
    let bad = #"{"version": 999, "vietnamese": ["\#(longWord)"], "english": [], "keep": []}"#
    try Data(bad.utf8).write(to: path)
    defer { try? FileManager.default.removeItem(at: path) }

    let manager = LexiconManager(updatePackageURL: path)
    manager.reload()

    XCTAssertNotEqual(manager.snapshotVersions().vn, 999)
    XCTAssertEqual(manager.snapshotSources().vn, .embedded)
  }

  func testLexiconManagerUserAllowAndDenyOverride() throws {
    Defaults[.userAllowWords] = ["abcxyz"]
    Defaults[.userDenyWords] = ["việt"]
    defer {
      Defaults[.userAllowWords] = []
      Defaults[.userDenyWords] = []
    }

    let manager = LexiconManager(updatePackageURL: URL(fileURLWithPath: "/tmp/vkey-lexicon-user-override.json"))
    manager.reload()

    XCTAssertTrue(manager.isVietnameseWord("abcxyz"))
    XCTAssertFalse(manager.isVietnameseWord("việt"))
  }

  func testSpellDecisionRestoreEnglishWhenInvalidVietnamese() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldPolicy = Defaults[.restorePolicy]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.restorePolicy] = oldPolicy
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.restorePolicy] = .vietnameseFirst

    let engine = SpellDecisionEngine.shared
    let decision = engine.evaluate(rawInput: "text", transformed: "tẽt", needsRecovery: true)
    XCTAssertEqual(decision, .restoreRawEnglish("text"))
  }

  /// Regression 1.7.11: balanced policy phải keep VN khi transformed có
  /// dấu Việt (ả/ư/đ/...) — bất kể raw có match English (vd "car"/"cả",
  /// "nuut"/"nứt"). Trước đây balanced chỉ check `extremelyCommonVietnameseWords`
  /// cherry-picked → các từ phổ biến có dấu nhưng không trong list bị restore raw.
  func testSpellDecisionBalancedKeepsVnDiacritic() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldPolicy = Defaults[.restorePolicy]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.restorePolicy] = oldPolicy
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.restorePolicy] = .balanced

    let engine = SpellDecisionEngine.shared
    // "car" (English) → "cả" (telex hỏi). Balanced phải keep VN do dấu ả.
    let d1 = engine.evaluate(rawInput: "car", transformed: "cả", needsRecovery: false)
    XCTAssertEqual(d1, .keepVietnamese)
    // "the" → "thể" (telex hỏi).
    let d2 = engine.evaluate(rawInput: "the", transformed: "thể", needsRecovery: false)
    XCTAssertEqual(d2, .keepVietnamese)
    // "but" → "bụt" (telex nặng nếu user gõ "butj" — nhưng nếu commit thẳng
    // "but" sẽ là raw không dấu). Test với có dấu:
    let d3 = engine.evaluate(rawInput: "buj", transformed: "bụ", needsRecovery: false)
    XCTAssertEqual(d3, .keepVietnamese)
  }

  func testSpellDecisionVietnameseFirstKeepsValidVietnamese() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldPolicy = Defaults[.restorePolicy]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.restorePolicy] = oldPolicy
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.restorePolicy] = .vietnameseFirst

    let engine = SpellDecisionEngine.shared
    let decision = engine.evaluate(rawInput: "gi", transformed: "gì", needsRecovery: false)
    XCTAssertEqual(decision, .keepVietnamese)
  }

  func testSpellDecisionLegacyRestoreBackwardCompatibility() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true

    let engine = SpellDecisionEngine.shared
    let decision = engine.evaluate(rawInput: "of", transformed: "ò", needsRecovery: false)
    XCTAssertEqual(decision, .restoreRawEnglish("of"))
  }

  func testSuggestionServiceRankingForVietnameseTypo() throws {
    let service = SuggestionService.shared
    let suggestions = service.suggest(word: "thih", locale: "vi_VN", limit: 5)
    XCTAssertFalse(suggestions.isEmpty)
    XCTAssertTrue(suggestions.first?.score ?? 0 > 0)
  }

  func testSpellDecisionSuggestsWhenInvalidAndNotEnglish() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldSuggestion = Defaults[.suggestionEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.suggestionEnabled] = oldSuggestion
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.suggestionEnabled] = true

    let engine = SpellDecisionEngine.shared
    let decision = engine.evaluate(rawInput: "thih", transformed: "thih", needsRecovery: true)
    if case .suggest(let candidates) = decision {
      XCTAssertFalse(candidates.isEmpty)
    } else {
      XCTFail("Expected suggestion decision for invalid non-English token")
    }
  }

  func testSpellDecisionDoesNotSuggestForValidSyllableNotInDictionary() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldSuggestion = Defaults[.suggestionEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.suggestionEnabled] = oldSuggestion
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.suggestionEnabled] = true

    let engine = SpellDecisionEngine.shared
    // "tắt" is a valid Vietnamese syllable (needsRecovery is false) but is not in the embedded dictionary.
    let decision = engine.evaluate(rawInput: "tatws", transformed: "tắt", needsRecovery: false)
    XCTAssertEqual(decision, .keepVietnamese)
  }

  func testSpellDecisionPreservesDoubledToneMarks() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
    }
    Defaults[.spellCheckEnabled] = true

    let engine = SpellDecisionEngine.shared
    
    // "barr" has doubled "rr", should be kept raw even if needsRecovery is true
    let decision1 = engine.evaluate(rawInput: "barr", transformed: "barr", needsRecovery: true)
    XCTAssertEqual(decision1, .keepRaw)
    
    // "class" has doubled "ss", should be kept raw even if needsRecovery is true
    let decision2 = engine.evaluate(rawInput: "class", transformed: "class", needsRecovery: true)
    XCTAssertEqual(decision2, .keepRaw)
  }

  /// v4.23 — THAY THẾ `testTransformationTrackerDetectsRepeatedFailureSignals`.
  ///
  /// Test cũ dựng `TransformationTracker` và khẳng định hai telemetry lỗi liên
  /// tiếp thì bộ đếm bật cờ. Cơ chế đó nay đã bị gỡ hẳn (kèm công tắc
  /// `autoSwitchStrategy`) vì nó KHÔNG BAO GIỜ chạy được ngoài test: nhánh
  /// `isHighRisk` đòi `usedAsyncQueue == false`, mà mọi call site thật dựng
  /// `EventSendTelemetry` với `attemptedTransform == true` đều đặt
  /// `usedAsyncQueue: true`. Test cũ pass chỉ vì nó tự tay dựng telemetry mà
  /// transport không bao giờ phát ra — nó khoá một con đường chết, nên phải đi
  /// cùng đoạn code chết chứ không được "sửa cho biên dịch được".
  ///
  /// Thay vào đó khoá ĐÚNG hành vi còn lại: chiến lược gửi phím tra THẲNG bảng
  /// per-app, không qua tầng đệm nào nữa. `activeApp` rỗng (chưa có app nào) là
  /// khác biệt hành vi DUY NHẤT của lần gỡ này — trước đây rơi vào `.batch`
  /// (giá trị khởi tạo của struct), nay rơi vào fallback `.hybrid` của
  /// `getStrategy`. Ghi lại tường minh để lần sau không ai coi là hồi quy.
  func testSendingStrategyReadsPerAppTableWithHybridFallback() throws {
    guard case .hybrid = EventSimulator.getStrategy(for: "") else {
      return XCTFail("activeApp rỗng phải rơi về fallback .hybrid của getStrategy")
    }
    guard case .hybrid = EventSimulator.getStrategy(for: "com.example.khongkhaibao") else {
      return XCTFail("App không khai báo phải fallback .hybrid")
    }
    guard case .stepByStep = EventSimulator.getStrategy(for: "com.apple.Terminal") else {
      return XCTFail("App có khai báo phải lấy đúng strategy trong bảng")
    }
  }

  func testStepByStepUnicodeUnitsPreserveWholeCharacter() throws {
    XCTAssertEqual(
      EventSimulator.unicodeUnits(for: "ắ"),
      String("ắ").utf16.map { UniChar($0) }
    )
    XCTAssertEqual(EventSimulator.unicodeUnits(for: "😀").count, 2)
    // v4.15: transport KHÔNG tự chuẩn hoá — combining mark NFD giữ nguyên 2
    // unit (base + mark). Chuẩn hoá NFC do sendReplacement quyết định theo
    // field (xem testEmittedCharactersFollowsFieldNormalization).
    XCTAssertEqual(EventSimulator.unicodeUnits(for: Character("a\u{0301}")).count, 2)
  }

  func testModifierOnlyHotkeyTogglesAfterPurePressAndFullRelease() throws {
    let control = UInt64(NSEvent.ModifierFlags.control.rawValue)
    let shift = UInt64(NSEvent.ModifierFlags.shift.rawValue)
    let target = control | shift
    let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))

    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: target, modifierTarget: target)
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: control, modifierTarget: target)
    )
    XCTAssertTrue(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: 0, modifierTarget: target)
    )
  }

  func testModifierOnlyHotkeyDoesNotToggleWhenExtraModifierIsAdded() throws {
    let control = UInt64(NSEvent.ModifierFlags.control.rawValue)
    let shift = UInt64(NSEvent.ModifierFlags.shift.rawValue)
    let option = UInt64(NSEvent.ModifierFlags.option.rawValue)
    let target = control | shift
    let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))

    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: target, modifierTarget: target)
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(
        type: .flagsChanged,
        currentMods: target | option,
        modifierTarget: target
      )
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: 0, modifierTarget: target)
    )
  }

  func testModifierOnlyHotkeyDoesNotToggleAfterInterveningKeyDown() throws {
    let control = UInt64(NSEvent.ModifierFlags.control.rawValue)
    let shift = UInt64(NSEvent.ModifierFlags.shift.rawValue)
    let target = control | shift
    let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))

    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: target, modifierTarget: target)
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .keyDown, currentMods: target, modifierTarget: target)
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: 0, modifierTarget: target)
    )
  }
}

// MARK: - vkey 1.5.0 Phase 1 — Engine regression suite

/// Tests added in the 1.5.0 engine pass:
/// - Parametric tone placement for kiểu cũ vs kiểu mới (1.4)
/// - chuaNguyenAmUO recomputed after typo correction (1.1)
/// - Trie case-insensitive option (1.3)
/// - Late D toggle shared between Telex & VNI (1.6)
/// - pop() keeps tone when vowel remains (1.7)
final class EngineV150Tests: XCTestCase {

  private func telex(_ input: String) -> String {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in input { p.push(char: c) }
    return p.transformed
  }

  private func vni(_ input: String) -> String {
    let p = InputProcessor(method: .VNI)
    p.newWord()
    for c in input { p.push(char: c) }
    return p.transformed
  }

  // MARK: - 1.4 Tone placement parametric (kiểu cũ vs kiểu mới)

  /// Pure transform that bypasses `Defaults` so the test works under XCTest
  /// parallelization (the test plan has `parallelizable: true`, and `Defaults`
  /// is a global UserDefaults wrapper — read/write races would otherwise flap).
  ///
  /// Drives a Telex engine to produce a TiengVietState, then calls
  /// `TiengVietTransformer.transform` directly with an explicit `kieuMoi` flag.
  private func telexTransform(_ input: String, kieuMoi: Bool) -> String {
    let engine = Telex()
    var state = TiengVietState.empty
    for c in input {
      let result = engine.push(char: c, state: state)
      state = result.state
    }
    guard !state.isBlank else { return "" }

    var finalDauMu = state.dauMu
    let nguyenAmLower = String(state.thanhPhanTieng.nguyenAm).lowercased()
    if state.dauMu == .khongMu, nguyenAmLower == "uye", !state.thanhPhanTieng.phuAmCuoi.isEmpty {
      finalDauMu = .muUp
    }
    if state.dauMu == .khongMu, nguyenAmLower == "a",
       String(state.thanhPhanTieng.phuAmCuoi).lowercased() == "k" {
      finalDauMu = .muNgua
    }

    let finalDauThanh: DauThanh =
      (state.dauThanh == .bang)
        ? (state.thanhPhanTieng.uuTienDauThanh ?? state.dauThanh)
        : state.dauThanh

    return TiengVietTransformer.transform(
      thanhPhanTieng: state.thanhPhanTieng,
      dauThanh: finalDauThanh,
      dauMu: finalDauMu,
      gachD: state.gachD,
      kieuMoi: kieuMoi
    )
  }

  /// Pairs of (telex input, expected_kieuCu, expected_kieuMoi).
  ///
  /// - `oa`/`oe`/`uy` without a final consonant → tone splits between styles.
  /// - With a final consonant (or 3-vowel block) both styles place the tone on
  ///   the second vowel by phonological convention — so both columns match.
  ///
  /// Inputs that need breve (ă) use `aw`; inputs that need circumflex (ê/ô)
  /// use the doubled-vowel Telex shortcut (`ee`/`oo`).
  private let toneTable: [(input: String, kieuCu: String, kieuMoi: String)] = [
    // === oa — true split ===
    ("hoaf",   "hòa",   "hoà"),
    ("hoas",   "hóa",   "hoá"),
    ("xoar",   "xỏa",   "xoả"),
    ("loax",   "lõa",   "loã"),
    // === oa + final consonant — both styles agree ===
    ("hoanf",   "hoàn",   "hoàn"),
    ("toans",   "toán",   "toán"),
    ("hoawcj",  "hoặc",   "hoặc"),  // o + ă (aw) + c — breve required
    // === oe — true split ===
    ("hoer",   "hỏe",   "hoẻ"),
    ("loef",   "lòe",   "loè"),
    // === uy — true split ===
    ("thuys",  "thúy",   "thuý"),
    ("quys",   "quý",    "quý"),    // qu is initial consonant → only y is vowel; both place on y
    // === uy + final consonant — both styles agree ===
    ("huyeetj", "huyệt", "huyệt"),  // uyê + t
    ("khuyeenf","khuyền","khuyền"), // uyê + n + huyền
  ]

  func test_tonePlacement_parametric() throws {
    for c in toneTable {
      let gotCu = telexTransform(c.input, kieuMoi: false)
      XCTAssertEqual(gotCu, c.kieuCu, "kiểu cũ: \(c.input) → expected \(c.kieuCu), got \(gotCu)")
      let gotMoi = telexTransform(c.input, kieuMoi: true)
      XCTAssertEqual(gotMoi, c.kieuMoi, "kiểu mới: \(c.input) → expected \(c.kieuMoi), got \(gotMoi)")
    }
  }

  // MARK: - 1.1 chuaNguyenAmUO recomputed after typo correction

  func test_chuaNguyenAmUO_afterOuSwap() {
    // "bous" → typo recovery makes vowel "uo" → flag must be true so móc
    // applies to both u and o → "buố"
    let result = TiengVietParser.parse(Array("bou"), autoTypoCorrection: true)
    XCTAssertEqual(String(result.nguyenAm).lowercased(), "uo")
    XCTAssertTrue(
      result.chuaNguyenAmUO,
      "After 'ou'→'uo' typo swap, chuaNguyenAmUO must be re-derived from NguyenAmUO table"
    )
  }

  func test_chuaNguyenAmUO_afterEiSwap() {
    let result = TiengVietParser.parse(Array("vei"), autoTypoCorrection: true)
    XCTAssertEqual(String(result.nguyenAm).lowercased(), "ie")
    XCTAssertFalse(
      result.chuaNguyenAmUO,
      "After 'ei'→'ie' typo swap, chuaNguyenAmUO must be false (ie not in NguyenAmUO)"
    )
  }

  // MARK: - 1.2 Parser is pure (Defaults not read inside)

  func test_parser_pureWithoutDefaults() {
    let prev = Defaults[.autoTypoCorrection]
    defer { Defaults[.autoTypoCorrection] = prev }
    Defaults[.autoTypoCorrection] = false

    // Even with Defaults turned OFF, passing autoTypoCorrection:true must
    // produce the corrected result. Proves Parser doesn't read Defaults.
    let r = TiengVietParser.parse(Array("phuogn"), autoTypoCorrection: true)
    XCTAssertEqual(String(r.phuAmCuoi).lowercased(), "ng")
  }

  // MARK: - 1.3 Trie case-insensitive

  func test_trie_caseSensitiveByDefault() {
    let t = Trie()
    t.insert("hello")
    XCTAssertNil(t.findLongestPrefix(in: "HELLO"))
    XCTAssertEqual(t.findLongestPrefix(in: "hello world"), "hello")
  }

  func test_trie_caseInsensitiveFoldsBoth() {
    let t = Trie(caseInsensitive: true)
    t.insert("Hello")
    XCTAssertEqual(t.findLongestPrefix(in: "HELLO world"), "Hello",
                   "case-insensitive lookup returns the originally-stored casing")
    XCTAssertEqual(t.findLongestPrefix(in: "hello"), "Hello")
    XCTAssertTrue(t.contains("HELLO"))
    XCTAssertTrue(t.contains("hELLo"))
    XCTAssertFalse(t.contains("hel"), "prefix is not a stored end-of-word")
  }

  // MARK: - 1.6 Late D toggle works identically in Telex & VNI

  func test_lateDToggle_telex() {
    // "dinjhd" → "định" (j=nặng applied to i, then trailing d converts d→đ)
    XCTAssertEqual(telex("dinjhd"), "định")
  }

  func test_lateDToggle_vni() {
    // "dinh59" → "định" (5=nặng, trailing 9 toggles d→đ)
    XCTAssertEqual(vni("dinh59"), "định")
  }

  // MARK: - 1.7 pop() contract

  func test_pop_keepsToneWhenVowelRemains() {
    // "tois" → "tói" (state has tone .sac); pop one char → "to" — vowel
    // remains, but the trailing 's' was the tone trigger, so the popped
    // state must drop the tone since 's' was the tone-key (engine pops it
    // along with the visual character).
    //
    // What we DO want to lock: pop on a state with a vowel + tone that came
    // from withTone() (not from a Telex 's'/'f' key) keeps the tone.
    let s = TiengVietState.empty
      .push("t").push("o").push("i")
      .withTone(.sac)
    XCTAssertEqual(s.transformed, "tói")
    let popped = s.pop()
    XCTAssertEqual(popped.dauThanh, .sac, "tone is preserved when a vowel remains")
    XCTAssertEqual(popped.transformed, "tó")
  }

  func test_pop_clearsToneWhenNoVowel() {
    let s = TiengVietState.empty.push("t").push("a").withTone(.sac)
    XCTAssertEqual(s.transformed, "tá")
    let popped = s.pop().pop() // remove both 'a' and 't'
    XCTAssertTrue(popped.isBlank)
    XCTAssertEqual(popped.dauThanh, .bang)
    XCTAssertEqual(popped.dauMu, .khongMu)
  }

  // MARK: - 1.5 Double-horn applies only when first two vowels are u+o

  func test_doubleHorn_onUoOnly() {
    // "dduwowcj" → "được" — both u and o get the horn
    XCTAssertEqual(telex("dduwowcj"), "được")
  }

  func test_horn_doesNotDoubleApplyOnNonUo() {
    // "tuowi" should produce "tươi" (uoi vowel group is in NguyenAmUO → uo
    // prefix gets double-horn, i untouched). Regression guard for 1.5.
    XCTAssertEqual(telex("tuowi"), "tươi")
  }
}

// MARK: - vkey 1.5.0 Phase 2 — Platform regression suite

/// Phase 2 added an XMLParser-based appcast parser to replace fragile regex,
/// plus a few platform contracts (run-loop source ownership, file-monitor
/// non-UTF8 fallback). Only the appcast parser is testable without an event
/// tap / root permission — the other contracts are exercised by smoke runs.
final class AppcastParserTests: XCTestCase {

  private let sampleAppcast = #"""
  <?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
      <title>vkey</title>
      <item>
        <title>Version 1.5.0</title>
        <sparkle:version>15000</sparkle:version>
        <sparkle:shortVersionString>1.5.0</sparkle:shortVersionString>
        <enclosure
          url="https://example.com/vkey-1.5.0.dmg"
          sparkle:edSignature="abc"
          length="12345"
          type="application/octet-stream" />
      </item>
      <item>
        <title>Version 1.4.6</title>
        <sparkle:version>14600</sparkle:version>
        <sparkle:shortVersionString>1.4.6</sparkle:shortVersionString>
        <enclosure url="https://example.com/vkey-1.4.6.dmg" length="1" type="x" />
      </item>
    </channel>
  </rss>
  """#

  func test_parsesTopItemOnly() throws {
    let data = sampleAppcast.data(using: .utf8)!
    let summary = AppcastParser.parseTopItem(data: data)
    XCTAssertEqual(summary?.versionCode, "15000")
    XCTAssertEqual(summary?.shortVersion, "1.5.0")
    XCTAssertEqual(summary?.enclosureURL, "https://example.com/vkey-1.5.0.dmg")
  }

  func test_returnsNilOnGarbage() {
    let garbage = Data("not actually xml at all".utf8)
    XCTAssertNil(AppcastParser.parseTopItem(data: garbage))
  }

  func test_emptyItemIsTolerated() throws {
    let xml = #"""
    <?xml version="1.0"?>
    <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel><item></item></channel>
    </rss>
    """#
    let summary = AppcastParser.parseTopItem(data: Data(xml.utf8))
    XCTAssertNotNil(summary)
    XCTAssertNil(summary?.versionCode)
    XCTAssertNil(summary?.shortVersion)
    XCTAssertNil(summary?.enclosureURL)
  }
}

// MARK: - vkey 1.5.0 Phase 4 — Lexicon schema v5 + EnVnReference

final class LexiconV150Tests: XCTestCase {

  func test_lexiconPackage_decodesWithoutBilingualFields() throws {
    // Old (v4) JSON: no en_vn_mapping, no _meta. Must still decode.
    let oldJSON = #"""
    {
      "version": 4,
      "vietnamese": ["và", "của"],
      "english": ["of", "if"],
      "keep": ["lisa"]
    }
    """#
    let package = try JSONDecoder().decode(
      LexiconUpdatePackage.self,
      from: Data(oldJSON.utf8)
    )
    XCTAssertEqual(package.version, 4)
    XCTAssertEqual(package.vietnamese, ["và", "của"])
    XCTAssertNil(package.enVnMapping)
    XCTAssertNil(package.vnEnMapping)
    XCTAssertNil(package.meta)
  }

  func test_lexiconPackage_decodesV5Schema() throws {
    let newJSON = #"""
    {
      "_meta": {
        "version": 5,
        "generated_at": "2026-05-19",
        "sources": [
          {
            "name": "English Wiktionary",
            "url": "https://kaikki.org",
            "license": "CC BY-SA 4.0",
            "used_for": "en_vn_mapping{}"
          }
        ],
        "license_of_aggregate": "CC BY-SA 4.0 + GPL-3.0"
      },
      "version": 5,
      "vietnamese": ["và"],
      "english": ["of"],
      "keep": [],
      "en_vn_mapping": {
        "and": ["và"],
        "love": ["yêu", "tình yêu"]
      },
      "vn_en_mapping": {
        "máy tính": ["computer"]
      }
    }
    """#
    let package = try JSONDecoder().decode(
      LexiconUpdatePackage.self,
      from: Data(newJSON.utf8)
    )
    XCTAssertEqual(package.version, 5)
    XCTAssertEqual(package.enVnMapping?["and"], ["và"])
    XCTAssertEqual(package.enVnMapping?["love"], ["yêu", "tình yêu"])
    XCTAssertEqual(package.vnEnMapping?["máy tính"], ["computer"])
    XCTAssertEqual(package.meta?.version, 5)
    XCTAssertEqual(package.meta?.sources?.first?.license, "CC BY-SA 4.0")
  }

  func test_enVnReference_lookupIsCaseInsensitive() {
    let ref = EnVnReference()
    ref.load(
      en2vn: ["Love": ["yêu", "tình yêu"], "computer": ["máy tính"]],
      vn2en: ["máy tính": ["computer"]]
    )
    XCTAssertEqual(ref.lookupEnglish("LOVE"), ["yêu", "tình yêu"])
    XCTAssertEqual(ref.lookupEnglish("love"), ["yêu", "tình yêu"])
    XCTAssertEqual(ref.lookupEnglish("Computer"), ["máy tính"])
    XCTAssertNil(ref.lookupEnglish("unknown"))
    XCTAssertEqual(ref.lookupVietnamese("Máy Tính"), ["computer"])
  }

  func test_enVnReference_loadReplacesOldData() {
    let ref = EnVnReference()
    ref.load(en2vn: ["love": ["yêu"]], vn2en: nil)
    XCTAssertNotNil(ref.lookupEnglish("love"))
    ref.load(en2vn: ["work": ["công việc"]], vn2en: nil)
    XCTAssertNil(ref.lookupEnglish("love"))
    XCTAssertEqual(ref.lookupEnglish("work"), ["công việc"])
  }

  func test_entryCount_reflectsBothMaps() {
    let ref = EnVnReference()
    XCTAssertEqual(ref.entryCount.en, 0)
    XCTAssertEqual(ref.entryCount.vn, 0)
    ref.load(en2vn: ["a": ["A"], "b": ["B"]], vn2en: ["c": ["C"]])
    XCTAssertEqual(ref.entryCount.en, 2)
    XCTAssertEqual(ref.entryCount.vn, 1)
  }
}

// MARK: - vkey 1.5.0 Phase 9 — UsageStatistics

/// Tests use a per-test isolated `UsageStatistics(storageDir:)` so parallel
/// XCTest scheduling (the test plan has `parallelizable: true`) cannot
/// race on the singleton's in-memory or on-disk state.
final class UsageStatisticsTests: XCTestCase {

  private var stats: UsageStatistics!
  private var tmpDir: URL!

  override func setUp() {
    super.setUp()
    tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("vkey-stats-\(UUID().uuidString)", isDirectory: true)
    stats = UsageStatistics(storageDir: tmpDir)
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userKeepWords)
    Defaults.reset(.userDenyWords)
    Defaults[.statisticsEnabled] = true
  }

  override func tearDown() {
    stats = nil
    try? FileManager.default.removeItem(at: tmpDir)
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userKeepWords)
    Defaults.reset(.userDenyWords)
    super.tearDown()
  }

  func test_recordCommit_incrementsAggregates() throws {
    for _ in 0..<3 {
      stats.recordCommit(
        decision: .keepVietnamese,
        rawInput: "viet",
        transformed: "việt",
        appBundleId: "com.apple.dt.Xcode"
      )
    }
    // Let the async queue drain.
    let exp = expectation(description: "queue drain")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
    wait(for: [exp], timeout: 1.0)

    let summary = stats.currentWeekSummary()
    XCTAssertEqual(summary.wordsTotal, 3)
    XCTAssertEqual(summary.wordsKeptVietnamese, 3)
    XCTAssertTrue(summary.topVietnameseWords.contains { $0.word == "việt" && $0.count == 3 })
    XCTAssertTrue(summary.topApps.contains { $0.word == "com.apple.dt.Xcode" })
  }

  func test_disabledByDefaults_noOps() throws {
    Defaults[.statisticsEnabled] = false
    defer { Defaults[.statisticsEnabled] = true }

    stats.recordCommit(
      decision: .keepVietnamese,
      rawInput: "v", transformed: "v", appBundleId: nil
    )
    let exp = expectation(description: "queue drain")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
    wait(for: [exp], timeout: 1.0)

    XCTAssertEqual(stats.currentWeekSummary().wordsTotal, 0)
  }

  // The "weekly feedback" tests below exercise the pure-function core of the
  // promotion logic (`UsageStatistics.computePromotion(...)`) rather than the
  // instance method that touches global `Defaults`. The instance method is
  // a thin wrapper around the pure function — running the pure function
  // gives us deterministic results regardless of XCTest parallelization.

  func test_computePromotion_englishAboveThreshold() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: ["deploy": 5, "hello": 5],
      vnKeepStreak: [:],
      existingAllow: [], existingKeep: [], existingDeny: []
    )
    XCTAssertEqual(Set(result.allow), Set(["deploy", "hello"]))
    XCTAssertTrue(result.keep.isEmpty)
  }

  func test_computePromotion_vietnameseAboveThreshold() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: [:],
      vnKeepStreak: ["việt": 5, "không": 7, "alphaonly": 6],
      existingAllow: [], existingKeep: [], existingDeny: []
    )
    XCTAssertEqual(Set(result.keep), Set(["việt", "không"]),
                   "ascii-only word should be skipped since it has no Vietnamese marker")
  }

  func test_computePromotion_belowThresholdSkipped() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: ["deploy": 3],
      vnKeepStreak: ["việt": 4],
      existingAllow: [], existingKeep: [], existingDeny: [],
      threshold: 5
    )
    XCTAssertTrue(result.allow.isEmpty)
    XCTAssertTrue(result.keep.isEmpty)
  }

  func test_computePromotion_existingEntriesSkipped() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: ["deploy": 5, "release": 5],
      vnKeepStreak: ["việt": 5, "không": 5],
      existingAllow: ["deploy"],
      existingKeep: ["không"],
      existingDeny: []
    )
    XCTAssertEqual(result.allow, ["release"])
    XCTAssertEqual(result.keep, ["việt"])
  }

  func test_computePromotion_denyTrumpsEverything() {
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: ["deploy": 99],
      vnKeepStreak: ["việt": 99],
      existingAllow: [],
      existingKeep: [],
      existingDeny: ["deploy", "việt"]
    )
    XCTAssertTrue(result.allow.isEmpty,
                  "User has explicitly denied — promotion must skip even at high count")
    XCTAssertTrue(result.keep.isEmpty)
  }

  func test_computePromotion_capsBatchSize() {
    // Use letter-only labels so they pass the `isASCIIAlphabeticWord` guard
    // (digits would be rejected). Generate 20 distinct ASCII words.
    var streak: [String: Int] = [:]
    let letters = "abcdefghijklmnopqrst"
    for c in letters {
      streak["alpha\(c)"] = 5
    }
    XCTAssertEqual(streak.count, 20)
    let result = UsageStatistics.computePromotion(
      enRestoreStreak: streak, vnKeepStreak: [:],
      existingAllow: [], existingKeep: [], existingDeny: [],
      maxBatch: 5
    )
    XCTAssertEqual(result.allow.count, 5)
  }

  private func drainStatsQueue(_ stats: UsageStatistics) {
    stats.flushSynchronously()
    let exp = expectation(description: "queue drain")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
    wait(for: [exp], timeout: 1.0)
  }

  func test_removeFromCurrentWeek_vietnamesePhrase() {
    for _ in 0..<5 {
      stats.recordCommit(
        decision: .keepVietnamese,
        rawInput: "xin", transformed: "xin", appBundleId: nil
      )
      stats.recordCommit(
        decision: .keepVietnamese,
        rawInput: "chào", transformed: "chào", appBundleId: nil
      )
    }
    drainStatsQueue(stats)
    let before = stats.aggregatedTopVietnamesePhrases(minWords: 2, maxWords: 3, threshold: 3)
    XCTAssertTrue(before.contains { $0.word == "xin chào" && $0.count >= 3 })

    stats.removeFromCurrentWeek(word: "xin chào", category: .vietnamesePhrase)
    drainStatsQueue(stats)
    let after = stats.aggregatedTopVietnamesePhrases(minWords: 2, maxWords: 3, threshold: 3)
    XCTAssertFalse(after.contains { $0.word == "xin chào" })
  }

  func test_removeFromCurrentWeek_englishPhrase() {
    for _ in 0..<5 {
      stats.recordCommit(
        decision: .restoreRawEnglish("machine"),
        rawInput: "machine", transformed: "machine", appBundleId: nil
      )
      stats.recordCommit(
        decision: .restoreRawEnglish("learning"),
        rawInput: "learning", transformed: "learning", appBundleId: nil
      )
    }
    drainStatsQueue(stats)
    let before = stats.aggregatedTopEnglishPhrases(minWords: 2, maxWords: 3, threshold: 3)
    XCTAssertTrue(before.contains { $0.word == "machine learning" && $0.count >= 3 })

    stats.removeFromCurrentWeek(word: "machine learning", category: .englishPhrase)
    drainStatsQueue(stats)
    let after = stats.aggregatedTopEnglishPhrases(minWords: 2, maxWords: 3, threshold: 3)
    XCTAssertFalse(after.contains { $0.word == "machine learning" })
  }

  func test_removeTopEntry_english_addsUserDeny() {
    stats.recordCommit(
      decision: .restoreRawEnglish("lol"),
      rawInput: "lol", transformed: "lol", appBundleId: nil
    )
    drainStatsQueue(stats)
    XCTAssertTrue(stats.currentWeekSummary().topEnglishWords.contains { $0.word == "lol" })

    stats.removeTopEntry(word: "lol", category: .english)
    drainStatsQueue(stats)
    XCTAssertTrue(
      Defaults[.userDenyWords].contains { $0.normalizedDictionaryToken == "lol" },
      "Xóa từ EN từ top phải thêm deny list để không hiện lại"
    )
    XCTAssertFalse(stats.currentWeekSummary().topEnglishWords.contains { $0.word == "lol" })
  }
}

// MARK: - vkey 1.5.0 Phase 10 — UserDataMigration

final class UserDataMigrationTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Baseline so the test starts from known defaults.
    Defaults.reset(.userAllowWords)
    Defaults.reset(.userKeepWords)
    Defaults.reset(.userDenyWords)
    Defaults.reset(.macros)
    Defaults.reset(.perAppOverride)
  }

  func test_currentExport_capturesState() {
    Defaults[.userAllowWords] = ["alpha", "beta"]
    Defaults[.macros] = [Macro(from: "vn", to: "Việt Nam")]
    Defaults[.perAppOverride] = ["com.apple.Terminal": "off"]
    Defaults[.modifierOnlyTextToolsHotkey] = 123
    Defaults[.clipboardHistoryModifierOnlyHotkey] = 456
    Defaults[.autoUpdateEnabled] = false
    Defaults[.uiTheme] = .glass
    Defaults[.accentColorChoice] = .blue
    Defaults[.appearanceMode] = .dark
    Defaults[.predictionHUDLineOffset] = 7
    Defaults[.predictionHUDFontSize] = 19
    Defaults[.hudOpacityPercent] = 64
    Defaults[.autoCapitalizeEnabled] = false
    Defaults[.nonLatinIMEAutoDisable] = false
    Defaults[.freeMarkModeEnabled] = true
    Defaults[.cgEventRaceHardeningEnabled] = false
    Defaults[.cgEventFlushDelayMs] = 42
    var titleRule = WindowTitleRule()
    titleRule.name = "Docs"
    titleRule.bundleIdPrefix = "com.google.Chrome"
    titleRule.titleRegex = "Docs"
    titleRule.overrideState = .englishMode
    titleRule.disablePrediction = true
    Defaults[.windowTitleRules] = [titleRule]
    defer {
      Defaults.reset(.userAllowWords)
      Defaults.reset(.macros)
      Defaults.reset(.perAppOverride)
      Defaults.reset(.modifierOnlyTextToolsHotkey)
      Defaults.reset(.clipboardHistoryModifierOnlyHotkey)
      Defaults.reset(.autoUpdateEnabled)
      Defaults.reset(.uiTheme)
      Defaults.reset(.accentColorChoice)
      Defaults.reset(.appearanceMode)
      Defaults.reset(.predictionHUDLineOffset)
      Defaults.reset(.predictionHUDFontSize)
      Defaults.reset(.hudOpacityPercent)
      Defaults.reset(.autoCapitalizeEnabled)
      Defaults.reset(.nonLatinIMEAutoDisable)
      Defaults.reset(.freeMarkModeEnabled)
      Defaults.reset(.cgEventRaceHardeningEnabled)
      Defaults.reset(.cgEventFlushDelayMs)
      Defaults.reset(.windowTitleRules)
    }

    let export = UserDataMigration.currentExport(includeStatistics: false)
    XCTAssertEqual(export.schemaVersion, UserDataExport.currentSchemaVersion)
    XCTAssertEqual(export.userAllowWords?.sorted(), ["alpha", "beta"])
    XCTAssertEqual(export.macros?.first?.from, "vn")
    XCTAssertEqual(export.perAppOverride?["com.apple.Terminal"], "off")
    XCTAssertEqual(export.modifierOnlyTextToolsHotkey, 123)
    XCTAssertEqual(export.clipboardHistoryModifierOnlyHotkey, 456)
    XCTAssertEqual(export.autoUpdateEnabled, false)
    XCTAssertEqual(export.uiTheme, UITheme.glass.rawValue)
    XCTAssertEqual(export.accentColorChoice, AccentColorChoice.blue.rawValue)
    XCTAssertEqual(export.appearanceMode, AppearanceMode.dark.rawValue)
    XCTAssertEqual(export.predictionHUDLineOffset, 7)
    XCTAssertEqual(export.predictionHUDFontSize, 19)
    XCTAssertEqual(export.hudOpacityPercent, 64)
    XCTAssertEqual(export.autoCapitalizeEnabled, false)
    XCTAssertEqual(export.nonLatinIMEAutoDisable, false)
    XCTAssertEqual(export.freeMarkModeEnabled, true)
    XCTAssertEqual(export.cgEventRaceHardeningEnabled, false)
    XCTAssertEqual(export.cgEventFlushDelayMs, 42)
    XCTAssertEqual(export.windowTitleRules?.first?.name, "Docs")
    XCTAssertEqual(export.windowTitleRules?.first?.overrideState, .englishMode)
  }

  func test_encodeRoundTrip() throws {
    let export = UserDataMigration.currentExport(includeStatistics: false)
    let data = try UserDataMigration.encode(export)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(UserDataExport.self, from: data)
    XCTAssertEqual(decoded.schemaVersion, export.schemaVersion)
    XCTAssertEqual(decoded.appVersion, export.appVersion)
  }

  func test_autoUpdateEnabled_roundTrip() {
    Defaults[.autoUpdateEnabled] = false
    defer { Defaults.reset(.autoUpdateEnabled) }

    let export = UserDataMigration.currentExport(includeStatistics: false)
    XCTAssertEqual(export.autoUpdateEnabled, false)

    Defaults[.autoUpdateEnabled] = true
    UserDataMigration.importExport(export)
    XCTAssertEqual(Defaults[.autoUpdateEnabled], false)
  }

  func test_clipboardHistoryModifierOnlyHotkey_roundTrip() {
    Defaults[.clipboardHistoryModifierOnlyHotkey] = 999
    defer { Defaults.reset(.clipboardHistoryModifierOnlyHotkey) }

    let export = UserDataMigration.currentExport(includeStatistics: false)
    XCTAssertEqual(export.clipboardHistoryModifierOnlyHotkey, 999)

    Defaults[.clipboardHistoryModifierOnlyHotkey] = 0
    UserDataMigration.importExport(export)
    XCTAssertEqual(Defaults[.clipboardHistoryModifierOnlyHotkey], 999)
  }

  func test_importMerge_keepsExistingEntries() {
    Defaults[.userAllowWords] = ["existing"]
    defer { Defaults.reset(.userAllowWords) }

    let export = UserDataExport(
      schemaVersion: 1, exportedAt: Date(),
      appVersion: "1.5.0", appBuild: "15000",
      typingMethod: nil, newStyleTonePlacement: nil, autoTypoCorrection: nil,
      allowedZWJF: nil, hudEnabled: nil, modifierOnlyToggleHotkey: nil,
      smartSwitchEnabled: nil, smartSwitchApps: nil, perAppOverride: nil,
      spellCheckEnabled: nil, spellCheckInSentenceEnabled: nil,
      englishAutoRestoreEnabled: nil, restorePolicy: nil,
      suggestionEnabled: nil, autoApplyHighConfidenceSuggestion: nil,
      useEnVnReference: nil,
      personalDictionaryEnabled: nil,
      userAllowWords: ["fresh"], userKeepWords: nil, userDenyWords: nil,
      macros: nil,
      macroEnabled: nil, macrosSeeded: nil, defaultMacrosVersion: nil,
      appTheme: nil,
      autoPersonalDictFeedback: nil,
      statistics: nil
    )
    let changes = UserDataMigration.importExport(export, replaceLists: false)
    XCTAssertTrue(changes.contains { $0.contains("Từ cho phép: +1") })
    XCTAssertEqual(Set(Defaults[.userAllowWords]), Set(["existing", "fresh"]))
  }

  func test_importReplace_overwritesLists() {
    Defaults[.userAllowWords] = ["existing"]
    defer { Defaults.reset(.userAllowWords) }

    let export = UserDataExport(
      schemaVersion: 1, exportedAt: Date(),
      appVersion: "1.5.0", appBuild: "15000",
      typingMethod: nil, newStyleTonePlacement: nil, autoTypoCorrection: nil,
      allowedZWJF: nil, hudEnabled: nil, modifierOnlyToggleHotkey: nil,
      smartSwitchEnabled: nil, smartSwitchApps: nil, perAppOverride: nil,
      spellCheckEnabled: nil, spellCheckInSentenceEnabled: nil,
      englishAutoRestoreEnabled: nil, restorePolicy: nil,
      suggestionEnabled: nil, autoApplyHighConfidenceSuggestion: nil,
      useEnVnReference: nil,
      personalDictionaryEnabled: nil,
      userAllowWords: ["fresh"], userKeepWords: nil, userDenyWords: nil,
      macros: nil,
      macroEnabled: nil, macrosSeeded: nil, defaultMacrosVersion: nil,
      appTheme: nil,
      autoPersonalDictFeedback: nil,
      statistics: nil
    )
    UserDataMigration.importExport(export, replaceLists: true)
    XCTAssertEqual(Defaults[.userAllowWords], ["fresh"])
  }

  // MARK: - 2.0 (C1): Latency Benchmarks
  //
  // Đo thời gian hot-path xử lý ký tự để có baseline cho engine Swift
  // hiện tại + regression gate khi thêm tính năng / port sang Rust (C2).
  //
  // Đọc kết quả trong Xcode Test Navigator — mỗi method hiển thị baseline
  // (set baseline với ⌘+U sau khi run lần đầu để track regression > 10%).
  //
  // Mục tiêu cho 2.0:
  // - parse 1 ký tự (Telex)           ≤ 0.05 ms
  // - full word "tieengs" (7 keys)    ≤ 0.30 ms
  // - 1000 ký tự liên tục             ≤ 50 ms (≈ < 0.05 ms / char)
  // - lexicon lookup (`isEnglishWord`) ≤ 0.02 ms / từ

  func test_benchmark_telex_singleChar() {
    let processor = InputProcessor(method: .Telex)
    measure {
      for _ in 0..<1000 {
        processor.newWord()
        processor.push(char: "a")
      }
    }
  }

  func test_benchmark_telex_fullWord_tieengs() {
    // "tieengs" → "tiếng" — đầy đủ flow parse + transform + tone mark.
    let processor = InputProcessor(method: .Telex)
    measure {
      for _ in 0..<1000 {
        processor.newWord()
        for c in "tieengs" {
          processor.push(char: c)
        }
      }
    }
  }

  func test_benchmark_vni_fullWord() {
    // "tieng61s" theo VNI cho "tiếng" — so sánh với Telex.
    let processor = InputProcessor(method: .VNI)
    measure {
      for _ in 0..<1000 {
        processor.newWord()
        for c in "tieng61s" {
          processor.push(char: c)
        }
      }
    }
  }

  func test_benchmark_telex_1000chars_continuous() {
    // Simulate gõ liên tục 1000 ký tự — không reset newWord giữa chừng
    // ngoại trừ khi gặp ký tự ngoài. Stress test cho buffer + state.
    let processor = InputProcessor(method: .Telex)
    let text = String(repeating: "tiengs ", count: 143)  // ~1001 chars
    measure {
      processor.newWord()
      for c in text {
        if c == " " {
          processor.newWord()
        } else {
          processor.push(char: c)
        }
      }
    }
  }

  func test_benchmark_lexicon_lookup() {
    let lexicon = LexiconManager.shared
    lexicon.reload()
    let probes = [
      "hello", "world", "tieng", "viet", "good", "morning",
      "the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
    ]
    measure {
      for _ in 0..<1000 {
        for word in probes {
          _ = lexicon.isInstantRestoreEnglish(word)
        }
      }
    }
  }

  func test_benchmark_parse_only() {
    // Pure parse stage — strip wrapping I/O. So sánh với Rust core sau khi port.
    measure {
      for _ in 0..<10_000 {
        var state = TiengVietState.empty
        for c in "tieengs" {
          state = state.push(c)
        }
      }
    }
  }
}

// MARK: - ===========================================
// MARK: - Upstream Regression Suite (gonhanh.org & xkey)
// MARK: - ===========================================

/// Đối chiếu các bug fix của gonhanh.org (khaphanspace) & xkey (xmannv) để
/// chống hồi quy trên vkey. Đặt trong vkeyTests.swift vì project liệt kê file
/// test thủ công (không synchronized group) — file .swift riêng sẽ KHÔNG được
/// biên dịch vào target.
final class UpstreamRegressionTests: XCTestCase {

  private func telex(_ input: String) -> String {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in input { p.push(char: c) }
    return p.transformed
  }

  // ③ gonhanh v1.0.144: từ nguyên âm lặp (TOTO, MAMA, PAPA...) bị dư ký tự khi
  // auto-restore. Phải giữ nguyên, không sinh ký tự thừa.
  func testRepeatedSyllableWordsNoExtraChar() throws {
    XCTAssertEqual(telex("toto"), "toto")
    XCTAssertEqual(telex("lili"), "lili")
    XCTAssertEqual(telex("haha"), "haha")
  }

  // ⑦ xkey 20260504 / gonhanh v1.0.131: lịch sử từ phải bị xoá ở ranh giới
  // (Enter/Tab); chỉ Space mới giữ previousWordState cho re-edit.
  func testSpaceKeepsHistoryForReedit() throws {
    var buffer = WordBuffer()
    let engine = Telex()
    for c in "chaof" { buffer.push(char: c, engine: engine) }
    buffer.newWord(storePrevious: true)
    XCTAssertNotNil(buffer.previousWordState,
      "Space phải giữ history để Backspace re-edit từ vừa gõ")
  }

  func testEnterClearsHistoryNoCrossBoundaryRestore() throws {
    var buffer = WordBuffer()
    let engine = Telex()
    for c in "chaof" { buffer.push(char: c, engine: engine) }
    buffer.newWord(storePrevious: false)
    XCTAssertNil(buffer.previousWordState,
      "Enter phải xoá history — tránh Backspace khôi phục từ dòng trước (desync)")
  }
}

// MARK: - ===========================================
// MARK: - App Sending Strategy Tests
// MARK: - ===========================================

/// Đảm bảo các app có input model "khó" được map đúng strategy gửi event.
final class AppSendingStrategyTests: XCTestCase {

  private func isStepByStep(_ bundleId: String) -> Bool {
    if case .stepByStep = EventSimulator.getStrategy(for: bundleId) { return true }
    return false
  }

  // Launchpad / Spotlight search field chạy trong tiến trình Dock
  // (com.apple.dock). Phải dùng stepByStep — batch/hybrid khiến gõ tiếng Việt
  // bị loạn (lặp/mất chữ, dấu sai).
  func testLaunchpadDockUsesStepByStep() throws {
    XCTAssertTrue(isStepByStep("com.apple.dock"),
      "Launchpad/Dock search phải dùng stepByStep để gõ tiếng Việt không loạn")
  }

  // Regression: terminal vẫn stepByStep; app thường vẫn dùng default (không stepByStep).
  func testTerminalStepByStepAndDefaultUnaffected() throws {
    XCTAssertTrue(isStepByStep("com.apple.Terminal"))
    XCTAssertFalse(isStepByStep("com.apple.TextEdit"),
      "App native thường KHÔNG nên rơi vào stepByStep")
  }

  private func isAxDirect(_ bundleId: String) -> Bool {
    if case .axDirect = EventSimulator.getStrategy(for: bundleId) { return true }
    return false
  }

  // v2.12: Spotlight — synthetic backspace bị inline-autocomplete nuốt/đảo bất
  // kể delay (v2.10 stepByStep vẫn lỗi) → phải ghi thẳng AXValue (axDirect).
  func testSpotlightUsesAxDirect() throws {
    XCTAssertTrue(isAxDirect("com.apple.Spotlight"),
      "Spotlight phải dùng axDirect — mọi strategy event-based đều bị nuốt backspace")
    XCTAssertTrue(isAxDirect("com.apple.systemuiserver"))
  }

  /// v4.23 (F2): bundle ID upstream của Alacritty là "org.alacritty"; entry
  /// "io.alacritty" thừa kế từ lúc fork và chưa ai đối chiếu — cùng lớp lỗi
  /// "com.warp.Warp" (xem `testWarpBundleIdMatchesRealChannels`). Giữ CẢ HAI:
  /// khớp bằng `hasPrefix` nên entry sai chỉ là không bao giờ khớp, còn bỏ đi
  /// mà đoán sai chiều thì Alacritty lại âm thầm rơi về hybrid.
  func testAlacrittyMatchesBothBundleIds() throws {
    XCTAssertTrue(isStepByStep("org.alacritty"), "bundle ID upstream phải khớp")
    XCTAssertTrue(isStepByStep("io.alacritty"), "entry cũ vẫn phải khớp")
  }

  /// v4.23 (F2): "com.termius-dmg.mac" chỉ bao bản DMG; bản Mac App Store mang
  /// ID khác. Prefix rút gọn "com.termius" bao MỌI kênh mà không phá entry cũ
  /// (chuỗi DMG cũng bắt đầu bằng "com.termius").
  func testTermiusMatchesAllChannels() throws {
    XCTAssertTrue(isStepByStep("com.termius-dmg.mac"), "bản DMG (entry cũ)")
    XCTAssertTrue(isStepByStep("com.termius.mac"), "bản Mac App Store")
  }

  /// v4.23 (F3): app CHAT trước đây bị bỏ sót nên rơi hết về `.hybrid(800)`
  /// mặc định — ô soạn tin là contenteditable (Electron) hoặc text engine
  /// riêng (Qt), batch/hybrid gửi cụm backspace + retype async không sync với
  /// composition → rớt/lặp chữ đúng lớp lỗi Claude Desktop ("gửi"→"ửi",
  /// "điêu"→"điều" hụt). Chat là chỗ gõ tiếng Việt nhiều nhất nên đổi
  /// stepByStep (chậm hơn) là đánh đổi có chủ ý.
  func testChatAppsUseStepByStep() throws {
    for bundle in [
      "com.vng.zalo",                 // Electron (đã kiểm trên máy)
      "com.vng.zalo.zalocall",        // helper cùng prefix
      "com.tinyspeck.slackmacgap",    // Slack
      "com.hnc.Discord",              // Discord (bao cả Canary/PTB)
      "com.facebook.archon",          // Messenger
      "com.htl.plume",                // Plume (WKWebView Messenger bubble)
      "desktop.WhatsApp",             // WhatsApp bản Electron tải từ web
      "com.viber.osx",                // Viber (Qt/QML, không phải Electron)
    ] {
      XCTAssertTrue(isStepByStep(bundle), "\(bundle) phải dùng .stepByStep")
    }
  }

  /// Đối chứng cho F3: WhatsApp bản Mac App Store là Catalyst/AppKit thật nên
  /// CỐ Ý không thêm — nó phải giữ `.hybrid` mặc định. Nếu ai đó "dọn" bằng
  /// cách đổi prefix thành "WhatsApp" hay "net.whatsapp" thì test này vỡ.
  func testMASWhatsAppStaysOnDefaultHybrid() throws {
    XCTAssertFalse(isStepByStep("net.whatsapp.WhatsApp"),
      "bản Catalyst/AppKit không cần stepByStep")
    guard case .hybrid = EventSimulator.getStrategy(for: "net.whatsapp.WhatsApp") else {
      return XCTFail("bản MAS phải rơi về .hybrid mặc định")
    }
  }
}

// MARK: - ===========================================
// MARK: - English Instant-Restore Collision Tests
// MARK: - ===========================================

/// Đảm bảo danh sách 126 từ instant-restore không "ăn" mất các từ tiếng Việt
/// hợp lệ khi đang gõ tiếng Việt.
final class EnglishRestoreCollisionTests: XCTestCase {

  private func telex(_ input: String) -> String {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in input { p.push(char: c) }
    return p.transformed
  }

  // BUG: gõ Telex "queen" ở mode tiếng Việt trước đây ra "queen" (instant-restore
  // English) thay vì "quên" (từ VN hợp lệ). "queen"/"queens" đã bị loại khỏi
  // danh sách 126 từ instant-restore.
  func testQueenTypesAsVietnameseQuen() throws {
    XCTAssertEqual(telex("queen"), "quên",
      "Gõ Telex 'queen' ở mode tiếng Việt phải ra 'quên', không bị đè English")
  }

  // v2.9: audit toàn bộ danh sách instant-restore phát hiện thêm 18 từ EN mà
  // Telex thuần ra từ VIỆT hợp lệ & phổ biến. Đã loại khỏi instant-restore.
  func testCommonVietnameseWordsNotShadowedByEnglish() throws {
    XCTAssertEqual(telex("moon"), "môn")       // chuyên môn
    XCTAssertEqual(telex("noon"), "nôn")
    XCTAssertEqual(telex("soon"), "sôn")
    XCTAssertEqual(telex("theme"), "thêm")
    // v2.15: "meeting" giờ ra "meeting" (giữ tiếng Anh) thay vì "miêng" —
    // fix typo-correction "ei→ie" không còn nuốt phụ âm cuối "t" (cùng class
    // bug "Opus→uOs"). "miêng" vốn không phải từ Việt chuẩn nên đây là cải thiện.
    XCTAssertEqual(telex("meeting"), "meeting")
    XCTAssertEqual(telex("meets"), "mết")
    XCTAssertEqual(telex("boots"), "bốt")
    XCTAssertEqual(telex("tree"), "trê")
    XCTAssertEqual(telex("beer"), "bể")
    XCTAssertEqual(telex("loops"), "lốp")
  }

  // Regression: các từ EN mà transform KHÔNG ra từ VN hợp lệ vẫn giữ raw English.
  func testOtherEenWordsStillRestoreEnglish() throws {
    XCTAssertEqual(telex("green"), "green")
    XCTAssertEqual(telex("screen"), "screen")
    // Nhóm 2 (giữ lại theo quyết định — từ Anh phổ biến): vẫn restore English.
    XCTAssertEqual(telex("three"), "three")
    XCTAssertEqual(telex("these"), "these")
  }
}

// MARK: - ===========================================
// MARK: - ZWJF-Off Classic Telex Tests (v2.13)
// MARK: - ===========================================

/// Khi TẮT "cho phép âm tiết đầu w/z/j/f" (`allowedZWJF=false`), w trở thành
/// phím dấu Telex cổ điển: "w"→ư, "tw"→tư, "nhw"→như. Trước v2.13 w vẫn bị
/// giữ nguyên là "w" (engine thiếu nhánh w-không-nguyên-âm, và bảng
/// impossible-prefix khoá "tw/dw/sw/wr" thành raw English).
final class ZWJFOffTelexTests: XCTestCase {

  private func telex(_ input: String) -> String {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in input { p.push(char: c) }
    return p.transformed
  }

  private func withZWJF(_ enabled: Bool, run: () throws -> Void) rethrows {
    let old = Defaults[.allowedZWJF]
    Defaults[.allowedZWJF] = enabled
    defer { Defaults[.allowedZWJF] = old }
    try run()
  }

  func testClassicTelexW_whenZWJFOff() throws {
    try withZWJF(false) {
      XCTAssertEqual(telex("w"), "ư", "w đứng không phải ra ư khi ZWJF tắt")
      XCTAssertEqual(telex("W"), "Ư")
      XCTAssertEqual(telex("tw"), "tư", "tw phải ra tư — prefix 'tw' không được khoá raw")
      XCTAssertEqual(telex("nhw"), "như")
      XCTAssertEqual(telex("twf"), "từ")
      XCTAssertEqual(telex("dwa"), "dưa")
    }
  }

  // Regression: ZWJF BẬT (mặc định) → w giữ nguyên cho loanword.
  func testWStaysRawForLoanwords_whenZWJFOn() throws {
    try withZWJF(true) {
      XCTAssertEqual(telex("web"), "web")
      XCTAssertEqual(telex("w"), "w")
    }
  }

  /// v4.23 (E12): gõ `w` LẦN HAI phải huỷ sạch, không để lại chữ 'u' giả.
  ///
  /// Telex cổ điển biến `w` đứng một mình thành `ư` bằng cách TỰ SINH chữ 'u'
  /// rồi đặt móc. Phím `w` kế tiếp trước đây chỉ toggle TẮT móc, nên chữ 'u'
  /// tự sinh ở lại: "ww" ra "uw", "www" ra "uww", "tww" ra "tuw" — gõ URL
  /// ("www.") thành rác. Nay `w` thứ hai rơi xuống push thô nên chuỗi hiện
  /// đúng phím đã gõ.
  ///
  /// Giới hạn đã biết: KHÔNG ra được đúng một chữ "w" cho ca "ww" vì
  /// `WordBuffer.shouldAppendRawKey` đòi `new.count == old.count`, chuỗi rỗng
  /// không được nối phím thô. "ww" (đúng những phím đã gõ) là kết quả tốt nhất
  /// đạt được mà không đụng InputProcessor.
  func testDoubleWCancelsWithoutGhostU_whenZWJFOff() throws {
    try withZWJF(false) {
      XCTAssertEqual(telex("ww"), "ww", "w thứ hai huỷ, không để lại 'u' tự sinh")
      XCTAssertEqual(telex("www"), "www", "gõ 'www.' phải ra 'www', không phải 'uww'")
      XCTAssertEqual(telex("tww"), "tww", "sau phụ âm cũng vậy — không phải 'tuw'")

      // Đối chứng: mọi đường móc HỢP LỆ phải nguyên vẹn.
      XCTAssertEqual(telex("w"), "ư")
      XCTAssertEqual(telex("tw"), "tư")
      XCTAssertEqual(telex("nhw"), "như")
      // 'u' do NGƯỜI DÙNG gõ thì `w` vẫn là lệnh móc, và `w` thứ hai vẫn là
      // đường huỷ móc CŨ (chữ 'u' thật ở lại) — không được nhầm hai ca.
      XCTAssertEqual(telex("uw"), "ư")
      XCTAssertEqual(telex("uww"), "uw")
    }
  }
}

// MARK: - ===========================================
// MARK: - AX-Direct Delete-Start Tests (v2.14)
// MARK: - ===========================================

/// `axDeleteStart` lùi từ caret theo CỤM grapheme trong không gian UTF-16 —
/// an toàn với app lưu NFD (ô = o + combining ◌̂) như Spotlight.
final class AXDeleteStartTests: XCTestCase {

  func testNFCSimple() throws {
    // "gõ" NFC: g(1) + õ(1) = length 2; xoá 1 → lùi về sau 'g'
    let s = "g\u{00F5}"
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 2, backspaceCount: 1, usesNFC: true), 1)
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 2, backspaceCount: 2, usesNFC: true), 0)
  }

  func testNFDCombiningMark() throws {
    // "gõ" NFD: g(1) + o(1) + ◌̃(1) = length 3; xoá 1 phải lùi NGUYÊN cụm o+◌̃ → 1
    let s = "go\u{0303}"
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 1, usesNFC: true), 1)
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 2, usesNFC: true), 0)
  }

  func testClampsAtZeroAndHandlesEmptyValue() throws {
    XCTAssertEqual(EventSimulator.axDeleteStart("", caretUTF16: 0, backspaceCount: 3, usesNFC: true), 0)
    XCTAssertEqual(EventSimulator.axDeleteStart("ab", caretUTF16: 2, backspaceCount: 99, usesNFC: true), 0)
    XCTAssertEqual(EventSimulator.axDeleteStart("ab", caretUTF16: 2, backspaceCount: 99, usesNFC: false), 0)
  }

  /// `usesNFC: false` phải lùi theo SCALAR, khớp số đếm của `calcKeyStrokesNFD`.
  /// Trước đây luôn lùi theo grapheme, nên khi caller đưa số đếm scalar mà
  /// strategy bị `sendReplacement` ép sang axDirect (overlaySearchIsFocused)
  /// thì mỗi dấu thanh làm lùi dư một cụm → xoá lố sang ký tự đứng trước.
  func testNFDScalarAxisDeletesOneScalarPerUnit() throws {
    // "gõ" NFD: g(1) + o(1) + ◌̃(1) = length 3.
    let s = "go\u{0303}"
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 1, usesNFC: false), 2,
      "1 scalar = chỉ dấu ◌̃, base 'o' còn lại")
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 2, usesNFC: false), 1,
      "2 scalar = ◌̃ + o, giữ 'g'")
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 3, usesNFC: false), 0)

    // Trục scalar khớp đúng số mà calcKeyStrokesNFD sinh ra cho cùng phép thay.
    let (bs, _) = EventSimulator.calcKeyStrokes(from: "gõ", to: "gó", usesNFC: false)
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: bs, usesNFC: false),
      1, "axDirect xoá đúng phần mà calcKeyStrokesNFD đã đếm")
  }

  /// Surrogate pair là MỘT scalar — không được lùi nửa cặp.
  func testNFDScalarAxisKeepsSurrogatePairIntact() throws {
    let s = "a😀"  // 'a'(1) + emoji(2 UTF-16 unit) = length 3
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 1, usesNFC: false), 1,
      "Lùi 1 scalar phải nuốt trọn surrogate pair")
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 2, usesNFC: false), 0)
  }
}


// MARK: - ===========================================
// MARK: - Vowel Typo-Correction Final-Consonant Guard (v2.15)
// MARK: - ===========================================

/// Typo-correction "ou→uo" / "ei→ie" / "aoi→oai" KHÔNG được nuốt phụ âm cuối.
/// Bug "Opus"→"uOs": gõ "opu" cho o=nguyênÂm, p=phụÂmCuối, u=conLai; reparse
/// "uo" nuốt mất 'p'. Fix: chỉ reparse khi phuAmCuoi rỗng.
final class VowelTypoFinalConsonantTests: XCTestCase {
  private func telex(_ s: String) -> String {
    let p = InputProcessor(method: .Telex); p.newWord()
    for c in s { p.push(char: c) }
    return p.transformed
  }

  func testOpusNotMangled() throws {
    XCTAssertEqual(telex("opu"), "opu", "o + phụ âm cuối p + u: KHÔNG được thành 'uo'")
    XCTAssertEqual(telex("opus"), "opus")
    XCTAssertEqual(telex("Opus"), "Opus")
    XCTAssertEqual(telex("OPUS"), "OPUS")
  }

  // Regression: "bous"→"buốt" path (phuAmCuoi rỗng) PHẢI vẫn hoạt động.
  func testBuosStillWorks() throws {
    // "buoocs" = buôc + sắc → "buốc"; "bous" reparse uo cho phép gõ "buốt"
    XCTAssertEqual(telex("buoojt"), "buột", "uo + mũ + nặng + t = buột (path uo vẫn sống)")
    XCTAssertEqual(telex("muoons"), "muốn")
  }

  // Regression: "veit"→"việt" path (phuAmCuoi rỗng khi reparse) vẫn hoạt động.
  func testVeitStillWorks() throws {
    XCTAssertEqual(telex("vieetj"), "việt")
  }

  // FIX (loanword "source"→"suorce"): từ tiếng Anh có "ou" + đuôi rác KHÔNG
  // được swap thành "uo" khi gõ ở chế độ tiếng Việt. Trước fix: "source" →
  // "suorce" (phải chuyển EN mới gõ được). Sau fix: giữ nguyên.
  func testEnglishOuWordsNotMangled() throws {
    XCTAssertEqual(telex("source"), "source", "ou + 'rce' rác → KHÔNG thành 'suorce'")
    XCTAssertEqual(telex("Source"), "Source")
    XCTAssertEqual(telex("count"), "count", "ou + n(cuối) + 't' rác → giữ nguyên")
    XCTAssertEqual(telex("double"), "double")
    // Prefix giữa chừng: không swap sou→suo (root cause Suorce trên màn hình).
    XCTAssertEqual(telex("sou"), "sou")
    XCTAssertEqual(telex("Sou"), "Sou")
    XCTAssertEqual(telex("cou"), "cou")
    XCTAssertEqual(telex("you"), "you")
  }

  // FIX: cùng guard conLai.isEmpty áp cho luật "ei→ie" và "aoi→oai".
  // Dùng parse() để kiểm tra cấu trúc, độc lập với xử lý dấu thanh.
  func testEiAndAoiLoanwordsNotMangled() throws {
    // "their": e + leftover "ir" → KHÔNG swap thành "ie" (còn 'r' rác).
    let their = TiengVietParser.parse(Array("their"))
    XCTAssertEqual(String(their.nguyenAm), "e", "their giữ 'e', không swap 'ie'")
    XCTAssertEqual(String(their.conLai), "ir")
    // "veil": e + "il" → KHÔNG swap (còn 'l').
    let veil = TiengVietParser.parse(Array("veil"))
    XCTAssertEqual(String(veil.nguyenAm), "e", "veil giữ 'e', không swap 'viel'")
    // Regression: "veit" vẫn swap (conLai rỗng) → "ie" + "t".
    let veit = TiengVietParser.parse(Array("veit"))
    XCTAssertEqual(String(veit.nguyenAm), "ie")
    XCTAssertEqual(String(veit.phuAmCuoi), "t")
    // Regression: "haoi" vẫn swap → "oai".
    let haoi = TiengVietParser.parse(Array("haoi"))
    XCTAssertEqual(String(haoi.nguyenAm), "oai")
  }
}

// MARK: - ===========================================
// MARK: - NFD vs NFC Diffing Tests
// MARK: - ===========================================

final class NFDvsNFCDiffingTests: XCTestCase {
  func testPopBehaviorNFCvsNFD() throws {
    // 1. NFC app (default for Apple Notes)
    let nfcProcessor = InputProcessor(method: .Telex)
    nfcProcessor.changeActiveApp("com.apple.Notes")
    nfcProcessor.push(char: "g")
    nfcProcessor.push(char: "o")
    nfcProcessor.push(char: "o")  // "gô"
    XCTAssertEqual(nfcProcessor.transformed, "gô")
    
    // Pop (delete last 'o' to get "go")
    let (nfcBs, nfcDiff) = nfcProcessor.pop(usesNFC: nfcProcessor.usesNFCForFocusedField())
    XCTAssertEqual(nfcBs, 1) // deletes "ô"
    XCTAssertEqual(nfcDiff, ["o"]) // re-types "o"
    
    // 2. NFD app (Electron). 4.21: Chrome KHÔNG còn dùng được làm ví dụ NFD —
    // web content của trình duyệt đã chuyển sang NFC. Electron vẫn giữ NFD.
    let nfdProcessor = InputProcessor(method: .Telex)
    nfdProcessor.changeActiveApp("com.tinyspeck.slackmacgap")
    nfdProcessor.push(char: "g")
    nfdProcessor.push(char: "o")
    nfdProcessor.push(char: "o")  // "gô"
    XCTAssertEqual(nfdProcessor.transformed, "gô")
    
    // Pop (delete last 'o' to get "go")
    let (nfdBs, nfdDiff) = nfdProcessor.pop(usesNFC: nfdProcessor.usesNFCForFocusedField())
    XCTAssertEqual(nfdBs, 0, "NFD should let the OS handle backspace (numBackspaces = 0)")
    XCTAssertEqual(nfdDiff, [], "NFD should not need to retype any character")
  }

  func testGeminiAppUsesNFC() throws {
    // v3.6: bundle ID THẬT của Gemini app là com.google.GeminiMacOS
    // (v3.4 ghi nhầm com.google.gemini → rơi về NFD → "nhập" → "nḥ̂p").
    // Check lowercased prefix nên cả hai biến thể đều phải pass.
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.google.GeminiMacOS"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.google.gemini"))
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.google.Chrome"))

    let processor = InputProcessor(method: .Telex)
    processor.changeActiveApp("com.google.GeminiMacOS")

    // Type "nhân"
    processor.push(char: "n")
    processor.push(char: "h")
    processor.push(char: "a")
    processor.push(char: "a")
    processor.push(char: "n")
    XCTAssertEqual(processor.transformed, "nhân")
  }

  func testNativeTextEditorsUseNFCGraphemeStorage() throws {
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.sublimetext.4"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.sublimetext.3"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.barebones.bbedit"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.macromates.TextMate"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "org.vim.MacVim"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "net.nemetschek.vectorworks.2024"))
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.google.Chrome"))
  }

  /// v4.2: Sublime/BBEdit lưu grapheme NFC — pop phải giống Notes (bs=1),
  /// không phải NFD (bs=0) vì NFD diff gây backspace thừa / nuốt newline.
  func testSublimeTextPopUsesNFCGraphemeBackspace() throws {
    let sublime = InputProcessor(method: .Telex)
    sublime.changeActiveApp("com.sublimetext.4")
    sublime.push(char: "g")
    sublime.push(char: "o")
    sublime.push(char: "o")
    XCTAssertEqual(sublime.transformed, "gô")
    let (sublimeBs, sublimeDiff) = sublime.pop(usesNFC: sublime.usesNFCForFocusedField())
    XCTAssertEqual(sublimeBs, 1, "Sublime must NFC-pop like Notes")
    XCTAssertEqual(sublimeDiff, ["o"])

    // Đối chứng NFD. 4.21: dùng Electron thay Chrome — trình duyệt đã sang NFC.
    let electron = InputProcessor(method: .Telex)
    electron.changeActiveApp("com.tinyspeck.slackmacgap")
    electron.push(char: "g")
    electron.push(char: "o")
    electron.push(char: "o")
    let (electronBs, electronDiff) = electron.pop(usesNFC: electron.usesNFCForFocusedField())
    XCTAssertEqual(electronBs, 0, "Electron vẫn NFD-pop")
    XCTAssertEqual(electronDiff, [])
  }

  /// v4.15: emit-form phải khớp field-form. `emittedCharacters` precompose khi
  /// field NFC (ô tìm kiếm khớp text precomposed) và GIỮ NGUYÊN combining mark
  /// khi field NFD — ép NFC vào field NFD là gốc bug "gửi"→"ửi" (mất chữ đầu).
  func testEmittedCharactersFollowsFieldNormalization() throws {
    let nfd = Array("e\u{0301}o\u{0300}")  // "é" + "ò" dạng NFD (base + combining)
    XCTAssertNotEqual(
      Array(String(nfd).utf16),
      Array("éò".utf16),
      "Sanity: NFD và NFC khác nhau trước khi chuẩn hoá"
    )

    // Field NFC → precompose: "éò" mỗi ký tự 1 UTF-16 unit, không còn combining.
    let nfc = EventSimulator.emittedCharacters(nfd, normalizeToNFC: true)
    XCTAssertEqual(String(nfc), "éò")
    XCTAssertEqual(String(nfc).utf16.count, 2)
    XCTAssertFalse(
      String(nfc).unicodeScalars.contains { $0.value == 0x0301 || $0.value == 0x0300 },
      "Field NFC không được phát combining mark"
    )

    // Field NFD → giữ NGUYÊN combining mark (số scalar không đổi → khớp backspace).
    let raw = EventSimulator.emittedCharacters(nfd, normalizeToNFC: false)
    XCTAssertEqual(raw, nfd)
    XCTAssertTrue(
      String(raw).unicodeScalars.contains { $0.value == 0x0301 },
      "Field NFD phải giữ combining mark như calcKeyStrokesNFD đã tính"
    )
  }

  func testAutoCapitalizeAfterEnterSwallowsLowercaseKeyEvent() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 36) // Enter
    let result = typeLetter(processor, code: 0) // a
    XCTAssertSwallowed(result, "Auto-capitalize must synthesize uppercase, not pass lowercase key")
    XCTAssertEqual(processor.transformed, "A")
  }

  func testAutoCapitalizeAfterPeriodAndSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 49) // space
    let result = typeLetter(processor, code: 7) // x
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "X")
  }

  func testAutoCapitalizeDoesNotCapitalizeImmediatelyAfterPeriodWithoutSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    let result = typeLetter(processor, code: 17) // t
    XCTAssertPassThrough(result, "No space after period → pass-through lowercase")
    XCTAssertEqual(processor.transformed, "t")
  }

  func testAutoCapitalizeDoesNotCapitalizeImmediatelyAfterExclamationWithoutSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 18, shift: true) // !
    let result = typeLetter(processor, code: 17) // t
    XCTAssertPassThrough(result)
    XCTAssertEqual(processor.transformed, "t")
  }

  func testAutoCapitalizeDoesNotCapitalizeImmediatelyAfterQuestionWithoutSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 44, shift: true) // ?
    let result = typeLetter(processor, code: 17) // t
    XCTAssertPassThrough(result)
    XCTAssertEqual(processor.transformed, "t")
  }

  func testAutoCapitalizeAfterExclamationAndSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 18, shift: true) // !
    typeKey(processor, code: 49) // space
    let result = typeLetter(processor, code: 7) // x
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "X")
  }

  func testAutoCapitalizeAfterQuestionAndSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 44, shift: true) // ?
    typeKey(processor, code: 49) // space
    let result = typeLetter(processor, code: 7) // x
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "X")
  }

  func testAutoCapitalizeAfterPeriodAndDoubleSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 49) // space
    typeKey(processor, code: 49) // second space
    let result = typeLetter(processor, code: 7) // x
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "X")
  }

  func testAutoCapitalizePreservesDecimalNumbers() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 20) // 3
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 18) // 1
    XCTAssertEqual(processor.transformed, "1")
    typeKey(processor, code: 21) // 4
    XCTAssertEqual(processor.transformed, "14")
  }

  func testAutoCapitalizePreservesAbbreviationWithoutSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 46) // m
    typeKey(processor, code: 15) // r
    typeKey(processor, code: 47) // .
    let result = typeLetter(processor, code: 1) // s (mr.smith)
    XCTAssertPassThrough(result, "No space after period → pass-through lowercase")
    XCTAssertEqual(processor.transformed, "s")
  }

  func testAutoCapitalizeAfterPeriodAndEnter() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 36) // Enter
    let result = typeLetter(processor, code: 17) // t
    XCTAssertSwallowed(result, "Enter after period still marks sentence start")
    XCTAssertEqual(processor.transformed, "T")
  }

  func testAutoCapitalizeVietnameseAfterPeriodAndSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 49) // space
    let result = typeLetter(processor, code: 9) // v
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "V")
  }

  func testAutoCapitalizePreservesDomainSegments() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()

    for code: UInt16 in [5, 31, 31, 5, 37, 14] { typeKey(processor, code: code) }
    XCTAssertEqual(processor.transformed, "google")

    typeKey(processor, code: 47) // .
    typeKey(processor, code: 8) // c
    XCTAssertEqual(processor.transformed, "c", "First letter after dot must stay lowercase")
    typeKey(processor, code: 31) // o
    typeKey(processor, code: 46) // m
    XCTAssertEqual(processor.transformed, "com")

    typeKey(processor, code: 47) // .
    typeKey(processor, code: 9) // v
    XCTAssertEqual(processor.transformed, "v", "Second dot segment must stay lowercase")
    typeKey(processor, code: 45) // n
    XCTAssertEqual(processor.transformed, "vn")
  }

  /// v4.23 (P4): nhánh auto-capitalize phải phát KẾT QUẢ ENGINE, không phát ký
  /// tự thô vừa viết hoa.
  ///
  /// Nhánh cũ gửi thẳng `[newChar]` với giả định "engine không bao giờ đụng ký
  /// tự ĐẦU của từ". Giả định đó SAI khi `allowedZWJF` tắt: Telex cổ điển biến
  /// `w` đứng một mình thành `ư`. Khi đó lệnh gửi đi là "W" trong khi bộ đệm
  /// tin rằng màn hình có "Ư" — mà event gốc đã bị nuốt (`return nil`) — nên
  /// mọi phím sau diff trên nền sai và cả từ hỏng.
  ///
  /// PHẠM VI: `sendTypedReplacement` là private và transport post CGEvent thật,
  /// nên test không đọc được chuỗi đã phát. Cái khoá được ở đây là ĐIỀU KIỆN
  /// TIÊN QUYẾT của lỗi (engine thật sự đổi ký tự đầu) cùng cặp
  /// `lastTransformed → transformed` mà nhánh mới lấy diff, và số học của diff
  /// đó khác hẳn ký tự thô.
  func testAutoCapitalizeEmitsEngineResultNotRawKey() throws {
    let savedZWJF = Defaults[.allowedZWJF]
    Defaults[.autoCapitalizeEnabled] = true
    Defaults[.allowedZWJF] = false
    defer {
      Defaults.reset(.autoCapitalizeEnabled)
      Defaults[.allowedZWJF] = savedZWJF
    }

    let processor = makeNotesProcessor()
    typeKey(processor, code: 36) // Enter → chờ viết hoa
    let result = typeLetter(processor, code: 13) // w
    XCTAssertSwallowed(result, "Auto-capitalize nuốt event gốc — vkey phải tự phát")

    XCTAssertEqual(processor.transformed, "Ư",
      "Telex cổ điển: 'W' đầu từ thành 'Ư' — engine ĐỤNG vào ký tự đầu")
    XCTAssertEqual(processor.lastTransformed, "",
      "Diff phải lấy từ trạng thái TRƯỚC push (rỗng ở đầu từ)")

    let (backspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: processor.lastTransformed, to: processor.transformed, usesNFC: true)
    XCTAssertEqual(backspaces, 0)
    XCTAssertEqual(diffChars, ["Ư"], "Phải phát 'Ư' — nhánh cũ phát 'W' và lệch đệm")
    XCTAssertNotEqual(diffChars, ["W"])
  }

  /// Đối chứng P4: ca thường (engine không đụng ký tự đầu) phải cho ra ĐÚNG
  /// một ký tự như trước — công thức mới không được làm phình diff.
  func testAutoCapitalizeOrdinaryLetterStillEmitsSingleChar() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }

    let processor = makeNotesProcessor()
    typeKey(processor, code: 36) // Enter
    let result = typeLetter(processor, code: 9) // v
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "V")

    let (backspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: processor.lastTransformed, to: processor.transformed, usesNFC: true)
    XCTAssertEqual(backspaces, 0)
    XCTAssertEqual(diffChars, ["V"])
  }

  // MARK: - Auto-capitalize helpers
  // CGEvent virtualKey codes below assume US keyboard layout (KeyboardUS).
  //
  // Never use XCTAssertNotNil / XCTAssertNil directly on `Unmanaged<CGEvent>?` —
  // XCTest bridges the value for failure messages and can SIGABRT the test host.

  private func XCTAssertPassThrough(
    _ result: Unmanaged<CGEvent>?,
    _ message: @autoclosure () -> String = "Expected CGEvent pass-through",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(result != nil, message(), file: file, line: line)
  }

  private func XCTAssertSwallowed(
    _ result: Unmanaged<CGEvent>?,
    _ message: @autoclosure () -> String = "Expected CGEvent to be swallowed",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(result == nil, message(), file: file, line: line)
  }

  private func makeNotesProcessor() -> InputProcessor {
    let processor = InputProcessor(method: .Telex)
    processor.changeActiveApp("com.apple.Notes")
    return processor
  }

  private func typeKey(
    _ processor: InputProcessor,
    code: UInt16,
    shift: Bool = false
  ) {
    _ = typeKeyReturning(processor, code: code, shift: shift)
  }

  @discardableResult
  private func typeKeyReturning(
    _ processor: InputProcessor,
    code: UInt16,
    shift: Bool = false
  ) -> Unmanaged<CGEvent>? {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
    event.flags = shift ? [.maskShift] : []
    return processor.handleEvent(event: event)
  }

  @discardableResult
  private func typeLetter(
    _ processor: InputProcessor,
    code: UInt16
  ) -> Unmanaged<CGEvent>? {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
    event.flags = []
    return processor.handleEvent(event: event)
  }

  /// v3.6: diff NFD không bao giờ được mở đầu bằng combining mark trần —
  /// nếu có, ranh giới lùi về đầu cụm grapheme (xoá + retype nguyên cụm).
  func testNFDDiffNeverStartsWithBareCombiningMark() throws {
    // "nhâ" → "nhậ": NFD to = [n,h,a,◌̣,◌̂] — diff thô là [◌̣,◌̂] (dấu trần).
    // Phải snap về đầu cụm: xoá 2 scalar (◌̂, a), retype "ậ" hoàn chỉnh.
    let (bs1, diff1) = EventSimulator.calcKeyStrokesNFD(from: "nhâ", to: "nhậ")
    XCTAssertEqual(bs1, 2)
    XCTAssertEqual(diff1, ["ậ"])

    // Chiều ngược (xoá dấu nặng): cũng phải retype nguyên cụm "â".
    let (bs2, diff2) = EventSimulator.calcKeyStrokesNFD(from: "nhậ", to: "nhâ")
    XCTAssertEqual(bs2, 3)
    XCTAssertEqual(diff2, ["â"])

    // Thêm dấu vào chữ không dấu: "đi" → "đị" — retype "ị" hoàn chỉnh.
    let (bs3, diff3) = EventSimulator.calcKeyStrokesNFD(from: "đi", to: "đị")
    XCTAssertEqual(bs3, 1)
    XCTAssertEqual(diff3, ["ị"])

    // Diff RỖNG (chỉ xoá) giữ nguyên — không snap, pop vẫn nhường OS xử lý.
    let (bs4, diff4) = EventSimulator.calcKeyStrokesNFD(from: "gô", to: "go")
    XCTAssertEqual(bs4, 1)
    XCTAssertEqual(diff4, [])
  }

  /// v3.9: kiểu diff theo FieldKind trong app nhóm NFD.
  /// - webContent → NFD (pop "gô"→"go" nhường OS = (0, []))
  /// - nativePanel (NSSavePanel) → NFC = (1, ["o"])
  /// - windowField → NFC = (1, ["o"]) — dùng kèm axDirect ở runtime
  ///
  /// 4.21: đổi ví dụ từ Chrome sang Electron. Trình duyệt giờ NFC ở MỌI
  /// fieldKind nên không còn phân biệt được ba nhánh này; Electron thì còn.
  func testFieldKindDiffSelectionInNFDGroupApp() throws {
    let processor = InputProcessor(method: .Telex)
    processor.changeActiveApp("com.tinyspeck.slackmacgap")

    // Web content: NFD — pop "gô"→"go" nhường OS (0, []).
    processor.focusedFieldKind = .webContent
    processor.push(char: "g")
    processor.push(char: "o")
    processor.push(char: "o")
    XCTAssertEqual(processor.transformed, "gô")
    let (webBs, webDiff) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(webBs, 0)
    XCTAssertEqual(webDiff, [])

    // Save panel (hộp thoại modal native): NFC — pop "gô"→"go" = (1, ["o"]).
    processor.newWord()
    processor.focusedFieldKind = .nativePanel
    processor.push(char: "g")
    processor.push(char: "o")
    processor.push(char: "o")
    XCTAssertEqual(processor.transformed, "gô")
    let (panelBs, panelDiff) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(panelBs, 1)
    XCTAssertEqual(panelDiff, ["o"])

    // Omnibox (windowField của app NFD): NFC grapheme = (1, ["o"]) — vì
    // axDeleteStart của axDirect đếm theo grapheme. Cũng là browser-chrome.
    processor.newWord()
    processor.focusedFieldKind = .windowField
    XCTAssertTrue(processor.focusedFieldIsBrowserChrome())
    processor.push(char: "g")
    processor.push(char: "o")
    processor.push(char: "o")
    XCTAssertEqual(processor.transformed, "gô")
    let (omniBs, omniDiff) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(omniBs, 1)
    XCTAssertEqual(omniDiff, ["o"])

    // windowField trong app NFC-whitelist (vd Notes) KHÔNG phải browser-chrome
    // → không ép axDirect.
    processor.changeActiveApp("com.apple.Notes")
    processor.focusedFieldKind = .windowField
    XCTAssertFalse(processor.focusedFieldIsBrowserChrome())
  }

  /// Regression (Telegram/ChatGPT "điều"→"đều", mất chữ "i"): app native NFC
  /// grapheme-delete mà AX phân loại field thành .unknown (cảnh AX thật lỗi)
  /// PHẢI được định tuyến NFC — nếu không, NFD scalar-diff backspace thừa ở phím
  /// dấu của cụm nguyên âm mở → xóa nhầm chữ giữa. Khóa TẦNG EMIT (không chỉ
  /// engine): (1) số học diff thật, (2) predicate định tuyến, (3) gõ trọn từ.
  /// Nếu ai đó gỡ whitelist mà giữ nguyên test engine, test này vẫn phải FAIL.
  func testTelegramChatGPTRouteThroughNFC() throws {
    // (1) Số học tầng emit — chính là chỗ lỗi: điêu→điều.
    //     NFC (grapheme) xóa 2 grapheme (u, ê); NFD (scalar) đếm THỪA thành 3 →
    //     app xóa-grapheme sẽ xóa nhầm cả "i" → "đều".
    let (nfcBs, _) = EventSimulator.calcKeyStrokes(from: "điêu", to: "điều")
    XCTAssertEqual(nfcBs, 2, "NFC grapheme diff: backspace 2 (u, ê)")
    let (nfdBs, _) = EventSimulator.calcKeyStrokesNFD(from: "điêu", to: "điều")
    XCTAssertEqual(nfdBs, 3, "NFD scalar diff đếm thừa (3) → phá app grapheme")

    // (2)+(3) Telegram & ChatGPT với field .unknown vẫn PHẢI dùng NFC (nhờ
    //     whitelist short-circuit) và gõ ra "điều" nguyên vẹn.
    for app in ["ru.keepcoder.Telegram", "com.openai.chat"] {
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp(app)
      p.focusedFieldKind = .unknown
      XCTAssertTrue(p.usesNFCForFocusedField(), "\(app): field .unknown vẫn phải NFC")
      for c in "ddieeuf" { p.push(char: c) }
      XCTAssertEqual(p.transformed, "điều", "\(app): gõ ddieeuf phải ra điều")
    }

    // Đối chứng: app NFD thật KHÔNG bị kéo sang NFC. 4.21: dùng Electron —
    // Chrome đã sang NFC nên không còn là ví dụ NFD hợp lệ.
    let electron = InputProcessor(method: .Telex)
    electron.changeActiveApp("com.tinyspeck.slackmacgap")
    electron.focusedFieldKind = .webContent
    XCTAssertFalse(electron.usesNFCForFocusedField(), "Electron web content giữ NFD")
  }

  /// 4.21: bỏ công tắc thủ công của 4.16 — web content của TRÌNH DUYỆT dùng
  /// NFC tự động. Cơ sở là phép đo thật: Chrome giữ nguyên NFC ở <input>,
  /// <input type=search> và contenteditable; Google Docs LƯU NFC (copy ra đếm
  /// 22 scalar precomposed, NFD sẽ là 29) chứ không phải NFD như 4.16 phỏng đoán.
  func testBrowserWebContentUsesNFC() throws {
    let chrome = InputProcessor(method: .Telex)
    chrome.changeActiveApp("com.google.Chrome")
    chrome.focusedFieldKind = .webContent
    XCTAssertTrue(chrome.usesNFCForFocusedField(), "web content của Chrome phải NFC")
    chrome.focusedFieldKind = .windowField
    XCTAssertTrue(chrome.usesNFCForFocusedField(), "thanh địa chỉ Chrome vẫn NFC")

    // Kênh beta/canary khớp theo prefix.
    for bundle in ["com.google.Chrome.beta", "com.google.Chrome.canary",
                   "com.brave.Browser.nightly", "com.microsoft.edgemac.Dev"] {
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp(bundle)
      p.focusedFieldKind = .webContent
      XCTAssertTrue(p.usesNFCForFocusedField(), "\(bundle) phải NFC")
    }
  }

  /// `.unknown` phải ĐI CÙNG trục với `.webContent` trong cùng một app: AX
  /// timeout làm fieldKind rơi về .unknown giữa chừng, hai case khác trục thì
  /// một từ đang gõ bị đổi trục giữa dòng — đúng lớp lỗi 4.14.
  func testUnknownFieldKindMatchesWebContentAxisPerApp() throws {
    let chrome = InputProcessor(method: .Telex)
    chrome.changeActiveApp("com.google.Chrome")
    chrome.focusedFieldKind = .webContent
    let web = chrome.usesNFCForFocusedField()
    chrome.focusedFieldKind = .unknown
    XCTAssertEqual(chrome.usesNFCForFocusedField(), web, "Chrome: .unknown phải cùng trục .webContent")

    let slack = InputProcessor(method: .Telex)
    slack.changeActiveApp("com.tinyspeck.slackmacgap")
    slack.focusedFieldKind = .webContent
    let slackWeb = slack.usesNFCForFocusedField()
    slack.focusedFieldKind = .unknown
    XCTAssertEqual(slack.usesNFCForFocusedField(), slackWeb, "Slack: .unknown phải cùng trục .webContent")
  }

  /// Phạm vi hẹp có chủ đích: Electron cũng là web content nhưng CHƯA đo, nên
  /// giữ NFD như trước. Đây đúng là chỗ công tắc 4.16 phóng quá tay — nó bật
  /// NFC cho mọi app ngoài whitelist, kể cả Slack/Zalo/Telegram.
  func testNonBrowserWebViewsStayNFD() throws {
    for bundle in ["com.tinyspeck.slackmacgap", "com.hnc.Discord",
                   "com.anthropic.claudefordesktop", "com.vng.zalo"] {
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp(bundle)
      p.focusedFieldKind = .webContent
      XCTAssertFalse(p.usesNFCForFocusedField(), "\(bundle) (Electron) giữ NFD")
    }
  }

  /// Đối chứng: app Apple vẫn NFC nhờ whitelist grapheme-storage, không liên
  /// quan gì tới luật trình duyệt mới.
  func testAppleAppsStillNFCViaWhitelist() throws {
    let notes = InputProcessor(method: .Telex)
    notes.changeActiveApp("com.apple.Notes")
    notes.focusedFieldKind = .webContent
    XCTAssertTrue(notes.usesNFCForFocusedField(), "Notes NFC nhờ whitelist")
  }
}


// MARK: - ===========================================
// MARK: - Commit-Time Replacement vs previousWordState
// MARK: - ===========================================

/// Mọi đường commit tự THAY chữ trên màn hình (macro bung, spell auto-correct)
/// đều để lại `wordState` giữ chữ user gõ chứ không phải chữ đang hiển thị.
/// Lưu state lệch đó làm `previousWordState` là bug: `WordBuffer.pop` (nhánh
/// `keys.isEmpty`) dựng nó ngược vào buffer khi user Backspace ngay sau đó, nên
/// mọi diff kế tiếp được tính trên đoạn text KHÔNG có trên màn hình → phá chữ.
final class CommitReplacementPreviousWordStateTests: XCTestCase {

  private var savedSpell = true
  private var savedRestore = true

  override func setUp() {
    super.setUp()
    savedSpell = Defaults[.spellCheckEnabled]
    savedRestore = Defaults[.englishAutoRestoreEnabled]
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
  }

  override func tearDown() {
    Defaults[.spellCheckEnabled] = savedSpell
    Defaults[.englishAutoRestoreEnabled] = savedRestore
    super.tearDown()
  }

  /// Gõ "ARM": Telex coi R giữa hai phụ âm là dấu hỏi → "ẢM". Ở phím kết từ,
  /// spell decision nhận ra initialism tiếng Anh và gõ lại "ARM" lên màn hình
  /// (`.restoreRawEnglish`). Sau bước đó màn hình là "ARM" còn `wordState` vẫn
  /// là "ẢM" — đúng kiểu lệch đã vá ở macro, nên KHÔNG được lưu previous.
  func testEnglishRestoreCommitDoesNotStoreStaleWordState() throws {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in "ARM" { p.push(char: c) }
    XCTAssertEqual(p.transformed, "ẢM", "Telex: R giữa các phụ âm = dấu hỏi")

    XCTAssertTrue(
      p.applySpellDecisionAndAdvance(endingChar: " ", swallowEndingChar: true),
      "Spell decision phải restore 'ARM' — vkey tự gửi thay thế")
    XCTAssertNil(
      p.previousWordState,
      "Màn hình đang là 'ARM' còn wordState giữ 'ẢM' — lưu lại là dựng chữ cũ")

    // Backspace ngay sau đó chỉ xoá dấu cách (OS tự xử lý, trả về 0/rỗng) và
    // buffer phải TRỐNG, không được hồi sinh "ẢM".
    let (backspaces, diffChars) = p.pop(usesNFC: true)
    XCTAssertEqual(backspaces, 0)
    XCTAssertTrue(diffChars.isEmpty)
    XCTAssertEqual(p.transformed, "", "Buffer phải trống sau Backspace")
    XCTAssertTrue(p.wordState.isBlank)
  }

  /// Nhánh `.suggest` (thay từ gõ bằng từ trong từ điển) thoát cùng một cửa
  /// `return true`, nên dùng chung bảo đảm: hễ `applySpellDecisionAndAdvance`
  /// báo đã thay chữ thì không có `previousWordState` nào được giữ lại.
  func testAnyAppliedSpellReplacementLeavesNoPreviousWordState() throws {
    for word in ["ARM", "USA"] {
      let p = InputProcessor(method: .Telex)
      p.newWord()
      for c in word { p.push(char: c) }
      guard p.applySpellDecisionAndAdvance(endingChar: " ", swallowEndingChar: true) else {
        XCTFail("'\(word)' phải đi qua đường thay chữ ở commit")
        continue
      }
      XCTAssertNil(p.previousWordState, "'\(word)': không được giữ state trước khi sửa")
    }
  }

  /// Hậu quả cụ thể của hành vi CŨ, pin ở mức `WordBuffer`: `storePrevious:
  /// true` làm Backspace dựng lại "ẢM" vào buffer trong khi màn hình là "ARM";
  /// `storePrevious: false` để buffer trống như mong đợi.
  func testStoredStaleStateResurrectsPreReplacementWord() throws {
    let engine = Telex()

    var oldBehavior = WordBuffer()
    for c in "ARM" { oldBehavior.push(char: c, engine: engine) }
    oldBehavior.newWord(storePrevious: true)
    _ = oldBehavior.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(
      oldBehavior.transformed, "ẢM",
      "Hành vi cũ: Backspace hồi sinh 'ẢM' dù màn hình hiển thị 'ARM'")

    var newBehavior = WordBuffer()
    for c in "ARM" { newBehavior.push(char: c, engine: engine) }
    newBehavior.newWord(storePrevious: false)
    _ = newBehavior.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(newBehavior.transformed, "", "Hành vi mới: buffer trống")
    XCTAssertTrue(newBehavior.keys.isEmpty)
  }

  /// Macro trên đường Space (`handleTaskKey`) phải cùng quy tắc với đường dấu
  /// câu (`handleTextChar`): sau khi bung, màn hình là phần bung còn `wordState`
  /// giữ trigger. Space là phím bung macro phổ biến nhất.
  func testMacroExpansionOnSpaceKeepsNoPreviousWordState() throws {
    let savedMacros = Defaults[.macros]
    let savedEnabled = Defaults[.macroEnabled]
    defer {
      Defaults[.macros] = savedMacros
      Defaults[.macroEnabled] = savedEnabled
    }
    Defaults[.macroEnabled] = true
    Defaults[.macros] = [Macro(from: "dc", to: "địa chỉ")]

    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in "dc" { p.push(char: c) }
    XCTAssertEqual(p.transformed, "dc")

    XCTAssertTrue(
      p.expandMacroAndAdvance(endingChar: " "),
      "Macro 'dc' phải bung ở phím Space")
    XCTAssertNil(p.previousWordState, "Trigger 'dc' không được lưu sau khi bung macro")

    let (backspaces, diffChars) = p.pop(usesNFC: true)
    XCTAssertEqual(backspaces, 0)
    XCTAssertTrue(diffChars.isEmpty)
    XCTAssertEqual(p.transformed, "", "Backspace sau macro không được hồi sinh 'dc'")
  }
}

// MARK: - Bốn quy luật ngữ âm còn thiếu trong engine (đối chiếu gonhanh.org)
//
// Mỗi nhóm dưới đây là một quy luật tiếng Việt mà engine vkey chưa mã hoá,
// phát hiện khi so sánh với core Rust của GoNhanh.
final class EngineRulesFromGoNhanhTests: XCTestCase {

  private var savedFreeMark: Bool = false

  override func setUp() {
    super.setUp()
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.freeMarkModeEnabled] = false
    Defaults.reset(.autoTypoCorrection)
    Defaults.reset(.newStyleTonePlacement)
  }

  override func tearDown() {
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  /// Gõ chuỗi phím Telex qua đúng đường InputProcessor (gồm cả recovery),
  /// trả về chuỗi hiển thị trên màn hình.
  private func telex(_ keys: String) -> String {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in keys { p.push(char: c) }
    return p.transformed
  }

  // MARK: 1) Thanh nhập — âm tiết kết bằng p/t/c/ch/k chỉ mang sắc hoặc nặng

  /// Tiếng Việt không có âm tiết vừa kết bằng phụ âm tắc vừa mang huyền/hỏi/ngã.
  /// Gõ trúng tổ hợp đó thì phím dấu phải rơi xuống thành chữ cái thường.
  func testCheckedToneRejectsHuyenHoiNga() {
    let cases = [
      "otr", "atr", "itr", "ocr", "opr", "achr", "ichr", "hotr", "matr",
      "otf", "atf", "ocf", "opf", "echf", "matf", "hotf",
      "otx", "itx", "ocx", "opx", "ichx", "hotx", "ochx",
    ]
    for keys in cases {
      XCTAssertEqual(telex(keys), keys, "\(keys): thanh nhập — dấu phải rơi xuống chữ thường")
    }
  }

  /// Đối chứng: sắc và nặng trên phụ âm tắc là HỢP LỆ, không được đụng vào.
  func testCheckedToneKeepsSacAndNang() {
    let cases = [
      ("ots", "ót"), ("ocs", "óc"), ("ops", "óp"), ("achs", "ách"),
      ("otj", "ọt"), ("ocj", "ọc"), ("opj", "ọp"), ("achj", "ạch"),
      ("hocj", "học"), ("bats", "bát"), ("sachj", "sạch"), ("khacs", "khác"),
    ]
    for (keys, want) in cases {
      XCTAssertEqual(telex(keys), want, "\(keys): sắc/nặng + phụ âm tắc là hợp lệ")
    }
  }

  /// Đối chứng: phụ âm cuối vang (m/n/ng/nh) nhận đủ 6 thanh như thường.
  func testCheckedToneDoesNotTouchSonorantFinals() {
    let cases = [
      ("lamf", "làm"), ("banr", "bản"), ("conf", "còn"),
      ("anhr", "ảnh"), ("mangx", "mãng"), ("nhungwx", "những"),
    ]
    for (keys, want) in cases {
      XCTAssertEqual(telex(keys), want, "\(keys): phụ âm cuối vang nhận mọi thanh")
    }
  }

  // MARK: 2) Vần "uơ" mở — chỉ móc chữ o khi chưa có âm cuối

  /// "ươ" chỉ tồn tại khi có âm cuối (hương, được) hoặc có nguyên âm thứ ba
  /// (tươi, rượu). Vần mở là "uơ" với u trơn: huơ, khuơ, quơ, thuở.
  /// Trước fix, MỌI thứ tự phím đều ra "hươ"/"thưở" — hai từ này không gõ được.
  func testOpenUoKeepsBareU() {
    XCTAssertEqual(telex("huow"), "huơ")
    XCTAssertEqual(telex("khuow"), "khuơ")
    XCTAssertEqual(telex("thuowr"), "thuở")
    XCTAssertEqual(telex("huowr"), "huở")
  }

  /// Đối chứng: có âm cuối thì móc CẢ HAI (ươ), và ba nguyên âm cũng vậy.
  func testClosedUoStillGetsDoubleHorn() {
    XCTAssertEqual(telex("dduowcj"), "được")
    XCTAssertEqual(telex("huowng"), "hương")
    XCTAssertEqual(telex("nuowcs"), "nước")
    XCTAssertEqual(telex("tuowi"), "tươi")
    XCTAssertEqual(telex("cuowif"), "cười")
    XCTAssertEqual(telex("ruowuj"), "rượu")
  }

  /// Đối chứng: "quơ" vốn đã đúng (qu- là phụ âm đầu) — không được vỡ.
  func testQuoUnchanged() {
    XCTAssertEqual(telex("quow"), "quơ")
  }

  // MARK: 3) "ă" không đứng trước nguyên âm khác

  /// Không có vần ăi/ăo/ău/ăy trong tiếng Việt — phải recovery về phím thô.
  func testBreveBeforeVowelRecovers() {
    XCTAssertEqual(telex("taiw"), "taiw")
    XCTAssertEqual(telex("tayw"), "tayw")
    XCTAssertEqual(telex("maiw"), "maiw")
  }

  /// Đối chứng: vần oă hợp lệ (ă đứng SAU o) và ă + phụ âm cuối vẫn chạy.
  func testBreveValidCasesUnaffected() {
    XCTAssertEqual(telex("xoawn"), "xoăn")
    XCTAssertEqual(telex("awn"), "ăn")
    XCTAssertEqual(telex("nawm"), "năm")
    XCTAssertEqual(telex("quawn"), "quăn")
  }

  // MARK: 4) Gõ lặp nguyên âm khi âm tiết đã có dấu = kéo dài, không phải đặt mũ

  /// Kiến trúc một-dauMu-cho-cả-từ khiến "chưa"+a không chỉ áp nhầm mũ mà còn
  /// XOÁ dấu móc đã đúng (ư→u). Người gõ kiểu chat mất chữ.
  func testRepeatedVowelAfterMarkDoesNotStealMu() {
    XCTAssertEqual(telex("chuwaa"), "chưaa")
    XCTAssertEqual(telex("chuwaaa"), "chưaaa")
  }

  /// Khi âm tiết mới chỉ có dấu THANH (chưa có mũ/móc), gõ lặp nguyên âm rơi
  /// về phím thô thay vì bịa ra "quấ". Không hiển thị được "quáa" vì ở tầng
  /// validator ca này không phân biệt được với "wifi" (chuKhongDau "wii" sau
  /// khi f bị nuốt làm huyền) — nới thêm sẽ biến "wifi" thành "wìi".
  /// Điều quan trọng vẫn đạt: dấu sắc KHÔNG bị phá thành dấu mũ.
  func testRepeatedVowelAfterToneFallsBackToRaw() {
    XCTAssertEqual(telex("quasa"), "quasa")
    XCTAssertNotEqual(telex("quasa"), "quấ", "không được biến dấu sắc thành mũ")
  }

  /// Đối chứng cho chính ca đã suýt vỡ khi nới validator: từ mượn có phím dấu
  /// kẹp giữa hai nguyên âm giống nhau phải giữ nguyên phím thô.
  func testLoanwordWithToneKeyBetweenSameVowelsUnchanged() {
    XCTAssertEqual(telex("wifi"), "wifi")
  }

  /// Lưới an toàn cho cả bốn luật: từ thông dụng có ươ/oă/phụ-âm-tắc phải gõ
  /// đúng như cũ. Bộ này bắt được lần Rule 5c đầu tiên bắn quá sớm và làm hỏng
  /// nguyên nhóm "hoặc/ngoặc/khoăn" (chuỗi "ao" chờ phụ âm cuối để đảo ra "oa").
  func testCommonWordsUnaffected() {
    let cases = [
      ("nguwowif", "người"), ("thuowngf", "thường"), ("nguwowngx", "ngưỡng"),
      ("nuowcs", "nước"), ("truowngf", "trường"), ("dduowngf", "đường"),
      ("cuwowif", "cười"), ("hoawcj", "hoặc"), ("ngoawcj", "ngoặc"),
      ("khoawn", "khoăn"), ("choawts", "choắt"), ("hocj", "học"),
      ("khachs", "khách"), ("thuoocs", "thuốc"), ("bawngf", "bằng"),
    ]
    for (keys, want) in cases {
      XCTAssertEqual(telex(keys), want, "\(keys) phải ra \(want)")
    }
  }

  /// Đối chứng: đường đặt mũ chuẩn và đường huỷ mũ (aaa/ooo/eee) giữ nguyên.
  func testStandardMuPathsUnaffected() {
    XCTAssertEqual(telex("aa"), "â")
    XCTAssertEqual(telex("oo"), "ô")
    XCTAssertEqual(telex("ee"), "ê")
    XCTAssertEqual(telex("caan"), "cân")
    XCTAssertEqual(telex("toois"), "tối")
    XCTAssertEqual(telex("been"), "bên")
    XCTAssertEqual(telex("aaa"), "aa")
    XCTAssertEqual(telex("ooo"), "oo")
  }
}


// MARK: - v4.20: bảng app tương thích + manual accessibility
final class AppCompatV420Tests: XCTestCase {

  /// Bundle ID thật của Warp là "dev.warp.Warp-Stable" (và -Preview). Entry cũ
  /// "com.warp.Warp" không khớp gì nên Warp âm thầm chạy đường batch mặc định.
  func testWarpBundleIdMatchesRealChannels() {
    for bundle in ["dev.warp.Warp-Stable", "dev.warp.Warp-Preview", "dev.warp.Warp"] {
      guard case .stepByStep = EventSimulator.getStrategy(for: bundle) else {
        return XCTFail("\(bundle) phải dùng .stepByStep")
      }
    }
    // Bundle ID SAI cũ không được vô tình vẫn khớp.
    guard case .hybrid = EventSimulator.getStrategy(for: "com.warp.Warp") else {
      return XCTFail("bundle ID cũ (sai) không nên khớp entry nào")
    }
  }

  /// Terminal bổ sung — đều là app dựng cây text riêng, cần gửi từng phím.
  func testAdditionalTerminalsUseStepByStep() {
    for bundle in ["com.github.wez.wezterm", "com.raphaelamorim.rio", "com.termius-dmg.mac"] {
      guard case .stepByStep = EventSimulator.getStrategy(for: bundle) else {
        return XCTFail("\(bundle) phải dùng .stepByStep")
      }
    }
  }


}

// MARK: - v4.22: hộp thoại Lưu của app sandbox làm gãy từ đang gõ
//
// Ô "Thư mục mới" trong hộp thoại Lưu của Safari nằm ở tiến trình phụ
// `com.apple.Safari.SandboxBroker`. AX trả về khi thì bundle đó, khi thì
// `com.apple.Safari` — đổi qua lại TỪNG PHÍM. vkey coi mỗi lần đổi là chuyển
// app, áp lại chế độ Smart Switch, và đường đó xoá sạch bộ đệm từ.
// Hệ quả đo được: gõ "Haf Nooij" ra đúng "Haf Nooij", và "Nooij" ra "Nôị" vì
// từ bị cắt đôi giữa chừng ("nô" đã commit, "ij" thành từ mới → "ị").
final class SandboxHelperBundleTests: XCTestCase {

  /// Bundle phụ của chính app đang chạy KHÔNG phải app khác.
  func testHelperBundleResolvesToParentApp() {
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.Safari.SandboxBroker",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari",
      "SandboxBroker là tiến trình phụ của Safari, không phải app riêng")
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.appkit.xpc.openAndSavePanelService",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari",
      "hộp thoại Lưu ngoài tiến trình vẫn thuộc app đang dùng")
  }

  /// Đối chứng: app khác thật thì vẫn phải nhận ra là khác.
  func testDifferentAppStillSwitches() {
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.google.Chrome",
                                        frontmost: "com.apple.Safari"),
      "com.google.Chrome",
      "Chrome là app khác thật")
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.Safari",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari")
  }

  /// Lưới an toàn chung: gán lại CÙNG giá trị enabled không được xoá từ đang gõ.
  /// `didSet` của Swift bắn cả khi giá trị không đổi, nên mọi lần áp lại chế độ
  /// Smart Switch đều đi qua đây.
  func testSetEnabledSameValueKeepsWordBuffer() {
    let p = InputProcessor(method: .Telex)
    let hook = EventHook(inputProcessor: p)
    hook.setEnabled(true)
    p.newWord()
    for c in "ha" { p.push(char: c) }
    XCTAssertEqual(p.transformed, "ha")
    hook.setEnabled(true)   // gán lại ĐÚNG giá trị cũ
    XCTAssertEqual(p.transformed, "ha", "gán lại cùng giá trị không được xoá đệm")
    p.push(char: "f")
    XCTAssertEqual(p.transformed, "hà", "dấu huyền vẫn áp được sau khi áp lại chế độ")
  }

  /// Đổi giá trị thật thì vẫn phải reset (hành vi cũ, không được phá).
  func testSetEnabledValueChangeStillResets() {
    let p = InputProcessor(method: .Telex)
    let hook = EventHook(inputProcessor: p)
    hook.setEnabled(true)
    p.newWord()
    for c in "ha" { p.push(char: c) }
    hook.setEnabled(false)
    XCTAssertEqual(p.transformed, "", "tắt/bật thật sự vẫn reset đệm")
  }
}

// MARK: - ===========================================
// MARK: - v4.23 — Quy luật ngữ âm & phím dấu còn thiếu trong engine
// MARK: - ===========================================
//
// Mỗi test dưới đây khoá đúng MỘT lỗi engine đã vá ở v4.23, dùng nguyên chuỗi
// phím repro. Tên test mang mã lỗi (E1…E10) để tra ngược được sang CHANGELOG.
// Mỗi nhóm luôn kèm ĐỐI CHỨNG: những chuỗi phím chạy đúng từ trước và không
// được phép vỡ khi ai đó nới/siết lại luật.
final class EngineFixesV423Tests: XCTestCase {

  private var savedFreeMark = false
  private var savedZWJF = true
  private var savedAutoTypo = true
  private var savedNewStyle = true

  override func setUp() {
    super.setUp()
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    savedZWJF = Defaults[.allowedZWJF]
    savedAutoTypo = Defaults[.autoTypoCorrection]
    savedNewStyle = Defaults[.newStyleTonePlacement]
    // Chốt cấu hình mặc định của app: mọi kỳ vọng dưới đây đo ở đúng cấu hình
    // này. Không dùng `Defaults.reset` vì tearDown phải trả lại giá trị CŨ.
    Defaults[.freeMarkModeEnabled] = false
    Defaults[.allowedZWJF] = true
    Defaults[.autoTypoCorrection] = true
    Defaults[.newStyleTonePlacement] = true
  }

  override func tearDown() {
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.autoTypoCorrection] = savedAutoTypo
    Defaults[.newStyleTonePlacement] = savedNewStyle
    super.tearDown()
  }

  /// Gõ chuỗi phím qua ĐÚNG đường InputProcessor (gồm cả recovery + khôi phục
  /// tiếng Anh), trả về chuỗi hiển thị trên màn hình.
  private func telex(_ keys: String) -> String {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in keys { p.push(char: c) }
    return p.transformed
  }

  private func vni(_ keys: String) -> String {
    let p = InputProcessor(method: .VNI)
    p.newWord()
    for c in keys { p.push(char: c) }
    return p.transformed
  }

  // MARK: E1 — bảng vần thiếu "ng" cho e / uâ / yê

  /// `ValidVowelEndings` thiếu "ng" ở ba nhân âm tiết nên `needsRecovery` ném
  /// nguyên từ về phím thô: gõ "xẻng", "kẻng", "leng keng", "bâng khuâng",
  /// "chim yểng" đều không ra chữ. Đây là thiếu SÓT DỮ LIỆU chứ không phải
  /// luật — ba vần này có thật và phổ biến.
  func testE1_MissingNgEndingForE_UA_YE() {
    XCTAssertEqual(telex("xengr"), "xẻng")
    XCTAssertEqual(telex("kengr"), "kẻng")
    XCTAssertEqual(telex("lengf"), "lèng")
    XCTAssertEqual(telex("kengf"), "kèng")
    XCTAssertEqual(telex("khuaang"), "khuâng")   // bâng khuâng
    XCTAssertEqual(telex("yeengr"), "yểng")      // chim yểng

    // VNI cùng vần, cùng lỗi (bảng vần dùng chung cho hai kiểu gõ).
    XCTAssertEqual(vni("xeng3"), "xẻng")
    XCTAssertEqual(vni("khua6ng"), "khuâng")
    XCTAssertEqual(vni("ye6ng3"), "yểng")
  }

  /// Đối chứng E1: dạng KHÔNG dấu của chính các vần đó vốn đã chạy — thêm "ng"
  /// vào bảng không được làm chúng đổi nghĩa.
  func testE1_ControlPlainFormsUnchanged() {
    XCTAssertEqual(telex("xeng"), "xeng")
    XCTAssertEqual(telex("leng"), "leng")
    XCTAssertEqual(telex("khuaan"), "khuân")
    XCTAssertEqual(telex("yeen"), "yên")
  }

  // MARK: E2 — VNI: phím 7 thứ hai của cụm "uo" toggle TẮT móc

  /// Vần "ươ" có hai nguyên âm mang móc nên lối gõ đầy đủ có HAI phím móc,
  /// trong khi `dauMu` chỉ có MỘT ô: phím `7` thứ hai rơi vào `withMu` và
  /// toggle tắt móc vừa đặt. Telex đã có guard này từ lâu (`dduwow` → được),
  /// VNI thì không — nên 235/7.184 âm tiết "ươ" (được, người, trường, nước…)
  /// gõ ra chữ sai.
  func testE2_VNISecondHornKeyOnUOKeepsHorn() {
    XCTAssertEqual(vni("nu7o7c1"), "nước")
    XCTAssertEqual(vni("d9u7o7ng2"), "đường")
    XCTAssertEqual(vni("tu7o7i"), "tươi")
    XCTAssertEqual(vni("ngu7o7i2"), "người")
    XCTAssertEqual(vni("tru7o7ng2"), "trường")
    XCTAssertEqual(vni("d9u7o75c"), "được")
  }

  /// Đối chứng E2: đường HUỶ móc là hai phím móc KỀ NHAU, phải giữ nguyên —
  /// guard mới không được nuốt nó.
  func testE2_VNIHornToggleOffStillWorks() {
    XCTAssertEqual(vni("u7"), "ư")
    XCTAssertEqual(vni("o7"), "ơ")
    XCTAssertEqual(vni("u7u7"), "uu", "hai phím 7 kề nhau vẫn huỷ móc")
  }

  // MARK: E3 — VNI thiếu guard `conLai` (đối xứng với Telex)

  /// Telex bỏ qua phím dấu khi âm tiết còn phần không hợp lệ (`conLai`); VNI
  /// thì không, nên chữ số bị NUỐT vào làm dấu: "leg2" ra "lèg" thay vì giữ
  /// nguyên (Telex "legf" giữ "legf").
  func testE3_VNISkipsMarkKeysWhenSyllableHasLeftovers() {
    for keys in ["leg2", "bag2", "tag1", "log2", "dog9"] {
      XCTAssertEqual(vni(keys), keys, "\(keys): còn conLai thì phím số là chữ số")
    }
  }

  /// Đối chứng E3: validator CỐ Ý thả `conLai == ["g"]` đi qua (typo "gn"→"ng")
  /// nên đường gõ nhầm vẫn phải chạy — guard mới không được chặn nó.
  func testE3_VNITypoGnStillCorrected() {
    XCTAssertEqual(vni("phuo7gn2"), "phường")
  }

  // MARK: E4 — nguyên âm ba oeo/oao bị hiểu nhầm là lệnh dấu mũ

  /// Điều kiện đặt mũ cũ chỉ hỏi "nguyên âm CÓ CHỨA ký tự này ở bất kỳ đâu",
  /// nên chữ 'o' thứ hai của "oeo"/"oao" bị coi là gõ lặp: "khoeo" ra "khôe",
  /// "ngoaos" ra "ngốa". Hai cụm này có sẵn trong `TiengViet.NguyenAmGhep`.
  func testE4_TripleVowelOeoOaoIsNotCircumflexCommand() {
    XCTAssertEqual(telex("khoeo"), "khoeo")
    XCTAssertEqual(telex("ngoeo"), "ngoeo")
    XCTAssertEqual(telex("ngoeos"), "ngoéo")
    XCTAssertEqual(telex("khoeof"), "khoèo")
    XCTAssertEqual(telex("ngoeoj"), "ngoẹo")
    XCTAssertEqual(telex("ngoaos"), "ngoáo")
  }

  /// Đối chứng E4 — CHÍNH LÀ cái lưới đã bắt được lần siết quá tay đầu tiên.
  /// Không được siết thành "ký tự liền trước phải TRÙNG": Telex của vkey cho
  /// gõ mũ TRỄ sau phụ âm cuối ("theme" → "thêm"), siết như vậy là phá luôn.
  func testE4_LateCircumflexAfterFinalConsonantStillWorks() {
    XCTAssertEqual(telex("theme"), "thêm")
    XCTAssertEqual(telex("toong"), "tông")
  }

  // MARK: E5 — dấu mũ hoa/thường: bất đối xứng là CỐ Ý

  /// KỲ VỌNG ĐÃ SỬA (v4.24). Bản E5 gốc đòi "hai chiều phải như nhau" và khoá
  /// `telex("aA") == "â"`. Đo lại thì vế đó SAI TỪ ĐẦU, và chính nó là hồi quy
  /// R7: chiều `aA` → `â` không cứu được ca nào (corpus 7.184 âm tiết, selftest
  /// 127 ca, 5.622 ca gõ thanh sớm, 227.624 từ /usr/share/dict/words đều y
  /// nguyên) mà làm hỏng 803/9.844 tên riêng camelCase, hỏng theo kiểu MẤT CHỮ:
  /// "dataAccess" → "datccess", "photoObject" → "photObject", "LeEm" → "Lêm".
  /// Kỳ vọng cũ → mới: `telex("aA")` từ `"â"` thành `"aA"`.
  ///
  /// Bất đối xứng có lý do, không phải sót:
  ///   • Shift ở phím ĐẦU của cặp = viết hoa cả từ, phím sau vẫn là gõ lặp
  ///     ⇒ "Aa" → "Â".
  ///   • Shift ở phím SAU nghĩa là người gõ vừa CHỦ ĐỘNG mở một chữ hoa mới —
  ///     không ai bấm Shift để gõ ra chữ â THƯỜNG ⇒ "aA" giữ nguyên.
  /// Xem thêm `EngineRegressionFixesV424Tests.testR7_...` (chiều camelCase).
  func testE5_CircumflexCaseAsymmetryIsIntentional() {
    XCTAssertEqual(telex("Aa"), "Â", "Shift ở phím ĐẦU = viết hoa cả từ, phím sau là gõ lặp")
    XCTAssertEqual(telex("aA"), "aA",
      "Shift ở phím SAU = mở chữ hoa mới, KHÔNG phải lệnh đặt mũ")
    // Hai đường thuần một kiểu chữ không đụng tới.
    XCTAssertEqual(telex("aa"), "â")
    XCTAssertEqual(telex("AAn"), "Ân")
  }

  // MARK: E6 — rule swap nguyên âm ghi đè nguyên âm vừa gán

  /// Bốn rule "swap nguyên âm" gán sẵn `reparsed.nguyenAm` rồi mới phân tích
  /// phần đuôi. Dùng `finishParsing` thì bước tách nguyên âm của nó GHI ĐÈ
  /// nguyên âm vừa gán khi đuôi bắt đầu bằng nguyên âm — ký tự BIẾN MẤT mà
  /// `needsRecovery` vẫn false, nên không có đường phục hồi: "veia" ra "va",
  /// "boui" ra "bỉ", "haoan" ra "hoân", "afoot" ra "òt". Mất chữ âm thầm là
  /// lớp lỗi tệ nhất — người gõ không thấy gì bất thường cho tới khi đọc lại.
  func testE6_VowelSwapDoesNotSwallowFollowingVowel() {
    for keys in ["veia", "boui", "bouir", "haoan", "afoot"] {
      XCTAssertEqual(telex(keys), keys, "\(keys): swap không tiêu hoá hết ⇒ giữ phím thô")
    }
  }

  /// Đối chứng E6: các đường swap HỢP LỆ (đuôi tiêu hoá hết) vẫn phải chạy.
  func testE6_ValidVowelSwapsUnaffected() {
    XCTAssertEqual(telex("veit"), "viet")
    XCTAssertEqual(telex("haois"), "hoái")
    XCTAssertEqual(telex("haong"), "hoang")
    XCTAssertEqual(telex("phuowgn"), "phương")
  }

  // MARK: E7 — quét phím dấu đặt sai chỗ dừng ngay ở phụ âm đầu

  /// s/x/r/f/j vừa là phím dấu Telex vừa là phụ âm đầu hợp lệ. Vòng quét cũ
  /// `break` ở ký tự dấu ĐẦU TIÊN nên với "trfong" nó chốt vào chữ 'r' của cụm
  /// "tr", rồi guard `index > 0` vô hiệu hoá cả Rule 5 → không ra "tròng".
  /// Bước strip cũng phải xoá ĐÚNG ký tự tại vị trí tìm được, không phải "ký
  /// tự dấu đầu tiên gặp ở bất kỳ đâu" (xoá nhầm 'r' → "tfong").
  func testE7_MisplacedToneScanSkipsInitialConsonant() {
    XCTAssertEqual(telex("trfong"), "tròng")
    XCTAssertEqual(telex("sfai"), "sài")
    XCTAssertEqual(telex("xfin"), "xìn")
    XCTAssertEqual(telex("rfa"), "rà")
  }

  /// Đối chứng E7: phụ âm đầu KHÔNG phải phím dấu vốn đã chạy đúng.
  func testE7_ExistingMisplacedToneCasesUnchanged() {
    XCTAssertEqual(telex("thfong"), "thòng")
    XCTAssertEqual(telex("nhfa"), "nhà")
    XCTAssertEqual(telex("tafi"), "tài")
    XCTAssertEqual(telex("hoafng"), "hoàng")
  }

  /// Đối chứng E7 QUAN TRỌNG NHẤT: phụ âm đầu loanword (w/z/j/f, chỉ tồn tại
  /// khi `allowedZWJF` bật) KHÔNG được bỏ qua. Tiếng Việt không có từ bản địa
  /// mở đầu bằng các chữ đó nên phím dấu phía sau là chữ cái thật. Bỏ qua thì
  /// "from" ra "fỏm", "free" ra "fể", "frost" ra "fót" — 31 từ EN hỏng.
  func testE7_ForeignInitialConsonantsAreNotSkipped() {
    XCTAssertEqual(telex("from"), "from")
    XCTAssertEqual(telex("free"), "free")
    XCTAssertEqual(telex("frost"), "frost")
  }

  // MARK: E8 — không huỷ được dấu do Parser TỰ SUY RA

  /// `uuTienDauThanh` là dấu Parser tự suy ra từ phím dấu đặt sai chỗ ("thfi" →
  /// thì). Trước đây nó được áp VÔ ĐIỀU KIỆN mỗi khi `dauThanh == .bang`, nên
  /// thao tác gõ đúp phím dấu để HUỶ không bao giờ gỡ được dấu đó và phím dấu
  /// bị nuốt im lặng: "thfiff" vẫn ra "thì", "mfass" ra "màs".
  func testE8_DoubleToneKeyCancelsParserInferredTone() {
    XCTAssertEqual(telex("thfiff"), "thif", "gõ đúp 'f' phải huỷ được dấu tự suy ra")
    XCTAssertEqual(telex("mfass"), "mas", "gõ đúp 's' phải huỷ được dấu tự suy ra")
  }

  /// Đối chứng E8: gõ MỘT lần phím dấu vẫn ra dấu như cũ.
  func testE8_SingleToneKeyStillInfersTone() {
    XCTAssertEqual(telex("thfi"), "thì")
    XCTAssertEqual(telex("mfas"), "má")
  }

  // MARK: E9 — Free Mark Mode miễn luôn cả luật thanh nhập

  /// Free Mark nới VỊ TRÍ đặt dấu (tên riêng, tiếng dân tộc) — nhưng bản cũ
  /// miễn TOÀN BỘ validator cho âm tiết đơn chữ thường, nên bật Free Mark là
  /// "art" ra "ảt", "soft" ra "sòt", "hurt" ra "hủt". Luật thanh nhập (âm tiết
  /// kết bằng phụ âm tắc chỉ nhận sắc/nặng) là tuyệt đối, giữ lại nó không làm
  /// mất ca Free Mark hợp lệ nào.
  func testE9_FreeMarkStillObeysCheckedToneRule() {
    let saved = Defaults[.freeMarkModeEnabled]
    Defaults[.freeMarkModeEnabled] = true
    defer { Defaults[.freeMarkModeEnabled] = saved }

    for word in ["art", "chart", "part", "soft", "hurt", "text", "exit", "merit"] {
      XCTAssertEqual(telex(word), word,
        "Free Mark bật: '\(word)' không được biến thành âm tiết thanh-nhập bất khả")
    }
    // Đối chứng: sắc/nặng trên phụ âm tắc vẫn hợp lệ khi Free Mark bật.
    XCTAssertEqual(telex("batj"), "bạt")
    XCTAssertEqual(telex("bats"), "bát")
  }

  /// Đối chứng E9: cùng bộ từ đó khi Free Mark TẮT phải cho kết quả Y HỆT —
  /// công tắc này không được đổi kết quả của luật tuyệt đối.
  func testE9_SameResultWhenFreeMarkOff() {
    for word in ["art", "chart", "part", "soft", "hurt", "text", "exit", "merit"] {
      XCTAssertEqual(telex(word), word)
    }
  }

  // MARK: E10 — vần bất khả sinh ra SAU khi áp dấu mũ

  /// Rule 5 chỉ chạy khi âm tiết CÓ phụ âm cuối, Rule 6 chỉ soi cụm nguyên âm
  /// GỐC (chưa mang mũ) — nên không luật nào bắt được nhân bất khả sinh ra sau
  /// khi áp mũ: "khoee" ra "khôe", "hoaan" ra "hoân", "tauw" ra "taư",
  /// "cuwuc" ra "cuưc". Các vần ôe/oâ/aư/uư không tồn tại trong tiếng Việt.
  func testE10_ImpossibleRhymeAfterCircumflexRecoversToRawKeys() {
    for keys in ["khoee", "hoaan", "tauw", "cuwuc", "khoeoo"] {
      XCTAssertEqual(telex(keys), keys, "\(keys): vần sau khi áp mũ không tồn tại ⇒ phím thô")
    }
  }

  /// Đối chứng E10: bảng `NhanCoDauMuHopLe` liệt kê theo VỊ TRÍ đặt mũ THẬT,
  /// nên các vần có mũ hợp lệ phải đi qua nguyên vẹn — kể cả "ưu" (mũ ở chữ u
  /// ĐẦU) vốn dễ bị nhầm với "uư" (mũ ở chữ u sau, không tồn tại).
  func testE10_ValidCircumflexRhymesUnaffected() {
    let cases = [
      ("khoer", "khoẻ"), ("khuaan", "khuân"), ("dduwowngf", "đường"),
      ("nguwowif", "người"), ("tieengs", "tiếng"), ("ruowuj", "rượu"),
      ("xuaats", "xuất"), ("xoawn", "xoăn"),
    ]
    for (keys, want) in cases {
      XCTAssertEqual(telex(keys), want, "\(keys) phải ra \(want)")
    }
  }

  // MARK: E11 — guard "âm tiết đã có dấu" nuốt luôn lối gõ "thanh trước, mũ sau"
  //
  // (Số hiệu E11 trước đây bỏ trống: đợt v4.23 nhảy từ E10 sang E12 —
  // `ZWJFOffTelexTests.testDoubleWCancelsWithoutGhostU_whenZWJFOff`.)

  /// Nhánh đặt mũ Telex chặn mọi âm tiết ĐÃ mang dấu, gộp chung dấu MŨ/MÓC với
  /// dấu THANH. Gộp như vậy giết luôn lối gõ hợp lệ "phím thanh trước, phím mũ
  /// sau": đo trên 5.622 âm tiết có dấu của corpus thì chặn hết làm hỏng thêm
  /// 557 âm tiết — gần trọn nhóm nhân iê/uô/yê/uyê, tức những từ dùng hằng ngày.
  ///
  /// Nay chỉ nhận là lệnh đặt mũ khi phím này gõ ĐÔI LIỀN KỀ với một chữ CŨNG gõ
  /// SAU phím thanh (`TiengVietState.viTriGoDauThanh`) — xem đối chứng ngay dưới
  /// để thấy khe hở được mở HẸP đến mức nào.
  func testE11_ToneKeyBeforeCircumflexStillPlacesMu() {
    let cases = [
      ("tifeen", "tiền"), ("vijeec", "việc"), ("biseet", "biết"),
      ("xusaat", "xuất"), ("cujooc", "cuộc"), ("nghijeen", "nghiện"),
      ("nhifeeu", "nhiều"), ("khusyeen", "khuyến"),
    ]
    for (keys, want) in cases {
      XCTAssertEqual(telex(keys), want, "\(keys) phải ra \(want)")
    }
  }

  /// Đối chứng E11 — CHÍNH LÀ cái guard vừa nới, nên phải khoá lại cho chặt.
  /// Nới rộng hơn "gõ đôi liền kề sau phím thanh" là hỏng ngay ba nhóm:
  ///   • kéo dài kiểu chat, chữ ghép đôi nằm TRƯỚC phím thanh — "quasa" sẽ ra
  ///     "quấ" (phá luôn dấu sắc), "chưa"+a mất cả dấu móc;
  ///   • gõ mũ TRỄ trên âm tiết đã có thanh ("define") — nới cả nhóm này thì
  ///     /usr/share/dict/words hỏng thêm 129 từ, còn siết như hiện tại chỉ 4;
  ///   • từ mượn có phím dấu kẹp giữa hai nguyên âm giống nhau ("wifi").
  func testE11_ChatLengtheningAndLateMuStillBlocked() {
    XCTAssertEqual(telex("quasa"), "quasa")
    XCTAssertNotEqual(telex("quasa"), "quấ", "dấu sắc KHÔNG được biến thành dấu mũ")
    XCTAssertEqual(telex("chuwaa"), "chưaa")
    XCTAssertEqual(telex("chuwaaa"), "chưaaa")
    XCTAssertEqual(telex("wifi"), "wifi")
    XCTAssertEqual(telex("define"), "define", "mũ TRỄ sau phím thanh vẫn bị chặn")
    XCTAssertEqual(telex("tosoi"), "tosoi",
      "khe hở chỉ mở cho gõ ĐÔI LIỀN KỀ — 'tosoi' (mũ rời) vẫn nằm ngoài")
    // Thứ tự chuẩn (mũ trước, thanh sau) không đụng tới.
    XCTAssertEqual(telex("toosi"), "tối")
  }

  /// E11 — GIÁ đã đo, ghi lại tường minh chứ không giấu.
  ///
  /// Mở lối "thanh trước, mũ sau" làm /usr/share/dict/words (227.624 từ) đi từ
  /// 6.730 lên 6.734 ca hỏng: đúng 4 từ có phím dấu rồi mới tới cặp "ee" liền
  /// kề. Lợi ròng vẫn DƯƠNG (cứu 557 âm tiết tiếng Việt) nên đây là đánh đổi có
  /// chủ ý, không phải sơ suất.
  ///
  /// ⚠️ Test này khoá HÀNH VI HIỆN TẠI, KHÔNG phải hành vi mong muốn. Nếu ai đó
  /// siết đúng hơn (vd đòi cụm nguyên âm sau khi áp mũ phải là vần tiếng Việt có
  /// thật) và test FAIL thì CẬP NHẬT kỳ vọng ở đây — đừng revert E11.
  func testE11_KnownCostOnEnglishDoubleEWords() {
    XCTAssertEqual(telex("fusee"), "fuế")
    XCTAssertEqual(telex("puree"), "puể")
    XCTAssertEqual(telex("tureen"), "tuển")
    XCTAssertEqual(telex("usee"), "uế")
  }
}

// MARK: - ===========================================
// MARK: - v4.23 — Backspace / replay ở tầng WordBuffer
// MARK: - ===========================================
final class WordBufferReplayV423Tests: XCTestCase {

  private var savedZWJF = true
  private var savedAutoTypo = true
  private var savedNewStyle = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedAutoTypo = Defaults[.autoTypoCorrection]
    savedNewStyle = Defaults[.newStyleTonePlacement]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    // Chốt cấu hình mặc định: kỳ vọng dưới đây đo ở đúng cấu hình này. Bộ test
    // KHÔNG chạy song song nên phải tự pin thay vì tin vào thứ tự lớp.
    Defaults[.allowedZWJF] = true
    Defaults[.autoTypoCorrection] = true
    Defaults[.newStyleTonePlacement] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.autoTypoCorrection] = savedAutoTypo
    Defaults[.newStyleTonePlacement] = savedNewStyle
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  /// P2 — Backspace ngay sau khi commit một từ phải replay CHUỖI PHÍM GỐC.
  ///
  /// `TiengVietState.chuKhongDau` KHÔNG chứa phím dấu (`withTone`/`withMu`/
  /// `withGachD` không push ký tự nào), nên dựng lại `keys` từ nó — cách cũ —
  /// khiến mọi backspace kế tiếp replay một chuỗi phím đã MẤT SẠCH DẤU:
  /// "chào" → "cha", "tiếng" → "tien", "đường" → "duon", kèm cả cụm bị xoá và
  /// gõ lại. `previousKeys` giữ đúng những phím user đã bấm.
  func testP2_BackspaceAfterCommitReplaysOriginalKeys() throws {
    let engine = Telex()
    // (phím, chữ đã commit, keys sau BS#1, chữ sau BS#2)
    let cases: [(String, String, String, String)] = [
      ("chaof", "chào", "chaof", "chao"),
      ("tieengs", "tiếng", "tieengs", "tiêng"),
      ("dduwowngf", "đường", "dduwowngf", "đương"),
    ]

    for (keys, committed, wantKeys, afterSecondBS) in cases {
      var buffer = WordBuffer()
      for c in keys { buffer.push(char: c, engine: engine) }
      XCTAssertEqual(buffer.transformed, committed, "Sanity: '\(keys)' phải ra '\(committed)'")

      // Space commit từ (đường `newWord(storePrevious: true)` của handleTextChar).
      buffer.newWord(storePrevious: true)

      // BS#1: xoá dấu cách → khôi phục từ vừa commit vào bộ đệm.
      _ = buffer.pop(engine: engine, usesNFC: true)
      XCTAssertEqual(buffer.transformed, committed)
      XCTAssertEqual(String(buffer.keys), wantKeys,
        "'\(keys)': replay phải giữ CẢ phím dấu, không chỉ chuKhongDau")

      // BS#2: bỏ một phím — kết quả phải khớp đường Backspace không qua commit.
      _ = buffer.pop(engine: engine, usesNFC: true)
      XCTAssertEqual(buffer.transformed, afterSecondBS,
        "'\(keys)': bỏ 1 phím phải ra '\(afterSecondBS)'")
    }
  }

  /// P2 — pin hành vi CŨ để thấy rõ nó sai ở đâu, và khoá luôn nhánh fallback.
  ///
  /// `previousKeys` rỗng (ai đó gán thẳng `previousWordState` mà không qua
  /// `newWord(storePrevious:)`) thì `pop` quay về đúng công thức cũ. Fallback
  /// đó phải TỒN TẠI để không phá call site lạ, nhưng kết quả của nó chính là
  /// bug: chuỗi phím mất dấu.
  func testP2_EmptyPreviousKeysFallsBackToToneLessReplay() throws {
    let engine = Telex()
    var buffer = WordBuffer()
    for c in "chaof" { buffer.push(char: c, engine: engine) }
    buffer.newWord(storePrevious: true)
    buffer.previousKeys = []   // ép đi nhánh fallback = công thức CŨ

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(String(buffer.keys), "chao",
      "Fallback dựng keys từ chuKhongDau — phím dấu 'f' biến mất")
    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "cha",
      "Đây là kết quả SAI của hành vi cũ, giữ lại để đối chiếu")
  }

  /// P3 — `reconstructState` phải reset `ddToggleStage`.
  ///
  /// Vòng replay cũ ghi vào một biến CỤC BỘ nên `self.ddToggleStage` giữ nguyên
  /// giá trị của từ TRƯỚC khi backspace: "vcdd" → "vcđ" (stage = 1), Backspace
  /// đưa màn hình về "vcd" mà stage vẫn 1 → gõ 'd' lại KHÔNG toggle được nữa
  /// (ra "vcdd"), và mọi 'd' sau đó cũng vậy cho tới hết từ.
  func testP3_ReconstructStateResetsDdToggleStage() throws {
    let engine = Telex()
    var buffer = WordBuffer()
    for c in "vcdd" { buffer.push(char: c, engine: engine) }
    XCTAssertEqual(buffer.transformed, "vcđ", "anywhere-dd: 'vcdd' → 'vcđ'")
    XCTAssertEqual(buffer.ddToggleStage, 1)

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "vcd")
    XCTAssertEqual(buffer.ddToggleStage, 0,
      "Sau replay, stage phải khớp MÀN HÌNH ('vcd' — chưa toggle)")

    buffer.push(char: "d", engine: engine)
    XCTAssertEqual(buffer.transformed, "vcđ",
      "Gõ 'd' lại phải toggle được; hành vi cũ kẹt ở 'vcdd'")
  }

  /// P6 — "kr" đã gỡ khỏi `impossible2LetterPrefixes`.
  ///
  /// Nó vừa nằm ở đó vừa nằm trong `TiengViet.PhuAmGhep` và
  /// `TiengVietValidator.ValidInitials` như phụ âm đầu tiếng Việt HỢP LỆ —
  /// mâu thuẫn trực tiếp. `isImpossibleCluster` chạy TRƯỚC validator (và trước
  /// cả Free Mark) nên "kroong" bị khoá raw ngay ở phím 'r' → ra "kroong" thay
  /// vì "Krông" (Krông Pắc, Krông Ana, Krông Bông).
  func testP6_KrPrefixNoLongerBlocksVietnamesePlaceNames() throws {
    let engine = Telex()

    func typed(_ keys: String) -> String {
      var b = WordBuffer()
      for c in keys { b.push(char: c, engine: engine) }
      return b.transformed
    }

    XCTAssertEqual(typed("kroong"), "krông", "Krông — tên địa danh Tây Nguyên")
    // Đối chứng: từ tiếng Anh mở đầu "kr" vẫn được validator/lexicon giữ raw,
    // chỉ là khoá muộn hơn 1 phím.
    XCTAssertEqual(typed("krill"), "krill")
    XCTAssertEqual(typed("kraft"), "kraft")
    // Đối chứng cho `testGoNhanhEngineInnovations` (dòng "kr initials"):
    // "krong" không có phím mũ nên vẫn ra "krong" như trước.
    XCTAssertEqual(typed("krong"), "krong")
  }
}

// MARK: - ===========================================
// MARK: - v4.23 — Ranh giới đổi app: bộ đệm & ngữ cảnh câu
// MARK: - ===========================================
final class AppSwitchBoundaryV423Tests: XCTestCase {

  private var savedZWJF = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.allowedZWJF] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  // ⚠️ ĐÃ XOÁ (v4.24) — `testP1_RealAppChangeClearsWordBuffer`.
  //
  // Test đó khoá: đang gõ "vie" ở Safari mà `changeActiveApp("com.google.Chrome")`
  // thì `transformed` phải về "" và phím kế tiếp mở TỪ MỚI. Nó khoá đúng một
  // dòng `newWord()` trong `InputProcessor.changeActiveApp`. Dòng đó đã bị GỠ,
  // nên test đi theo — giữ lại là khoá một con đường không còn tồn tại.
  //
  // VÌ SAO GỠ: hàm ấy chạy trong callback event-tap, mà trên macOS 26 `activeApp`
  // DAO ĐỘNG mỗi phím ở overlay (Spotlight) — hai khối trong `EventHook` ghi nó
  // từ hai nguồn lệch nhau (`eventTargetUnixProcessID` trả app NỀN, AX trả
  // Spotlight). Guard `app != activeApp` vì thế đúng mà vô dụng: mỗi phím là một
  // lần "đổi app" thật sự khác giá trị → xoá bộ đệm ở MỌI phím → không dấu nào
  // hình thành nữa, gõ tiếng Việt âm thầm biến thành gõ tiếng Anh. Vòng vá tiếp
  // theo (gộp hai khối thành một bộ phân giải duy nhất) lại đẻ hồi quy khác.
  //
  // CA HỎNG QUAY LẠI (P1 — chấp nhận sống chung): một app cướp focus mà KHÔNG
  // sinh keyDown/mouseDown, đúng lúc đang gõ dở một từ → bộ đệm của app cũ sống
  // sót, và số backspace của lần thay thế kế tiếp (tính trên "vie") ăn mất ký tự
  // cuối của ô bên app mới. Hiếm, hỏng đúng một ký tự, gõ lại được — rẻ hơn hẳn
  // "mất dấu ở mọi app".
  //
  // MUỐN VÁ LẠI: đọc docstring (a)→(d) của `InputProcessor.changeActiveApp`
  // TRƯỚC. Điều kiện tiên quyết là chứng minh trên máy thật rằng `activeApp` ỔN
  // ĐỊNH ở mọi phím (macOS 26 + Spotlight + Chrome web content). Dựng lại
  // `newWord()` khi chưa có bằng chứng đó thì
  // `testR1_ActiveAppPingPongMustNotTouchTheWordBuffer` sẽ đỏ — và nó đỏ có lý do.

  /// P1 — một lời gọi `changeActiveApp` KHÔNG được giết bộ đệm từ.
  ///
  /// Sau khi nửa "xoá đệm khi đổi app" của P1 bị LÙI (v4.24 — xem khối chú thích
  /// ngay trên), test này xanh một cách hiển nhiên: không đường nào trong
  /// `changeActiveApp` đụng tới bộ đệm nữa. Giữ lại làm TRIPWIRE — ai thêm
  /// `newWord()` vào đó mà quên guard sẽ thấy nó đỏ trước khi kịp đi hết vòng lặp
  /// vá-rồi-lùi lần nữa.
  ///
  /// Bối cảnh vẫn nguyên giá trị: `changeActiveApp` bị gọi lại với CÙNG bundle
  /// rất thường xuyên (`AppState.activeApplicationDidChange` gọi không guard; AX
  /// nhảy qua lại giữa app cha và tiến trình phụ của nó). Xoá vô điều kiện chính
  /// là dựng lại lỗi v4.22 — từ đang gõ bị cắt đôi giữa chừng ("Nooij" → "Nôị").
  func testP1_SameAppReassignmentKeepsWordBuffer() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp("com.apple.Safari")
    p.newWord()
    for c in "nooi" { p.push(char: c) }
    XCTAssertEqual(p.transformed, "nôi")

    p.changeActiveApp("com.apple.Safari")   // gán lại ĐÚNG giá trị cũ
    XCTAssertEqual(p.transformed, "nôi", "Gán lại cùng bundle không được xoá đệm")

    p.push(char: "j")
    XCTAssertEqual(p.transformed, "nội", "Dấu nặng vẫn áp được lên cả cụm")
  }

  /// P8 — ngữ cảnh câu chết cùng ranh giới app.
  ///
  /// `changeActiveApp` nay gọi `resetSentenceCapitalizeState()`. Nửa quan sát
  /// được từ test là cờ chờ-viết-hoa: sau Enter ở app A, chuyển sang app B thì
  /// chữ đầu tiên gõ ở B KHÔNG được tự viết hoa — câu đó thuộc về app A.
  ///
  /// PHẠM VI: nửa còn lại của P8 (`prev1Committed`/`prev2Committed` — cửa sổ
  /// n-gram) là `private` và chỉ quan sát được qua `NGramStore` file-backed,
  /// nên KHÔNG assert ở đây; đừng đọc test này như bằng chứng cửa sổ n-gram đã
  /// bị cắt.
  func testP8_PendingCapitalizeDiesOnRealAppChange() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }

    func press(_ p: InputProcessor, code: UInt16) -> Unmanaged<CGEvent>? {
      let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
      event.flags = []
      return p.handleEvent(event: event)
    }

    // Đối chứng: KHÔNG đổi app → vẫn tự viết hoa như cũ.
    let staying = InputProcessor(method: .Telex)
    staying.changeActiveApp("com.apple.Notes")
    _ = press(staying, code: 36)          // Enter
    _ = press(staying, code: 0)           // a
    XCTAssertEqual(staying.transformed, "A", "Cùng app: Enter vẫn mở câu mới")

    // Đổi app thật giữa Enter và chữ cái → ngữ cảnh câu của app cũ phải chết.
    let switching = InputProcessor(method: .Telex)
    switching.changeActiveApp("com.apple.Notes")
    _ = press(switching, code: 36)        // Enter (ở Notes)
    switching.changeActiveApp("com.apple.Safari")
    _ = press(switching, code: 0)         // a (ở Safari)
    XCTAssertEqual(switching.transformed, "a",
      "Câu vừa xuống dòng thuộc app CŨ — không được viết hoa hộ app mới")
  }
}

// MARK: - ===========================================
// MARK: - v4.23 — Macro bung được sau khi auto-capitalize viết hoa trigger
// MARK: - ===========================================
final class MacroCaseInsensitiveV423Tests: XCTestCase {

  /// P7 — auto-capitalize viết hoa chữ đầu câu TRƯỚC khi macro được tra, mà
  /// toàn bộ macro seed sẵn đều chữ thường và CẢ HAI tính năng đều bật mặc
  /// định. Ở đầu mỗi câu/dòng "vn" đã thành "Vn", `"vn" != "Vn"` nên macro
  /// không bao giờ bung: ra "Vn " thay vì "Việt Nam ". Giữa câu thì bung bình
  /// thường — nên lỗi chỉ lộ ở đầu câu và rất dễ bị bỏ qua.
  func testP7_MacroExpandsWhenTriggerWasAutoCapitalized() throws {
    let macros = [Macro(from: "vn", to: "Việt Nam")]
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "vn", endingChar: " ", macros: macros),
      "Việt Nam ", "chữ thường: bung như trước")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Vn", endingChar: " ", macros: macros),
      "Việt Nam ", "đầu câu (auto-capitalize) cũng phải bung")
  }

  /// P7 — KỲ VỌNG ĐÃ SỬA (v4.24). Bản gốc khoá `"VN"` → `"VIỆT NAM "`, tức khoá
  /// đúng cái HỒI QUY (R4): nó là hệ quả của khớp-bỏ-qua-hoa/thường cộng với
  /// `matchCase` viết HOA TOÀN BỘ, và nó nuốt mọi viết tắt người Việt gõ HOA CÓ
  /// CHỦ Ý. Kỳ vọng cũ → mới: `"VIỆT NAM "` thành `nil`.
  ///
  /// Lỗi P7 cần vá chỉ đòi biến thể hoa-CHỮ-ĐẦU (thứ auto-capitalize thật sự tạo
  /// ra ở đầu câu), nên khớp thu hẹp về đúng `autoCapitalizedVariant`. Muốn
  /// all-caps bung thì khai macro all-caps riêng — nhánh khớp CHÍNH XÁC phục vụ
  /// đúng việc đó (`testP7_ExactCaseMacroWinsOverCaseInsensitiveMatch`).
  func testP7_AllCapsTriggerDoesNotExpand() throws {
    let macros = [Macro(from: "vn", to: "Việt Nam")]
    XCTAssertNil(
      InputProcessor.macroTarget(for: "VN", endingChar: " ", macros: macros),
      "ALL-CAPS là viết tắt có chủ ý, không phải trigger bị auto-capitalize")
    // Đối chứng đi kèm: biến thể hoa-CHỮ-ĐẦU vẫn bung, và `matchCase` vẫn lo
    // phần bung cho nó — nửa fix gốc của P7 không được mất theo.
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Vn", endingChar: " ", macros: macros),
      "Việt Nam ")
  }

  /// R4 [chiều HỒI QUY] — đo trên ĐÚNG bảng macro mà user thật có
  /// (`DefaultMacros.allDefaults`, seed sẵn cho mọi máy mới). Khớp
  /// bỏ-qua-hoa/thường biến mọi viết tắt gõ HOA thành macro: "PM " (giờ chiều /
  /// Project Manager) → "± ", "VN " → "VIỆT NAM ", "HN " → "HÀ NỘI ",
  /// "CTY " → "CÔNG TY ", "ARR " → "→", "DEG " → "°". Trước v4.23 chúng đi qua
  /// nguyên vẹn — đây là chữ BIẾN MẤT khỏi văn bản người dùng, không phải tính
  /// năng.
  func testR4_AllCapsAbbreviationsPassThroughUnexpanded() throws {
    let macros = DefaultMacros.allDefaults
    for trigger in ["PM", "VN", "HN", "SG", "CTY", "ARR", "DEG", "GTE"] {
      XCTAssertNil(
        InputProcessor.macroTarget(for: trigger, endingChar: " ", macros: macros),
        "\(trigger) gõ HOA là viết tắt có chủ ý — không được bung macro")
    }
  }

  /// R4 [chiều FIX GỐC] — nửa còn lại của P7 phải sống: biến thể hoa-CHỮ-ĐẦU
  /// (đầu câu, sau khi auto-capitalize viết hoa trigger) vẫn bung, chữ thường
  /// giữa câu vẫn bung. Cộng thêm ranh giới của chính `autoCapitalizedVariant`,
  /// vì đó là chỗ duy nhất quyết định "biến thể nào được nhận".
  func testR4_AutoCapitalizedVariantStillExpands() throws {
    let macros = DefaultMacros.allDefaults
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "vn", endingChar: " ", macros: macros),
      "Việt Nam ", "giữa câu (chữ thường) — đường vốn đã chạy")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Vn", endingChar: " ", macros: macros),
      "Việt Nam ", "đầu câu (auto-capitalize) — chính là lỗi P7 đã vá")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Hn", endingChar: " ", macros: macros), "Hà Nội ")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Cty", endingChar: " ", macros: macros), "Công ty ")
    // Phần bung không có chữ cái thì `matchCase` không đụng được gì.
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Pm", endingChar: " ", macros: macros), "± ")

    // Ranh giới: CHỈ viết hoa chữ đầu, và chỉ khi trigger mở đầu bằng chữ thường.
    XCTAssertEqual(InputProcessor.autoCapitalizedVariant(of: "vn"), "Vn")
    XCTAssertEqual(InputProcessor.autoCapitalizedVariant(of: "tphcm"), "Tphcm")
    XCTAssertNil(InputProcessor.autoCapitalizedVariant(of: "VN"),
      "trigger đã viết hoa thì auto-capitalize không tạo ra được biến thể nào")
    XCTAssertNil(InputProcessor.autoCapitalizedVariant(of: ""))
  }

  /// P7 — khớp CHÍNH XÁC phải được thử TRƯỚC. Người dùng có quyền khai hai
  /// macro chỉ khác hoa/thường; mỗi cái phải giữ phần bung riêng của mình.
  func testP7_ExactCaseMacroWinsOverCaseInsensitiveMatch() throws {
    let macros = [
      Macro(from: "vn", to: "Việt Nam"),
      Macro(from: "VN", to: "Vietnam Ltd"),
    ]
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "VN", endingChar: " ", macros: macros),
      "Vietnam Ltd ", "khớp chính xác thắng, KHÔNG được matchCase thành ALL-CAPS")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "vn", endingChar: " ", macros: macros),
      "Việt Nam ")
  }

  /// Đối chứng P7: không có macro nào khớp thì vẫn trả nil (không được vì nới
  /// hoa/thường mà bung nhầm), và macro rỗng bị bỏ qua như cũ.
  func testP7_NoMatchAndEmptyMacrosStillReturnNil() throws {
    let macros = [Macro(from: "vn", to: "Việt Nam")]
    XCTAssertNil(InputProcessor.macroTarget(for: "vni", endingChar: " ", macros: macros))
    XCTAssertNil(InputProcessor.macroTarget(for: "", endingChar: " ", macros: macros))
    XCTAssertNil(InputProcessor.macroTarget(
      for: "vn", endingChar: " ", macros: [Macro(from: "vn", to: "")]))
  }
}

// MARK: - ===========================================
// MARK: - v4.24 — Vá 9 hồi quy do đợt v4.23 đẻ ra
// MARK: - ===========================================
//
// Cả 9 hồi quy lọt qua 391 test vì lưới cũ chỉ khoá MỘT chiều: "ca mà bản vá
// sinh ra để sửa phải đúng". Không test nào hỏi ngược lại — "bản vá có làm hỏng
// thứ đang chạy đúng không". Vì vậy MỖI test trong khối này khoá ĐỒNG THỜI hai
// chiều, và cố ý để chúng CẠNH NHAU trong cùng một hàm:
//   • [HỒI QUY] ca mà bản vá v4.23 làm hỏng — nay phải xanh;
//   • [FIX GỐC] ca mà bản vá v4.23 sinh ra để sửa — không được mất.
// Người sửa engine lần sau đọc một chỗ là thấy cả hai mép của ranh giới.
//
// Ba bản vá KHÔNG có test ở đây — và HAI trong ba đã bị LÙI HẲN (v4.24). Lý do
// ghi thẳng tại chỗ gần nhất:
//   • R3 (miễn trừ `.stepByStep` khỏi downgrade + hàng rào thứ tự
//     `pendingReplacements`/`passThroughOrDefer`) — ĐÃ LÙI; xem khối chú thích
//     cuối `EngineRegressionFixesV424Tests`.
//   • R5 (cờ `fieldKindIsReliable` + cổng `AppState.adoptFieldKind` đóng băng
//     phân loại field trong một từ) — ĐÃ LÙI; xem `FocusedFieldStabilityV424Tests`.
//   • R9 chỉ sửa docstring; hành vi được khoá bằng hai test R9 dưới đây.
//
// R1 (bộ phân giải `activeApp` một-nguồn + `newWord()` trong `changeActiveApp`)
// cũng đã bị LÙI — xem `AppSwitchResolverV424Tests` và `AppSwitchBoundaryV423Tests`.
// Ba chỗ lùi đó KHÔNG phải dọn dẹp: lỗi chúng vá (P1/P5/F1) là lỗi CÓ SẴN đang
// chạy trong v4.23, còn thuốc thì hai lần liền độc hơn bệnh. Mỗi chỗ đều có khối
// chú thích (a) lỗi gốc (b) đã vá thế nào (c) hồi quy đẻ ra (d) vì sao sống chung.

final class EngineRegressionFixesV424Tests: XCTestCase {

  private var savedFreeMark = false
  private var savedZWJF = true
  private var savedAutoTypo = true
  private var savedNewStyle = true

  override func setUp() {
    super.setUp()
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    savedZWJF = Defaults[.allowedZWJF]
    savedAutoTypo = Defaults[.autoTypoCorrection]
    savedNewStyle = Defaults[.newStyleTonePlacement]
    // Chốt cấu hình mặc định của app — mọi kỳ vọng dưới đây đo ở đúng cấu hình
    // này (và ở cùng cấu hình với `EngineFixesV423Tests`). Bộ test KHÔNG chạy
    // song song nên phải tự pin thay vì tin vào thứ tự lớp.
    Defaults[.freeMarkModeEnabled] = false
    Defaults[.allowedZWJF] = true
    Defaults[.autoTypoCorrection] = true
    Defaults[.newStyleTonePlacement] = true
  }

  override func tearDown() {
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.autoTypoCorrection] = savedAutoTypo
    Defaults[.newStyleTonePlacement] = savedNewStyle
    super.tearDown()
  }

  /// Gõ chuỗi phím qua ĐÚNG đường InputProcessor (gồm cả recovery + khôi phục
  /// tiếng Anh), trả về chuỗi hiển thị trên màn hình.
  private func telex(_ keys: String) -> String {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in keys { p.push(char: c) }
    return p.transformed
  }

  // MARK: R2 — Rule 7 bắn vào đúng trạng thái mà Rule 5c cố ý tha

  /// "ao" + dấu trăng khi CHƯA có phụ âm cuối là trạng thái TRUNG GIAN: phụ âm
  /// cuối tới thì parser đảo "ao" → "oa" và ra hoặc / ngoặc / khoăn / choắt.
  /// Rule 5c tha nó từ lâu (có test khoá). Rule 7 — thêm ở v4.23 cho E10 — thì
  /// không, mà nhân "ăo" đâu có trong `NhanCoDauMuHopLe`, nên cả nhóm gõ NGHỊCH
  /// thứ tự a/o bị chốt `stopProcessing` ngay ở phím `w` và recovery không nhả
  /// ra nữa. Nay hai luật gọi CHUNG một carve-out (`dangChoPhuAmCuoiDeDaoAO`)
  /// nên không lệch nhau được.
  func testR2_SwappedAOOrderStillReachesTheFinalConsonantSwap() {
    // [HỒI QUY] thứ tự nghịch (a trước o) phải về được tới đích.
    XCTAssertEqual(telex("haowcj"), "hoặc")
    XCTAssertEqual(telex("chaowts"), "choắt")
    XCTAssertEqual(telex("ngaowcj"), "ngoặc")
    XCTAssertEqual(telex("khaown"), "khoăn")
    // …và trạng thái trung gian phải SỐNG qua từng phím, không bị chốt sớm.
    XCTAssertEqual(telex("haow"), "hăo", "trạng thái chờ đảo, chưa có phụ âm cuối")
    XCTAssertEqual(telex("haowc"), "hoăc", "phụ âm cuối tới ⇒ parser đảo ao → oa")

    // [FIX GỐC] thứ tự thuận vốn đã chạy — carve-out không được nới rộng ra
    // thành "tha mọi thứ", cũng không được siết vào làm hỏng nhóm này.
    XCTAssertEqual(telex("hoawcj"), "hoặc")
    XCTAssertEqual(telex("ngoawcj"), "ngoặc")
    XCTAssertEqual(telex("khoawn"), "khoăn")
    XCTAssertEqual(telex("choawts"), "choắt")
    XCTAssertEqual(telex("xoawn"), "xoăn")
  }

  /// R2 [FIX GỐC] — E10 vẫn phải bắt được nhân bất khả sinh ra SAU khi áp mũ.
  /// Carve-out chỉ được mở đúng bằng "ăo mở", không rộng hơn một ly: nếu ai đó
  /// vá R2 bằng cách tắt hẳn Rule 7 thì test này vỡ.
  func testR2_ImpossibleRhymeAfterMuStillRecoversToRawKeys() {
    for keys in ["khoee", "hoaan", "tauw", "cuwuc", "khoeoo", "taiw"] {
      XCTAssertEqual(telex(keys), keys,
        "\(keys): vần sau khi áp mũ không tồn tại ⇒ phải về phím thô")
    }
    // Và các vần CÓ mũ hợp lệ vẫn đi qua nguyên vẹn.
    XCTAssertEqual(telex("khuaan"), "khuân")
    XCTAssertEqual(telex("dduwowngf"), "đường")
    XCTAssertEqual(telex("ruowuj"), "rượu")
    XCTAssertEqual(telex("tieengs"), "tiếng")
  }

  // MARK: R6 — guard "nguyên âm ba" (E4) chặn quá rộng

  /// E4 chặn 'o' thứ hai của "oeo"/"oao" bị hiểu nhầm thành lệnh mũ. Guard đầu
  /// tiên chỉ hỏi "ký tự liền trước có phải nguyên âm KHÁC không" — quá rộng:
  /// "toio" cũng khớp (liền trước là 'i') nên rơi xuống phím thô, mất lối gõ mũ
  /// TRỄ sau nguyên âm. Nay có thêm vế bắt buộc: cụm nguyên âm NỐI THÊM ký tự
  /// này phải là vần CÓ THẬT. "oe"+o = "oeo" có thật ⇒ nguyên âm ba; "oi"+o =
  /// "oio" không tồn tại ⇒ chắc chắn là lệnh đặt mũ.
  func testR6_LateCircumflexAfterAnotherVowelStillWorks() {
    XCTAssertEqual(telex("toio"), "tôi", "[HỒI QUY] mũ trễ sau NGUYÊN ÂM")
    XCTAssertEqual(telex("theme"), "thêm", "[FIX GỐC] mũ trễ sau PHỤ ÂM CUỐI")
    XCTAssertEqual(telex("toong"), "tông")
  }

  /// R6 [FIX GỐC] — nguyên âm ba vẫn KHÔNG được coi là lệnh đặt mũ. Đây chính
  /// là lưới đã bắt được lần siết quá tay đầu tiên của E4.
  func testR6_TripleVowelIsStillNotACircumflexCommand() {
    XCTAssertEqual(telex("khoeo"), "khoeo")
    XCTAssertEqual(telex("ngoeo"), "ngoeo")
    XCTAssertEqual(telex("ngoeos"), "ngoéo")
    XCTAssertEqual(telex("khoeof"), "khoèo")
    XCTAssertEqual(telex("ngoeoj"), "ngoẹo")
    XCTAssertEqual(telex("khoeor"), "khoẻo")
    XCTAssertEqual(telex("ngoaos"), "ngoáo")
    XCTAssertEqual(telex("ngoaor"), "ngoảo")
  }

  // MARK: R7 — "đối xứng hoa/thường" làm MẤT CHỮ trong tên camelCase

  /// Xem `EngineFixesV423Tests.testE5_CircumflexCaseAsymmetryIsIntentional` cho
  /// lập luận; đây là chiều mà E5 gốc không hề đo. Chiều `aA` → `â` khiến chữ
  /// HOA nuốt chữ thường liền trước, và nuốt ÂM THẦM — người gõ không thấy gì
  /// bất thường cho tới khi đọc lại tên biến.
  func testR7_CircumflexCaseAsymmetryKeepsCamelCaseNamesIntact() {
    // [HỒI QUY] tên camelCase phải đi qua NGUYÊN VẸN.
    XCTAssertEqual(telex("dataAccess"), "dataAccess", "chiều aA→â làm mất chữ 'a'")
    XCTAssertEqual(telex("photoObject"), "photoObject")
    XCTAssertEqual(telex("LeEm"), "LeEm")

    // [FIX GỐC] chiều `Aa` → `Â` (Shift ở phím ĐẦU = viết hoa cả từ) vẫn chạy,
    // và các đường thuần một kiểu chữ không đổi.
    XCTAssertEqual(telex("Aa"), "Â")
    XCTAssertEqual(telex("Leem"), "Lêm")
    XCTAssertEqual(telex("AAn"), "Ân")
    XCTAssertEqual(telex("aa"), "â")
  }

  // MARK: R9 — Free Mark: docstring nói "TOÀN BỘ", hành vi là "gần như toàn bộ"

  /// Bản vá R9 sửa TÀI LIỆU và giữ nguyên hành vi E9, nên phần khoá được là
  /// đúng cái tài liệu mới hứa — và phải khoá CẢ HAI vế của chữ "gần như", vì
  /// hiểu lệch vế nào cũng dẫn tới một bản vá sai.
  func testR9_FreeMarkLoosensStructureButKeepsTheCheckedToneRule() {
    let saved = Defaults[.freeMarkModeEnabled]
    Defaults[.freeMarkModeEnabled] = true
    defer { Defaults[.freeMarkModeEnabled] = saved }

    // VẾ 1 — "gần như TOÀN BỘ": Free Mark VẪN nới cấu trúc vần. Đây là lý do
    // tồn tại của công tắc (tên riêng, tiếng dân tộc) và là chiều dễ bị siết
    // nhầm nhất khi ai đó đọc E9 rồi tưởng Free Mark đã bị vô hiệu hoá.
    XCTAssertEqual(telex("khoee"), "khôe", "Free Mark bật: vần ôe được phép")
    XCTAssertEqual(telex("tauw"), "taư")
    XCTAssertEqual(telex("cuwuc"), "cuưc")
    XCTAssertEqual(telex("xeengr"), "xểng")

    // VẾ 2 — "KHÔNG phải toàn bộ": luật thanh nhập là tuyệt đối, vẫn chạy.
    for word in ["art", "chart", "soft", "hurt", "hocr", "latf", "machx", "hopf", "bakr"] {
      XCTAssertEqual(telex(word), word,
        "Free Mark bật: '\(word)' không được biến thành âm tiết thanh-nhập bất khả")
    }
    // Sắc/nặng trên phụ âm tắc thì hợp lệ, không được chặn nhầm.
    XCTAssertEqual(telex("batj"), "bạt")
    XCTAssertEqual(telex("bats"), "bát")
  }

  /// R9 — cái Free Mark MẤT đi vì E9, đo tường minh: đúng nhóm âm tiết kết bằng
  /// phụ âm tắc mang huyền/hỏi/ngã. Hai điều được khoá ở đây:
  ///   1. nhóm đó hỏng ra CHUỖI PHÍM THÔ — người gõ nhìn thấy ngay đúng phím
  ///      mình bấm, không phải kiểu mất chữ âm thầm;
  ///   2. bật/tắt công tắc cho kết quả Y HỆT — tức E9 không lấy mất của Free
  ///      Mark âm tiết tiếng Việt nào, chỉ lấy mất tổ hợp bất khả.
  func testR9_FreeMarkCostIsRawKeysAndIdenticalWithSwitchOff() {
    let saved = Defaults[.freeMarkModeEnabled]
    defer { Defaults[.freeMarkModeEnabled] = saved }
    let words = ["hocr", "latf", "machx", "hopf", "bakr"]

    Defaults[.freeMarkModeEnabled] = false
    let off = words.map { telex($0) }
    Defaults[.freeMarkModeEnabled] = true
    let on = words.map { telex($0) }

    XCTAssertEqual(on, words, "hỏng ra phím THÔ, nhìn thấy được")
    XCTAssertEqual(on, off, "công tắc Free Mark không đổi kết quả của luật tuyệt đối")
  }

  // MARK: R8 — giá của việc gỡ "kr" khỏi bảng chặn (P6), chưa vá, đã đo

  /// Bản vá đợt này CỐ Ý chỉ sửa comment: gate theo chữ hoa không phân biệt được
  /// hai bên ("Krông" viết hoa thì "Kris"/"Kraft"/"Krispy Kreme" cũng viết hoa),
  /// còn fix đúng tầng là siết vần cho phụ âm đầu "kr" trong `TiengVietValidator`
  /// — hiện "kr" nhận MỌI vần nên "kri" được coi là âm tiết hợp lệ và ăn được
  /// dấu.
  ///
  /// ⚠️ Khoá HÀNH VI HIỆN TẠI, không phải hành vi mong muốn: `telex("kris")` ra
  /// "krí" là LỖI CÒN TỒN. Siết đúng tầng sẽ làm dòng đó FAIL — khi ấy CẬP NHẬT
  /// kỳ vọng, đừng đưa "kr" trở lại `impossible2LetterPrefixes` (làm vậy là giết
  /// lại Krông Pắc / Krông Ana / Krông Bông).
  func testR8_KrPrefixTradeoffIsMeasuredNotHidden() {
    // [FIX GỐC] địa danh Tây Nguyên gõ được.
    XCTAssertEqual(telex("kroong"), "krông")
    XCTAssertEqual(telex("krong"), "krong")
    // Từ tiếng Anh kr… tự hồi phục ở phím kế tiếp — khoá muộn hơn 1 phím.
    XCTAssertEqual(telex("kraft"), "kraft")
    XCTAssertEqual(telex("krill"), "krill")
    XCTAssertEqual(telex("kremlin"), "kremlin")
    XCTAssertEqual(telex("krispy"), "krispy", "nháy 'krí'→'kríp' rồi hồi phục ở 'y'")
    // GIÁ đã biết: 4 ký tự là hết từ nên không còn phím nào để hồi phục.
    XCTAssertEqual(telex("kris"), "krí", "GIÁ đã đo — xem docstring trước khi 'sửa'")
  }

  // MARK: R3 — hàng rào thứ tự phím: ĐÃ THỬ, ĐÃ LÙI (v4.24), KHÔNG có test
  //
  // Chỗ này từng giải thích vì sao cơ chế hoãn phím của v4.23 không viết được
  // test. Cơ chế đó nay đã GỠ HẲN (`pendingReplacements`, `noteReplacementEnqueued`,
  // `hasPendingReplacements`, `passThroughOrDefer`), cùng với miễn trừ
  // `.stepByStep` trong `effectiveTypingStrategy`. Ghi lại để lần sau không ai
  // vá lại một cách mù quáng:
  //
  //   • LỖI GỐC (P5, có thật, VẪN CÒN): nhánh `bs<=1 && diff<=1 → .batch` hạ cả
  //     app whitelist `.stepByStep` (Telegram, Terminal/Warp, Claude, Dock…)
  //     xuống `.batch`, tức bỏ mất `usleep(3000)` chắn hai đầu backspace — đúng ở
  //     nhóm phím PHỔ BIẾN NHẤT (dd→đ, aa→â, ee→ê, w→ư/ơ, và mọi phím dấu gõ
  //     ngay sau nguyên âm cuối). Nhóm đó mất cushion.
  //   • ĐÃ VÁ THẾ NÀO: (1) miễn trừ `.stepByStep` khỏi downgrade; rồi (2) khi (1)
  //     dựng lại đúng race mà downgrade sinh ra để tránh ("push" → "pussh": phím
  //     'h' không đổi gì nên đi THẲNG qua event tap, vượt mặt backspace còn nằm
  //     trên `simulationQueue`), thêm một "sổ nợ" hàng đợi để NUỐT phím tới và
  //     phát lại nó bằng `sendString` ở cuối hàng đợi.
  //   • HỒI QUY ĐẺ RA (nặng hơn bệnh): `sendString` KHÔNG đi đường `.axDirect`,
  //     nên trong Spotlight/omnibox — đúng những ô phải dùng axDirect vì chúng
  //     nuốt synthetic event — ký tự hoãn MẤT HẲN. Và Enter/Tab thì không hoãn
  //     được (chúng mang ngữ nghĩa submit/chuyển field mà `sendString` không tái
  //     tạo): trong app chat `.stepByStep`, gõ "chaof" rồi Enter là GỬI ĐI tin
  //     "chao", còn backspace + "ò" rơi vào ô soạn của tin KẾ TIẾP.
  //   • QUYẾT ĐỊNH: sống chung với P5. Thiếu cushion thì thỉnh thoảng rớt/lặp một
  //     ký tự và người dùng gõ lại được; hai bản vá kia làm mất chữ trong
  //     Spotlight và gửi tin nhắn dở.
  //
  // Vì sao vẫn KHÔNG có test, kể cả nếu ai đó vá lại:
  //   • `effectiveTypingStrategy` (và cả cụm đã gỡ) đều `private` —
  //     `@testable import` chỉ mở tới `internal`, không gọi được từ đây.
  //   • Thứ bị vá là THỨ TỰ TỚI APP của các event, mà mọi nhánh đều kết thúc bằng
  //     `CGEvent.post` THẬT vào app đang focus của máy chạy test. Một test trung
  //     thực phải gõ vào app thật rồi đọc lại nội dung ô — kiểm thử tích hợp, và
  //     nó phá màn hình người chạy.
  //   • Nhịp bị khoá là cửa sổ ~8ms giữa hai phím; mô phỏng bằng `usleep` cho ra
  //     kết quả phụ thuộc tải máy — test nhấp nháy còn tệ hơn không có test.
  //
  // Phần CÒN khoá được nằm ở `AppSendingStrategyTests`: bảng
  // `EventSimulator.getStrategy(for:)` phải tiếp tục trả `.stepByStep` cho
  // Dock/Terminal/Telegram/Zalo/Slack… ⚠️ Ranh giới dễ đọc nhầm: bảng đó là chiến
  // lược MẶC ĐỊNH theo app, còn `effectiveTypingStrategy` VẪN được phép hạ nó
  // xuống `.batch` ở ca diff 1 ký tự (đó chính là P5). Đừng đọc các test kia như
  // bằng chứng rằng mọi lần gửi tới Telegram đều đi `.stepByStep`.
}

// MARK: - ===========================================
// MARK: - v4.24 (R1) — "app đang nhận phím": bộ phân giải MỘT-NGUỒN ĐÃ LÙI
// MARK: - ===========================================
//
// v4.23 gộp hai khối ghi `activeApp` trong `EventHook.eventTapCallback` thành
// MỘT bộ phân giải (overlay AX → event-target PID → cache) và kéo ảnh chụp AX
// lên chạy sớm hơn. Bản gộp đó ĐÃ LÙI (v4.24): nó chỉ an toàn khi đi kèm
// `newWord()` trong `changeActiveApp`, mà cặp ấy biến dao động `activeApp` vô
// hại thành xoá bộ đệm mỗi phím → không dấu nào hình thành nữa.
//
// HEAD hôm nay lại có hai khối, và `activeApp` lại được phép dao động ở overlay.
// Điều đó KHÔNG SAO — hậu quả duy nhất là đặt lại chiến lược gửi, vì không còn
// ai xoá bộ đệm theo nó. Hai test dưới đây khoá đúng ranh giới ấy.
final class AppSwitchResolverV424Tests: XCTestCase {

  private var savedZWJF = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.allowedZWJF] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  /// R1 — `activeApp` được phép DAO ĐỘNG; bộ đệm từ thì KHÔNG được chết theo.
  ///
  /// Trên macOS 26 với Smart Switch TẮT, gõ vào Spotlight: `eventTargetUnixProcessID`
  /// trả app NỀN (vd Excel) còn ảnh AX trả `com.apple.Spotlight`. Hai khối trong
  /// `EventHook.eventTapCallback` ghi `input.activeApp` từ hai nguồn đó, nên giá
  /// trị kéo qua kéo lại MỖI PHÍM. Đó là sự thật của HEAD và vkey sống chung với
  /// nó.
  ///
  /// ⚠️ ĐÂY LÀ TRIPWIRE CHO MỘT QUYẾT ĐỊNH, KHÔNG PHẢI TEST KHOÁ MỘT FIX. Bản
  /// v4.23 cho `changeActiveApp` gọi `newWord()`; cộng với dao động trên, mỗi
  /// phím thành một lần "đổi app" ⇒ `transformed` luôn rỗng ⇒ không dấu nào hình
  /// thành ⇒ gõ tiếng Việt âm thầm biến thành gõ tiếng Anh ở MỌI app. Bản vá đó
  /// đã lùi; test này đỏ đúng lúc ai đó dựng lại nó.
  ///
  /// CỐ Ý KHÔNG assert chiều ngược lại (đổi app THẬT có xoá đệm hay không): P1 là
  /// lỗi đang được chấp nhận sống chung — xem khối chú thích trong
  /// `AppSwitchBoundaryV423Tests` và docstring (a)→(d) của
  /// `InputProcessor.changeActiveApp`. Một bản vá P1 ĐÚNG trong tương lai (điều
  /// kiện tiên quyết: chứng minh trên máy thật rằng `activeApp` ổn định mỗi phím)
  /// sẽ phải sửa chính test này một cách CÓ CHỦ Ý, sau khi đọc hết lịch sử đó.
  func testR1_ActiveAppPingPongMustNotTouchTheWordBuffer() throws {
    let overlay = "com.apple.Spotlight"
    let background = "com.microsoft.Excel"

    // Hai nguồn bất đồng bộ ⇒ mỗi phím phân giải ra một app khác. Dấu vẫn phải
    // hình thành đủ trên cả cụm.
    let pingPong = InputProcessor(method: .Telex)
    pingPong.changeActiveApp(overlay)
    pingPong.newWord()
    var flip = false
    for c in "tieengs" {
      flip.toggle()
      pingPong.changeActiveApp(flip ? background : overlay)
      pingPong.push(char: c)
    }
    XCTAssertEqual(pingPong.transformed, "tiếng",
      "dao động activeApp từng phím KHÔNG được đụng tới bộ đệm từ")

    // Đối chứng: phân giải ổn định (ca gõ Spotlight bình thường) cũng ra "tiếng"
    // — nếu ca này đỏ thì lỗi nằm ở engine, không ở ranh giới đổi app.
    let stable = InputProcessor(method: .Telex)
    stable.changeActiveApp(overlay)
    stable.newWord()
    for c in "tieengs" {
      stable.changeActiveApp(overlay)
      stable.push(char: c)
    }
    XCTAssertEqual(stable.transformed, "tiếng")
  }

  /// R1 — ba viên gạch thuần mà đường nhận diện "app đang nhận phím" của HEAD
  /// vẫn đi qua. Bộ phân giải gộp của v4.23 đã lùi, nhưng cả `isOverlayBundle`
  /// lẫn `canonicalAppBundle` đều CÓ SẴN ở HEAD và vẫn được `EventHook` gọi —
  /// nếu một trong ba đổi nghĩa thì việc nhận diện app đổi hành vi mà chẳng test
  /// nào khác nhìn thấy.
  func testR1_ResolverBuildingBlocksKeepTheirMeaning() throws {
    // Nhánh 1 — overlay đang thực-focus THẮNG event-target PID (bằng chứng
    // v4.11: `eventTargetUnixProcessID` trả app NỀN cho phím Spotlight trên
    // macOS 26). Ở HEAD, danh sách overlay là thứ quyết định `focusedOverlayBundle()`
    // có ghi đè bundle của event-target hay không, khi Smart Switch BẬT.
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.Spotlight"))
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.dock"))
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.systemuiserver"))
    // App thường KHÔNG được coi là overlay: coi nhầm thì cache focused-bundle
    // (vốn chỉ ghi khi AX trả về bundle, nên DÍNH) biến thành latch overlay —
    // đúng thứ v4.11 đã gỡ và bản vá này không được dựng lại.
    XCTAssertFalse(EventSimulator.isOverlayBundle("com.microsoft.Excel"))
    XCTAssertFalse(EventSimulator.isOverlayBundle("com.google.Chrome"))

    // Nhánh 2/3 — giá trị phân giải xong còn phải quy về app CHA, nếu không mỗi
    // phím trong hộp thoại Lưu lại là một lần "đổi app" (lỗi v4.22: "Nooij" →
    // "Nôị"). Cả hai khối ghi `activeApp` ở HEAD đều đi qua đúng hàm này.
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(
        focused: "com.apple.appkit.xpc.openAndSavePanelService",
        frontmost: "com.apple.TextEdit"),
      "com.apple.TextEdit")
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.Safari.SandboxBroker",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari")
    // …mà app khác THẬT thì vẫn phải nhận ra là khác — nếu không, chiến lược gửi
    // của app này bị áp cho app kia (và một bản vá P1 tương lai cũng chết theo).
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.google.Chrome",
                                        frontmost: "com.apple.Safari"),
      "com.google.Chrome")
  }
}

// MARK: - ===========================================
// MARK: - v4.24 (R5) — vì sao đọc hụt AXRole vẫn phải LEO PARENT
// MARK: - ===========================================
//
// CẢ HAI bản vá R5 đã bị LÙI (v4.24): (1) `Focused.fieldKind(from:)` bỏ cuộc sớm
// và trả `.unknown` khi đọc hụt `AXRole`; rồi (2) cờ `fieldKindIsReliable` +
// `AppState.adoptFieldKind` đóng băng phân loại suốt một từ. HEAD lại leo parent
// khi đọc hụt, không có cờ tin cậy, không đóng băng — lý do đầy đủ (a)→(d) nằm
// trong docstring của `Focused.fieldKind(from:)`.
//
// PHẠM VI của cả lớp này: `Focused.fieldKind(from:)` là `private` và đòi một
// `AXUIElement` sống của cây AX thật, thứ không dựng được trong unit test. Nên ở
// đây khoá HAI HỆ QUẢ của việc để `.unknown` lọt ra — đó cũng đúng là hai lý do
// khiến bản vá (1) bị lùi, và là hai thứ sẽ hỏng nếu ai đó dựng nó lại.
final class FocusedFieldStabilityV424Tests: XCTestCase {

  /// R5 (a) — hệ quả thứ nhất của `.unknown`: thanh địa chỉ Chrome MẤT
  /// `.axDirect`, vì `focusedFieldIsBrowserChrome()` đòi đúng `.windowField`.
  /// Mất axDirect là quay lại synthetic backspace trong ô có inline autocomplete
  /// bôi đen — đúng lỗi "trường" → "truường" mà axDirect sinh ra để tránh.
  ///
  /// Đây là hồi quy mà bản vá "đọc hụt `AXRole` thì bỏ cuộc sớm" của v4.23 gây
  /// ra: chỉ cần MỘT lần đọc hụt ở node trong cùng là omnibox rơi về synthetic
  /// backspace suốt phần còn lại của từ. Bản vá đã lùi; test ở lại vì nó khoá
  /// đúng ranh giới mà bất kỳ vòng vá nào sau này cũng phải giữ.
  func testR5_UnknownFieldKindWouldCostTheOmniboxItsAxDirect() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp("com.google.Chrome")

    p.focusedFieldKind = .windowField
    XCTAssertTrue(p.focusedFieldIsBrowserChrome(),
      "omnibox = windowField của app nhóm NFD ⇒ axDirect")

    p.focusedFieldKind = .unknown
    XCTAssertFalse(p.focusedFieldIsBrowserChrome(),
      "bỏ cuộc sớm ở một node đọc hụt ⇒ omnibox rơi về synthetic backspace")

    // Đối chứng: windowField trong app NHÓM NFC (Notes) KHÔNG phải browser-chrome
    // — ranh giới này phải giữ, không thì axDirect bị ép vào mọi cửa sổ.
    p.changeActiveApp("com.apple.Notes")
    p.focusedFieldKind = .windowField
    XCTAssertFalse(p.focusedFieldIsBrowserChrome())
  }

  /// R5 (b) — hệ quả thứ hai: một hiccup AX giữa từ vẫn LẬT TRỤC, chỉ đổi chiều.
  /// Trong app nhóm NFD ngoài whitelist, `.windowField` đi trục NFC còn `.unknown`
  /// đi trục NFD, mà hai trục đếm backspace KHÁC NHAU cho cùng một bước chuyển.
  /// Ký tự 1–3 phát theo trục A, ký tự 4 đếm theo trục B ⇒ lệch backspace ⇒ ăn
  /// ngược vào chữ đã gõ (đúng lớp lỗi v4.14 "đếm một đằng, phát một nẻo").
  ///
  /// Vì thế bản vá "bỏ cuộc sớm" không giải quyết được gì — nó chỉ đổi chiều lật.
  /// Vòng vá kế tiếp (đóng băng phân loại suốt một từ bằng `AppState.adoptFieldKind`)
  /// cũng ĐÃ LÙI: nó so app bằng bundle id THÔ trong khi AX nhảy qua lại giữa app
  /// cha và tiến trình phụ (hộp thoại Lưu của app sandbox, helper của Chromium),
  /// nên chốt tự mở lại gần như mỗi phím — thêm một tầng trạng thái mà không chặn
  /// được gì.
  ///
  /// CA HỎNG CÒN LẠI (F1, chấp nhận sống chung): cần đúng một hiccup AX rơi vào
  /// giữa một từ. Muốn vá lại thì chốt phải đặt ở chỗ ĐẾM backspace (bất biến
  /// "dạng emit == dạng đếm" của v4.15), KHÔNG phải ở chỗ ĐO field, và phải nhận
  /// diện app theo `InputProcessor.canonicalAppBundle` chứ không so bundle id
  /// thô. Hai con số 2 vs 3 dưới đây là thước đo độ lệch đó.
  func testR5_FieldKindFlipMidWordChangesTheBackspaceArithmetic() throws {
    let (nfcBs, _) = EventSimulator.calcKeyStrokes(from: "điêu", to: "điều")
    let (nfdBs, _) = EventSimulator.calcKeyStrokesNFD(from: "điêu", to: "điều")
    XCTAssertEqual(nfcBs, 2)
    XCTAssertEqual(nfdBs, 3)
    XCTAssertNotEqual(nfcBs, nfdBs,
      "hai trục KHÔNG hoán đổi được giữa chừng một từ")

    // Và đây đúng là hai giá trị mà một lần đọc AX hụt hoán đổi được.
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp("com.tinyspeck.slackmacgap")   // Electron, ngoài whitelist NFC
    p.focusedFieldKind = .windowField
    XCTAssertTrue(p.usesNFCForFocusedField(), "đọc được ⇒ windowField ⇒ trục NFC")
    p.focusedFieldKind = .unknown
    XCTAssertFalse(p.usesNFCForFocusedField(), "đọc hụt ⇒ unknown ⇒ trục NFD")

    // [FIX GỐC v4.14] Đối chứng: app trong whitelist NFC short-circuit TRƯỚC
    // fieldKind, nên hiccup không lật được trục — hàng rào cũ vẫn còn nguyên.
    let telegram = InputProcessor(method: .Telex)
    telegram.changeActiveApp("ru.keepcoder.Telegram")
    for kind in [Focused.FieldKind.windowField, .unknown, .webContent, .nativePanel] {
      telegram.focusedFieldKind = kind
      XCTAssertTrue(telegram.usesNFCForFocusedField(),
        "\(kind): app whitelist NFC không được đổi trục theo fieldKind")
    }
  }

  // ⚠️ ĐÃ XOÁ (v4.24) — `testR5_SnapshotWithoutFocusedElementIsMarkedReliable`.
  //
  // Test đó khoá `snap.fieldKindIsReliable == true` cho nhánh "không có focused
  // element" của `Focused.snapshot()` — tức khoá đúng cờ tin cậy mà bản vá R5
  // vòng hai thêm vào `FocusSnapshot`. Cờ đó đã bị GỠ cùng
  // `AppState.adoptFieldKind`, nên test KHÔNG BIÊN DỊCH ĐƯỢC nữa; nó đi theo cơ
  // chế của nó thay vì được "sửa cho biên dịch được" (phần còn lại —
  // `fieldKind == .unknown`, `isComboOrSearch == false` — chỉ chạy khi máy chạy
  // test tình cờ không có focused element, nên không khoá được gì).
  //
  // VÌ SAO GỠ CỜ: cổng đóng băng dùng nó so app bằng bundle id THÔ, trong khi AX
  // nhảy qua lại giữa app cha và tiến trình phụ (hộp thoại Lưu của app sandbox,
  // helper của Chromium) — chốt tự mở lại gần như mỗi phím: thêm một tầng trạng
  // thái mà không chặn được gì. Vòng vá TRƯỚC đó ("đọc hụt thì bỏ cuộc sớm, trả
  // `.unknown`") còn tệ hơn: nó làm omnibox Chrome mất `.axDirect` thường trực —
  // xem `testR5_UnknownFieldKindWouldCostTheOmniboxItsAxDirect`.
  //
  // CA HỎNG QUAY LẠI (F1 — chấp nhận sống chung): một hiccup AX rơi đúng vào giữa
  // một từ lật `fieldKind` `.windowField` ↔ `.unknown`, hai bên trục NFC/NFD, nên
  // ký tự đầu từ phát theo trục này còn ký tự sau đếm backspace theo trục kia ⇒
  // lệch backspace ⇒ ăn ngược vào chữ đã gõ.
  // `testR5_FieldKindFlipMidWordChangesTheBackspaceArithmetic` ở trên đo đúng độ
  // lệch đó (2 vs 3) và ở lại làm chứng cứ.
}

// MARK: - ===========================================
// MARK: - T4 — ĐƠN VỊ XOÁ CỦA Ô NHẬP (phép đo, không phải giả định)
// MARK: - ===========================================
//
// Đo ngày 2026-08-23 bằng `Tools/probe` (macOS 26, Apple Silicon): đặt sẵn `x`+`ề`
// vào ô ở hai dạng chuẩn hoá, gửi ĐÚNG MỘT Backspace, đọc lại. vkey KHÔNG tham
// gia phép đo — đo chính bản thân ô nhập.
//
//   Ô                            NFD (4 scalar)            ⇒ đơn vị xoá
//   AppKit / NSTextView          4 scalar → 1 scalar       ⇒ GRAPHEME
//   Blink <input type=text>      4 scalar → 3 scalar       ⇒ SCALAR
//   Blink contenteditable        4 scalar → 3 scalar       ⇒ SCALAR
//
// (`contenteditable` chính là loại ô Zalo / Messenger / Slack / Discord dùng để
// soạn tin — tức nhánh NFD của vkey.)
//
// ⇒ HAI ENGINE XOÁ THEO HAI ĐƠN VỊ KHÁC NHAU. Nhưng điều đó KHÔNG biến nhánh nào
// hiện tại thành sai, vì bất biến v4.15 — "dạng PHÁT RA == dạng dùng để ĐẾM" —
// làm cả hai nhánh tự nhất quán:
//
//   • Nhánh NFD (Zalo/Messenger/Slack/Discord — Electron ngoài whitelist NFC):
//     vkey phát NFD ⇒ ô giữ NFD; vkey đếm scalar; Blink xoá scalar. KHỚP.
//   • Nhánh NFC (Chrome web content từ v4.21; omnibox; app Apple):
//     vkey phát NFC ⇒ ô giữ NFC; mà ở dạng NFC 1 grapheme ĐÚNG BẰNG 1 scalar,
//     nên đếm grapheme cũng ra đúng số backspace dù engine xoá theo scalar. KHỚP.
//
// ⚠️ NGƯỜI ĐỌC SAU: ĐỪNG "SỬA" TRỤC CỦA BẤT KỲ APP NÀO VÌ THẤY BẢNG TRÊN.
// Bảng trên nói đơn vị xoá KHÁC NHAU; nó KHÔNG nói việc gán trục đang sai. Việc
// gán trục hiện tại (`usesNFCGraphemeStorage`, nhánh `.webContent → isBrowserApp`,
// `nfcNativeEditorBundlePrefixes`) đã được phép đo này XÁC NHẬN là đúng cho cả
// hai nhánh. Lỗi "mất chữ" ở Zalo/Messenger KHÔNG phải lỗi trục chuẩn hoá — tìm ở
// T1 (đổi app giữa từ) và T2 (thứ tự phím). Chi tiết: `Tools/probe/README.md`.
//
// ⚠️ RỦI RO CÒN LẠI, CHƯA ĐO: cả hai nhánh chỉ đúng khi ô đang chứa chữ DO CHÍNH
// VKEY PHÁT RA. Chữ đến từ nguồn khác ở dạng khác (dán vào, app tự điền, chữ gõ
// trước khi đổi app) thì số đếm lệch. Đây là ca đáng đo tiếp, đừng suy đoán.
//
// (Ghi chú: khối ⚠️ "GIỚI HẠN CỦA PHÉP ĐO" trong `InputProcessor.usesNFCForFocusedField`
// nói phép đo này CHƯA TỪNG làm — nay đã làm; comment đó đã cũ.)

// MARK: - ===========================================
// MARK: - T3 — CHỐT TRỤC THEO TỪ: ĐÃ THỬ, ĐÃ LÙI
// MARK: - ===========================================
//
// ĐỌC KHỐI NÀY TRƯỚC KHI VÁ LẦN THỨ NĂM.
//
// T3 KHÔNG đổi trục của app nào. Nó đổi THỜI ĐIỂM quyết định trục: từ "đo lại mỗi
// phím" (13 chỗ tự gọi `usesNFCForFocusedField()`) thành "đo MỘT lần rồi chốt tới
// hết TỪ" — chốt cất trong `WordBuffer`, `newWord()` là đường mở khoá duy nhất,
// `EventHook` chỉ chụp AX ở ranh giới từ. Cơ chế chạy được; hai vòng rà soát đối
// kháng còn tìm thêm 4 lỗi mức CAO và vá xong cả 4. Nó VẪN BỊ LÙI, vì lý do không
// nằm ở cài đặt mà ở TIỀN ĐỀ:
//
//   (1) PHÉP ĐO Ở PHÍM 1 LÀ PHÉP ĐO TỆ NHẤT (ngay sau click/⌘S, AX còn trả ô CŨ),
//       nhưng ở bản đo-mỗi-phím nó KHÔNG CÓ HẬU QUẢ: phím 1 luôn cho
//       `lastTransformed == ""` ⇒ `bs == 0`, chỉ chèn một ký tự ASCII, trục không
//       quan sát được. Phép đo THẬT SỰ có hậu quả là phím đầu tiên SINH DẤU
//       (thường phím 3–5, tức 200–500ms sau khi focus đổi) — lúc AX đã lắng.
//       Chốt theo từ lấy đúng phép đo tệ nhất rồi dán nó lên cả từ.
//   (2) TRỤC SAI KHÔNG ĐỐI XỨNG. Chốt nhầm NFC trong ô Blink là VÔ HẠI: ở dạng NFC
//       1 grapheme đúng bằng 1 scalar (đã ĐO — xem khối T4 ngay trên và
//       `Tools/probe/README.md`). Chốt nhầm NFD trong ô AppKit thì hỏng CÂM: gõ
//       `Nooij` ra `Ṇ̂i`. Độ lệch của đúng ca đó nằm trong `HeadParityGoldenTests`
//       — `Nooij` cần 2 backspace ở trục NFC nhưng 3 ở trục NFD.
//   (3) TRONG CA ⌘S mở hộp thoại Lưu của app Electron, đo-mỗi-phím TỰ HỘI TỤ VỀ
//       ĐÚNG (phép đo ôi bị thay ngay phím kế tiếp, mà chiều lật NFD→NFC là chiều
//       LÀNH theo (2)); chốt thì đóng băng cái sai cho trọn từ.
//
// ⇒ Đổi một lỗi ngẫu nhiên hiếm lấy một lỗi hệ thống trong thao tác hằng ngày.
//
// ĐIỀU KIỆN TIÊN QUYẾT NẾU MUỐN THỬ LẠI — hai con số, ĐO TRƯỚC bằng `Tools/probe`,
// đừng suy đoán: (i) trục có THẬT SỰ lật giữa một từ không, và bao lâu một lần;
// (ii) sau click/⌘S thì bao lâu AX mới báo đúng ô. Nếu (ii) NHỎ HƠN khoảng cách
// tới phím sinh dấu đầu tiên thì chốt không giải quyết vấn đề gì cả. Không có hai
// con số đó thì mọi hàng rào quanh chốt chỉ là phỏng đoán. Xem
// `InputProcessor.emitPlan()` và `Focused.fieldKind(from:)` mục (e)/(f).
//
// THỨ SỐNG SÓT của cả đợt — và là thứ đáng có lưới — là `EmitPlan`: refactor
// THUẦN KIỂU, không nhớ gì, không đổi một byte nào của chuỗi phát ra, chỉ biến bất
// biến v4.15 ("dạng ĐẾM == dạng PHÁT") từ quy ước review thành ràng buộc compiler.
// Lưới cho nó: `EmitPlanTypeConstraintTests` và `HeadParityGoldenTests` phía dưới.
//
// ⚠️ TÊN LỚP `EmitPlanWordLockT3Tests` LÀ TÊN LỊCH SỬ — không còn "word lock" nào
// để khoá. Ba test còn lại trong lớp khoá đúng ba thứ sống sót: bảng app × field →
// trục cùng phép đo T4 chống lưng nó, tính đồng nhất với thuật toán tiền-refactor,
// và bất biến đếm-==-phát ở `pop`.

/// Một bước phát, so sánh được. `scalars` CÓ MẶT CÓ LÝ DO: Swift so sánh `String`
/// theo TƯƠNG ĐƯƠNG CHUẨN TẮC, nên "ếng" dạng NFC `==` "ếng" dạng NFD — mà chính
/// hai dạng đó mới là thứ đi ra dây. Thiếu số scalar thì test mù đúng chỗ cần nhìn.
private struct T3EmitStep: Equatable, CustomStringConvertible {
  let bs: Int
  let text: String
  let scalars: Int
  init(_ bs: Int, _ chars: [Character]) {
    self.bs = bs
    let s = String(chars)
    self.text = s
    self.scalars = s.unicodeScalars.count
  }

  /// Init cho BẢNG VÀNG đo trên HEAD (`HeadParityGoldenTests`). `text` viết ở dạng
  /// NFC trong source cho dễ đọc, còn `scalars` ghi RỜI — đó là chỗ duy nhất phân
  /// biệt hai trục, vì `==` của `String` so theo tương đương chuẩn tắc nên không
  /// nhìn ra dạng. Đừng "dọn" nó thành `T3EmitStep(bs, Array(text))`: làm thế là
  /// tự tính lại `scalars` từ literal NFC ⇒ mọi dòng vàng NFD hoá thành NFC và
  /// bảng hết khoá được gì.
  init(golden bs: Int, _ text: String, scalars: Int) {
    self.bs = bs
    self.text = text
    self.scalars = scalars
  }

  var description: String { "(bs=\(bs), \"\(text)\", \(scalars) scalar)" }
}

final class EmitPlanWordLockT3Tests: XCTestCase {

  /// Electron ngoài whitelist NFC — cùng lớp với Zalo/Messenger/Discord. Ở app
  /// này `fieldKind` MỚI thật sự quyết định trục (whitelist NFC short-circuit
  /// trước `fieldKind`, nên app Apple/Telegram không dựng được ca lật trục).
  private static let electronApp = "com.tinyspeck.slackmacgap"
  private static let browserApp = "com.google.Chrome"

  private var savedZWJF = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.allowedZWJF] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  // MARK: T4 — phép đo, viết thành assert chạy được

  /// T4 — hai đơn vị xoá, hai cách đếm, và VÌ SAO CẢ HAI ĐỀU ĐÚNG.
  ///
  /// Đây là bản chạy được của bảng đo ở đầu file. Nó khoá đúng ba con số mà mọi
  /// lập luận về trục dựa vào — nếu ai đó "tối ưu" `calcKeyStrokes*` và một trong
  /// ba con số đổi, thì lập luận "trục hiện tại đúng" hết hiệu lực và test này đỏ
  /// TRƯỚC khi người dùng mất chữ.
  func testT4_DeleteUnitPerEngineMatchesTheCountingAxis() throws {
    // Vật liệu của phép đo: `x` + `ề`.
    let sample = "xề"
    XCTAssertEqual(sample.precomposedStringWithCanonicalMapping.unicodeScalars.count, 2,
      "NFC: x + U+1EC1")
    XCTAssertEqual(sample.decomposedStringWithCanonicalMapping.unicodeScalars.count, 4,
      "NFD: x + e + U+0302 + U+0300 — đúng 4 scalar mà probe đã đặt vào ô")

    // AppKit xoá theo GRAPHEME: 1 Backspace ăn trọn cụm 3 scalar (4 → 1).
    // vkey cho field NFC đếm theo grapheme ⇒ 1. Khớp với 1 lần nhấn.
    let (nfcBs, nfcDiff) = EventSimulator.calcKeyStrokes(from: sample, to: "x")
    XCTAssertEqual(nfcBs, 1, "trục NFC đếm grapheme = đúng số phím AppKit cần")
    XCTAssertTrue(nfcDiff.isEmpty)

    // Blink xoá theo SCALAR: mỗi Backspace bóc 1 scalar, nên phải nhấn 3 lần để
    // hết cụm NFD 3 scalar. vkey cho field NFD đếm theo scalar ⇒ 3. Khớp.
    let (nfdBs, nfdDiff) = EventSimulator.calcKeyStrokesNFD(from: sample, to: "x")
    XCTAssertEqual(nfdBs, 3, "trục NFD đếm scalar = đúng số phím Blink cần")
    XCTAssertTrue(nfdDiff.isEmpty)

    // 1 vs 3 — ĐỘ LỆCH mà một lần lật trục giữa từ tạo ra. Đây là lý do T3 tồn
    // tại: không phải để đổi trục, mà để trục KHÔNG ĐỔI GIỮA CHỪNG.
    XCTAssertNotEqual(nfcBs, nfdBs)

    // Và đây là vì sao nhánh NFC vẫn đúng dù Blink xoá theo scalar: ở dạng NFC,
    // 1 grapheme ĐÚNG BẰNG 1 scalar, nên đếm grapheme ra cùng con số với đếm
    // scalar. Bất biến v4.15 ("phát NFC ⇒ ô giữ NFC") là thứ giữ tiền đề này.
    let nfc = sample.precomposedStringWithCanonicalMapping
    XCTAssertEqual(nfc.count, nfc.unicodeScalars.count,
      "ở dạng NFC, đếm grapheme == đếm scalar ⇒ nhánh NFC khớp cả engine xoá scalar")

    // Bảng gán trục — hai đầu mút mà phép đo T4 xác nhận. KHÔNG ĐỔI CÁC DÒNG NÀY.
    let electron = InputProcessor(method: .Telex)
    electron.changeActiveApp(Self.electronApp)
    electron.focusedFieldKind = .webContent
    XCTAssertFalse(electron.usesNFCForFocusedField(),
      "contenteditable của Electron: Blink xoá scalar + vkey phát NFD ⇒ trục NFD. ĐÚNG.")

    let chrome = InputProcessor(method: .Telex)
    chrome.changeActiveApp(Self.browserApp)
    chrome.focusedFieldKind = .webContent
    XCTAssertTrue(chrome.usesNFCForFocusedField(),
      "web content của TRÌNH DUYỆT: vkey phát NFC ⇒ 1 grapheme == 1 scalar ⇒ trục NFC. ĐÚNG.")
  }

  // MARK: [ĐÃ XOÁ] hai test khoá "đo đúng MỘT lần mỗi từ"
  //
  // `testT3_FieldSourceIsReadExactlyOncePerWord` — đếm THẲNG số lần nguồn phân
  // loại field bị đọc (qua điểm bơm `fieldKindProbe`) và khoá con số đó bằng 1
  // cho trọn một từ, kèm "chốt nằm trong `WordBuffer`, `newWord()` là đường mở
  // khoá DUY NHẤT" và "`pop(plan:)` dùng lại chốt chứ không đo lần hai".
  //
  // `testT3_NoisyFieldSourceCannotChangeTheEmittedSequence` — cho nguồn phân loại
  // DAO ĐỘNG từng phím theo một lịch nhiễu cố ý ác (phím 6, tức bước bỏ dấu sắc,
  // rơi vào phía NFD), rồi khoá rằng chuỗi (bs, diff) phát ra không đổi một byte
  // so với nguồn đứng yên. Kèm lưới chống test rỗng: chạy thêm bản đo-mỗi-phím
  // trên CÙNG lịch nhiễu và assert nó KHÁC — phím 6 cho 3 backspace ở trục NFC đã
  // chốt so với 4 ở trục NFD bị lật giữa chừng.
  //
  // XOÁ VÌ CƠ CHẾ ĐÃ LÙI, không phải vì test sai: `lockedEmitPlan`,
  // `storedEmitPlan` và `fieldKindProbe` đã gỡ khỏi production nên hai test này
  // không còn biên dịch được. Lý do lùi (đầy đủ ở đầu MARK này): phép đo ở PHÍM 1
  // là phép đo tệ nhất, mà ở bản đo-mỗi-phím nó lại KHÔNG có hậu quả — chốt theo
  // từ lấy đúng phép đo đó rồi dán lên cả từ; và trong ca ⌘S mở hộp thoại Lưu của
  // app Electron, đo-mỗi-phím TỰ HỘI TỤ VỀ ĐÚNG còn chốt thì đóng băng cái sai.
  //
  // MUỐN DỰNG LẠI: đo trước hai con số ở đầu MARK ((i) trục có lật giữa từ thật
  // không, (ii) độ trễ AX sau click/⌘S), rồi mới bàn tới chốt.
  //
  // KỸ THUẬT ĐÁNG GIỮ nếu có vòng sau: đếm SỐ LẦN ĐỌC NGUỒN thay vì kiểm sự tồn
  // tại của một biến tên là "chốt" — vòng vá (2) chết vì chốt của nó tự mở lại
  // gần như mỗi phím (nó so bundle id THÔ, mà AX nhảy giữa app cha và tiến trình
  // phụ từng phím) trong khi vẫn có đủ biến để một test ngây thơ nhìn thấy.
  // MARK: [KHÔNG HỒI QUY] — ô ổn định ⇒ giống hệt hành vi cũ

  /// [KHÔNG HỒI QUY] — với ô ỔN ĐỊNH, chuỗi (bs, diff) của HEAD GIỐNG HỆT thuật
  /// toán TIỀN-T3, trên cả nhánh NFC lẫn nhánh NFD, và trục/chiến-lược-gửi mà
  /// chốt mang theo đúng bằng giá trị hai resolver trả về.
  ///
  /// ĐÂY LÀ BẰNG CHỨNG "ĐỢT NÀY KHÔNG ĐỔI TRỤC CỦA AI". Bảng dưới liệt kê tường
  /// minh trục kỳ vọng cho từng ô — nếu một bản vá sau này đổi trục của bất kỳ
  /// app nào, test đỏ ở đúng dòng đó, kèm tên app.
  func testT3_StableFieldEmitsExactlyThePreT3Sequence() throws {
    // (app, fieldKind, trục NFC?, browser-chrome?)
    let table: [(String, Focused.FieldKind, Bool, Bool)] = [
      // Nhánh NFD — Electron ngoài whitelist (lớp Zalo/Messenger/Discord).
      (Self.electronApp, .webContent, false, false),
      (Self.electronApp, .unknown, false, false),
      // …trừ chính ô cửa sổ: `.windowField` đi trục NFC ĐÚNG VÌ nó gửi bằng
      // axDirect, mà `axDeleteStart` xoá theo grapheme. Hai vế phải cùng chốt.
      (Self.electronApp, .windowField, true, true),
      (Self.electronApp, .nativePanel, true, false),
      // Nhánh NFC — trình duyệt thật.
      (Self.browserApp, .webContent, true, false),
      (Self.browserApp, .unknown, true, false),
      (Self.browserApp, .windowField, true, true),  // omnibox
      (Self.browserApp, .nativePanel, true, false),
      // Whitelist NFC — short-circuit TRƯỚC fieldKind, nên fieldKind không đổi
      // được gì (và browser-chrome phải TẮT, nếu không axDirect tràn ra mọi cửa sổ).
      ("com.apple.Notes", .webContent, true, false),
      ("com.apple.TextEdit", .windowField, true, false),
      ("ru.keepcoder.Telegram", .webContent, true, false),
      ("com.sublimetext.4", .unknown, true, false),
    ]

    for (app, kind, expectNFC, expectChrome) in table {
      for word in ["tieengs", "ddieeuf"] {
        // HEAD — mọi lần gửi lấy kế hoạch từ chốt.
        let head = InputProcessor(method: .Telex)
        head.changeActiveApp(app)
        head.focusedFieldKind = kind
        var headSeq: [T3EmitStep] = []
        for c in word {
          head.push(char: c)
          let r = head.emitPlan().replacement(from: head.lastTransformed, to: head.transformed)
          headSeq.append(T3EmitStep(r.backspaceCount, r.diffChars))
        }

        // TIỀN-T3 — đo field lại ở mỗi phím. Ô đứng yên nên phải ra y hệt.
        let old = InputProcessor(method: .Telex)
        old.changeActiveApp(app)
        old.focusedFieldKind = kind
        var oldSeq: [T3EmitStep] = []
        for c in word {
          old.push(char: c)
          let (bs, diff) = EventSimulator.calcKeyStrokes(
            from: old.lastTransformed, to: old.transformed,
            usesNFC: old.usesNFCForFocusedField())
          oldSeq.append(T3EmitStep(bs, diff))
        }

        XCTAssertEqual(headSeq, oldSeq,
          "\(app) × \(kind) × \"\(word)\": ô ổn định PHẢI phát giống hệt bản tiền-T3")
        XCTAssertEqual(head.transformed, old.transformed)
        XCTAssertFalse(headSeq.isEmpty, "lưới an toàn: chuỗi rỗng thì so sánh trên là vô nghĩa")
      }

      // Chốt mang đúng giá trị hai resolver trả về — T3 giữ nguyên BẢNG ánh xạ
      // app × field → trục, chỉ đổi THỜI ĐIỂM đọc nó.
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp(app)
      p.focusedFieldKind = kind
      p.push(char: "a")
      let plan = p.emitPlan()
      XCTAssertEqual(plan.usesNFC, expectNFC, "\(app) × \(kind): trục")
      XCTAssertEqual(plan.usesNFC, p.usesNFCForFocusedField(),
        "\(app) × \(kind): chốt phải bằng resolver, không được lệch")
      XCTAssertEqual(plan.fieldIsBrowserChrome, expectChrome, "\(app) × \(kind): axDirect?")
      XCTAssertEqual(plan.fieldIsBrowserChrome, p.focusedFieldIsBrowserChrome(),
        "\(app) × \(kind): vế chiến lược gửi cũng phải bằng resolver")
    }
  }

  /// [KHÔNG HỒI QUY] — Backspace: trục dùng để ĐẾM bên trong `WordBuffer.pop`
  /// đúng bằng trục sẽ PHÁT ra (bất biến v4.15, nay do KIỂU giữ).
  ///
  /// `pop` là đường duy nhất mà số đếm được tính ở NƠI KHÁC (nó phải replay
  /// state trước khi đếm), nên nó cũng là chỗ dễ tuột nhất khỏi bất biến. Test
  /// đối chiếu `pop(plan:)` với `pop(usesNFC:)` thô trên hai processor giống hệt.
  func testT3_PopCountsAndEmitsOnTheSameLockedAxis() throws {
    for (app, kind) in [(Self.electronApp, Focused.FieldKind.webContent),
                        (Self.browserApp, .windowField)] {
      let viaPlan = InputProcessor(method: .Telex)
      viaPlan.changeActiveApp(app)
      viaPlan.focusedFieldKind = kind
      for c in "ddieeuf" { viaPlan.push(char: c) }
      XCTAssertEqual(viaPlan.transformed, "điều")

      let plan = viaPlan.emitPlan()
      let r = viaPlan.pop(plan: plan)
      XCTAssertEqual(r.plan.usesNFC, plan.usesNFC,
        "số đếm và trục phát PHẢI đi chung một giá trị")

      let viaRaw = InputProcessor(method: .Telex)
      viaRaw.changeActiveApp(app)
      viaRaw.focusedFieldKind = kind
      for c in "ddieeuf" { viaRaw.push(char: c) }
      let (bs, diff) = viaRaw.pop(usesNFC: plan.usesNFC)

      XCTAssertEqual(T3EmitStep(r.backspaceCount, r.diffChars), T3EmitStep(bs, diff),
        "\(app) × \(kind): pop(plan:) phải ra đúng cái pop(usesNFC:) ra")
    }
  }

  // MARK: [ĐÃ XOÁ] test khoá cổng chụp AX theo ranh giới từ
  //
  // `testT3_AXSnapshotGateIsExactlyTheWordBoundary` khoá rằng `EventHook` chỉ gọi
  // `syncFocusedContextForKeystroke()` khi `input.isAtWordBoundary`: ĐÚNG MỘT lần
  // chụp AX cho mỗi từ và nó rơi vào PHÍM ĐẦU, cộng ca click chuột (nhánh
  // `.leftMouseDown` gọi `newWord()` nên phím đầu ở ô mới vẫn được chụp lại).
  //
  // XOÁ VÌ CỔNG ĐÃ LÙI: `EventHook` chụp lại MỖI keyDown như HEAD, và
  // `isAtWordBoundary` đã gỡ khỏi production (sau khi lùi thì không còn người đọc
  // nào ngoài chính test này). Trớ trêu là con số mà test này khoá lại chính là
  // chỗ tiền đề sai lộ ra: "một lần chụp, ở PHÍM ĐẦU" nghe như tiết kiệm AX, thực
  // chất là chọn đúng phép đo tệ nhất — ngay sau click/⌘S, AX còn trả ô CŨ — rồi
  // buộc cả từ vào nó.
  //
  // HỆ QUẢ CÒN LẠI, ĐỪNG GỘP NHẦM: bỏ cổng làm `Focused.snapshot()` chạy lại MỖI
  // PHÍM trên tap thread, nên ngân sách riêng cho đường nóng (`hotPathAXTimeout`,
  // B1) càng cần chứ không phải bớt cần. `HotPathAXBudgetF4Tests` giữ chỗ đó —
  // đừng gộp hằng ấy về `defaultAXTimeout` cho gọn.

  // MARK: F1 — chốt NFD sau lần gửi có backspace (khác chốt-theo-từ đã lùi)

  /// Electron web content: sau lần gửi NFD đầu tiên có `bs > 0`, hiccup AX đổi
  /// `.webContent` → `.windowField` giữa từ KHÔNG được lật trục sang NFC.
  func testF1_NfdEmitPlanSurvivesMidWordFieldFlip() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(Self.electronApp)
    p.focusedFieldKind = .webContent

    let word = "tieengs"
    var lockedSeq: [T3EmitStep] = []
    for (i, c) in word.enumerated() {
      p.push(char: c)
      let r = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      if !r.isEmpty {
        p.recordConsequentialEmitForTests(r)
        lockedSeq.append(T3EmitStep(r.backspaceCount, r.diffChars))
      }
      if i == 4 { p.focusedFieldKind = .windowField }
    }

    let baseline = InputProcessor(method: .Telex)
    baseline.changeActiveApp(Self.electronApp)
    baseline.focusedFieldKind = .webContent
    var baseSeq: [T3EmitStep] = []
    for c in word {
      baseline.push(char: c)
      let r = baseline.emitPlan().replacement(
        from: baseline.lastTransformed, to: baseline.transformed)
      if !r.isEmpty {
        baseSeq.append(T3EmitStep(r.backspaceCount, r.diffChars))
      }
    }

    XCTAssertEqual(lockedSeq, baseSeq,
      "chốt NFD sau bs>0 phải giữ chuỗi phát ổn định dù fieldKind dao động")
    XCTAssertFalse(p.emitPlan().usesNFC, "vẫn trên nhánh NFD sau flip")
  }

  /// Hộp thoại Lưu (nativePanel/NFC): không kích hoạt chốt NFD — AX vẫn được đo
  /// lại mỗi phím để tự hội tụ NFC.
  func testF1_NativePanelNeverArmsNfdLockSoAxisCanSelfHeal() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(Self.electronApp)
    p.focusedFieldKind = .nativePanel

    for c in "nooij" {
      p.push(char: c)
      let r = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      if !r.isEmpty { p.recordConsequentialEmitForTests(r) }
    }
    XCTAssertTrue(p.emitPlan().usesNFC, "nativePanel ⇒ NFC")

    p.focusedFieldKind = .unknown
    XCTAssertFalse(p.emitPlan().usesNFC,
      "không có chốt NFD ⇒ hiccup về .unknown vẫn đo lại, không đóng băng NFC")
  }

  /// `.unknown` không đủ tin cậy để chốt — tránh đóng băng NFD khi hộp thoại Lưu
  /// vừa mở mà AX chưa kịp báo `.nativePanel`.
  func testF1_UnknownFieldKindNeverArmsNfdLock() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(Self.electronApp)
    p.focusedFieldKind = .unknown

    for c in "tuw" {
      p.push(char: c)
      let r = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      if !r.isEmpty { p.recordConsequentialEmitForTests(r) }
    }

    p.focusedFieldKind = .nativePanel
    XCTAssertTrue(p.emitPlan().usesNFC,
      ".unknown không chốt NFD ⇒ chuyển sang nativePanel vẫn đo lại NFC")
  }
}

// MARK: - ===========================================
// MARK: - [ĐÃ XOÁ] T3 — STICKY-ON-MISS ("đo hụt ≠ .unknown")
// MARK: - ===========================================
//
// LỚP `StickyOnMissT3Tests` (3 test) ĐÃ XOÁ CÙNG VÒNG LÙI CHỐT TRỤC THEO TỪ.
//
// NÓ TỪNG KHOÁ GÌ. Khi đó `Focused.fieldKind(from:)` trả `FieldKind?`: `nil` =
// KHÔNG ĐO ĐƯỢC (AX timeout / đứt chuỗi parent / chạm trần 25 cấp), khác hẳn
// `.unknown` = "đo được, và nó thuộc loại unknown". Khác biệt không phải chữ
// nghĩa: `.unknown` là một GIÁ TRỊ nằm bên phía NFD của trục và làm
// `focusedFieldIsBrowserChrome()` trả false, nên biến một lần đọc hụt thành
// `.unknown` là biến một hiccup AX thành một lần LẬT TRỤC + MẤT `.axDirect`.
//   • `testStickyA_MissIsRepresentedAsNoValueNotAsUnknown` — HỢP ĐỒNG của kiểu:
//     `FocusSnapshot.fieldKind` và `snapshot().fieldKind` phải là Optional.
//   • `testStickyB_MissKeepsTheOmniboxOnAxDirectAndKeepsTheAxis` — HỆ QUẢ, hai
//     dòng code thật đặt cạnh nhau: người đọc tuân hợp đồng (`if let`) giữ omnibox
//     trên `.axDirect` và không lật trục; người đọc viết `?? .unknown` mất cả hai.
//   • `testStickyC_WordLockSurvivesEvenIfTheStickyRuleWereRemoved` — ranh giới
//     trách nhiệm giữa hai cơ chế: sticky hạ XÁC SUẤT chốt sai, chốt theo từ đảm
//     bảo sai-thì-sai-NHẤT-QUÁN.
//
// XOÁ VÌ: `FieldKind?`, `AppState.adoptFocusSnapshot` và
// `InputProcessor.focusMovedSinceFieldKindMeasured` đều đã gỡ; đo hụt lại là
// `.unknown` như HEAD. Và vì chính test thứ ba ở trên nói ra ranh giới: sticky
// sinh ra để ĐỠ CHO CHỐT. Không còn chốt thì nó chỉ còn là "giữ lại phân loại của
// một ô có thể đã đóng" — tức thêm một trạng thái ÔI mới, đúng vào chỗ mà
// đo-mỗi-phím của HEAD đang tự hội tụ về đúng.
//
// ĐIỀU KIỆN THỬ LẠI: sticky đi SAU chốt, không đi trước. Phải đo được (i) tần suất
// `fieldKind(from:)` đo hụt THẬT trên máy dùng hằng ngày và (ii) trong số đó bao
// nhiêu lần ô focus đã đổi so với phép đo trước. Vế (ii) mới là thứ quyết định
// sticky lợi hay hại, và chưa ai đo. `Tools/probe`.
//
// CHIỀU MÀ HEAD VẪN GIỮ, đừng tưởng đã mất theo: `FocusedFieldStabilityV424Tests`
// (ngay phía trên) khoá việc đọc hụt AXRole vẫn phải LEO PARENT thay vì bỏ cuộc.
// Đó là hàng rào chống lật trục còn sống — và nó là hàng rào của HEAD, không phải
// của đợt này.

// MARK: - ===========================================
// MARK: - B1 — mã chết đã gỡ & quyền sở hữu axTargetPID
// MARK: - ===========================================
final class DeadCodeAndPIDOwnershipB1Tests: XCTestCase {

  /// B1.1 — chuỗi `isSearchOrComboFocused` đã biến mất TRỌN VẸN.
  ///
  /// Cái giá của việc giữ nó không phải là một biến thừa: `Focused.snapshot()`
  /// phải đọc thêm `kAXRole` RIÊNG trên focused element — một round-trip AX MỖI
  /// PHÍM, trên tap thread, cho một giá trị không ai đọc (người đọc duy nhất,
  /// `isFixAutocompleteApp()`, đã gỡ ở v4.23). Mà timeout/độ trễ AX điều khiển
  /// thẳng xác suất đọc hụt role ⇒ xác suất lật trục giữa từ. Một round-trip thừa
  /// mỗi phím KHÔNG trung tính.
  ///
  /// Hai vế được khoá bằng hai cách khác nhau vì hai thứ khác nhau:
  ///   • `FocusSnapshot.isComboOrSearch` — khoá lúc BIÊN DỊCH (init memberwise
  ///     hai tham số chỉ tồn tại khi struct có đúng hai trường);
  ///   • `InputProcessor.isSearchOrComboFocused` — khoá lúc CHẠY bằng Mirror,
  ///     vì "một stored property KHÔNG tồn tại" không diễn đạt được bằng kiểu.
  func testB1_1_DeadSearchOrComboChainIsFullyGone() throws {
    let snapshotFields = Mirror(reflecting: Focused.FocusSnapshot(bundleId: nil, fieldKind: .unknown))
      .children.compactMap(\.label)
    XCTAssertEqual(snapshotFields, ["bundleId", "fieldKind"],
      "FocusSnapshot chỉ còn hai trường — thêm trường nào cũng là thêm round-trip AX mỗi phím")

    let processorFields = Mirror(reflecting: InputProcessor(method: .Telex))
      .children.compactMap(\.label)
    // Lưới an toàn: Mirror phải THẤY được stored property, nếu không assert dưới
    // đây đúng một cách vô nghĩa.
    XCTAssertTrue(processorFields.contains("focusedFieldKind"),
      "đối chứng: Mirror có đọc được stored property của InputProcessor")
    XCTAssertFalse(processorFields.contains { $0.contains("SearchOrCombo") },
      "cờ chết đã gỡ — muốn dựng lại nhận diện ô search/combo thì đọc role TỪ "
        + "`fieldKind` (nó đã đọc role node trong cùng rồi), ĐỪNG thêm lần đọc thứ hai")
  }

  /// B1.2 — timeout AX có MỘT trạng thái ổn định, không phải "kẻ ghi sau thắng".
  ///
  /// Đặt timeout lên system-wide element là đặt MẶC ĐỊNH CHO CẢ TIẾN TRÌNH. Trước
  /// B1 có bốn chỗ cùng đặt, hai giá trị (0,05 và 0,1), từ hai thread, không chỗ
  /// nào khôi phục — nên timeout thực tế của MỌI truy vấn AX nhảy tuỳ đường nào
  /// chạy sau cùng. Nay trạng thái ổn định là `defaultAXTimeout`, còn chỗ cần
  /// ngắn hơn thì MƯỢN CÓ THỜI HẠN qua `withAXTimeout`.
  func testB1_2_AXTimeoutHasOneStableDefault() throws {
    XCTAssertEqual(Focused.defaultAXTimeout, 0.1, accuracy: 0.0001,
      "giá trị ổn định — `AppDelegate` cũng gọi setupAXTimeout(0.1)")
    XCTAssertGreaterThan(Focused.defaultAXTimeout, 0.05,
      "mặc định phải ≥ mọi giá trị mượn ngắn: xác suất đọc hụt kAXRole chỉ được GIẢM")

    // `withAXTimeout` là một scope, không phải một lần ghi: nó trả giá trị của
    // `body` ra ngoài và trả timeout về mặc định trong `defer`.
    XCTAssertEqual(Focused.withAXTimeout(0.05) { 42 }, 42)
    XCTAssertEqual(Focused.withAXTimeout(0.05) { "ok" }, "ok")
  }

  /// B1.3 — PID đích ĐI THEO LẦN GỬI, không được đọc lại từ global lúc flush.
  ///
  /// `axTargetPID` là hộp thư MỘT CHIỀU từ tap thread: đúng một người ghi
  /// (`EventHook.eventTapCallback`) và đúng một người đọc (`sendReplacement`,
  /// đọc ĐỒNG BỘ ngay lúc vào hàm, tức vẫn trong lần gọi tap callback đã ghi giá
  /// trị đó). Nhánh `.axDirect` flush TRỄ trên `simulationQueue`; nếu tầng dưới
  /// còn đọc lại global thì người dùng đổi app đúng giữa chừng sẽ khiến thao tác
  /// gửi của app A ghi AX vào ô đang focus của app B.
  ///
  /// Khoá bằng CHỮ KÝ: chỉ riêng việc gán dưới đây biên dịch được đã chứng minh
  /// PID đi bằng tham số. CỐ Ý KHÔNG GỌI hàm — `axDirectReplace` ghi thẳng vào ô
  /// đang focus của máy chạy test.
  func testB1_3_AxTargetPIDTravelsAsAParameter() throws {
    let signatureLock: [Any] = [
      EventSimulator.axDirectReplace(backspaceCount:insert:usesNFC:targetPID:)
        as (Int, String, Bool, pid_t) -> Bool
    ]
    XCTAssertEqual(signatureLock.count, 1,
      "axDirectReplace phải NHẬN targetPID; bỏ tham số này = quay lại đọc global lúc flush")

    // Biến global vẫn còn (tap thread cần chỗ để ghi) và vẫn là pid_t.
    let saved = EventSimulator.axTargetPID
    defer { EventSimulator.axTargetPID = saved }
    EventSimulator.axTargetPID = pid_t(4242)
    XCTAssertEqual(EventSimulator.axTargetPID, pid_t(4242))
  }
}

// MARK: - ===========================================
// MARK: - [ĐÃ XOÁ] F1/F2 — hai ca hỏng CỦA chốt trục theo từ
// MARK: - ===========================================
//
// HAI LỚP `EmitLockAtWordBoundaryF1Tests` (5 test) VÀ `StickyScopeF2Tests` (5
// test) ĐÃ XOÁ, cùng hai helper `f1EmitSequence` / `f2AdoptFocusSnapshot`.
//
// CHÚNG TỪNG KHOÁ GÌ. Hai lỗi mức CAO mà 419 test xanh không nhìn thấy, cùng một
// hình dạng: mọi test trước đó chỉ dựng ca "phân loại đang giữ là ĐÚNG, đừng để
// nhiễu ghi đè"; không test nào dựng ca ngược lại — "phân loại đang giữ đã ÔI,
// đừng dùng lại".
//
//   F1 — Backspace trên bộ đệm RỖNG (click sang ô mới rồi xoá nội dung cũ theo
//        thói quen) ĐÓNG chốt trục cho một từ CHƯA TỒN TẠI. Nhánh `.Delete` viết
//        `pop(plan: emitPlan())`, mà `emitPlan()` ở vị trí THAM SỐ nên được đánh
//        giá VÔ ĐIỀU KIỆN; `pop` trả `(0, [])` và không đi qua `newWord()`, nên
//        không có gì mở khoá. 5 test: ca tối thiểu (đo nhưng không chốt); ca đầy
//        đủ click→Backspace→gõ, với lịch probe mô phỏng đúng ghi chú v3.6 (lần
//        đọc AX đầu tiên sau click còn thấy focus CŨ); "che ≠ xoá" (getter che
//        giá trị vs `newWord()` xoá `storedEmitPlan` thật); bất biến
//        `isAtWordBoundary ⇒ lockedEmitPlan == nil` áp trên một kịch bản dài; và
//        ca biên Backspace khôi phục từ vừa commit qua Space.
//   F2 — Sticky-on-miss KHÔNG CÓ PHẠM VI. `focusedFieldKind` là biến toàn tiến
//        trình, nên giữ lại phân loại của một ô đã đóng (hộp thoại Lưu native,
//        `.nativePanel` ⇒ trục NFC) rồi áp cho ô kế tiếp (ô chat Electron ⇒ trục
//        NFD) là lật trục ⇒ lệch backspace ⇒ ăn mất chữ. 5 test: ca hộp thoại Lưu;
//        biến thể tệ hơn (`.windowField` ôi còn tuồn `.axDirect` vào editor
//        Electron); "chưa đo lần nào thì không có gì để sticky"; chiều không hồi
//        quy (không có sự kiện đổi focus ⇒ sticky vẫn phải giữ); và vòng đời MỘT
//        CHIỀU của cờ `focusMovedSinceFieldKindMeasured` (sự kiện BẬT, chỉ phép đo
//        thành công mới TẮT).
//
// XOÁ VÌ CẢ HAI CƠ CHẾ ĐÃ LÙI — không phải vì hai lỗi trên không có thật. Chúng có
// thật; nhưng chúng là lỗi CỦA CHỐT. Không còn chốt thì không có gì để đóng băng ở
// F1, và không có gì để bảo vệ ở F2.
//
// ⚠️ CHỖ NGƯỜI SAU DỄ HIỂU NGƯỢC. Ca ⌘S của F2 đọc như một lý do để GIỮ sticky có
// phạm vi. Nó là lý do để lùi CẢ CỤM: ở đúng ca đó, đo-mỗi-phím của HEAD TỰ HỘI TỤ
// VỀ ĐÚNG — phép đo ôi `.nativePanel` (NFC) bị thay bằng phép đo tươi ngay phím kế
// tiếp, mà chiều lật NFD→NFC lại là chiều LÀNH (ở dạng NFC 1 grapheme đúng bằng 1
// scalar; xem khối T4). Chốt thì đóng băng cái sai cho trọn từ. Nói gọn: cơ chế
// thứ nhất đẻ ra lỗi, rồi cần cơ chế thứ hai để đỡ chính lỗi đó.
//
// ĐIỀU KIỆN THỬ LẠI, y như phần trên: `Tools/probe` phải trả lời TRƯỚC (i) trục có
// THẬT SỰ lật giữa một từ không và bao lâu một lần; (ii) sau click/⌘S bao lâu thì
// AX báo đúng ô. Nếu (ii) nhỏ hơn khoảng cách tới phím SINH DẤU đầu tiên (thường
// phím 3–5, 200–500ms) thì chốt không giải quyết vấn đề gì cả.
//
// KỸ THUẬT ĐÁNG GIỮ LẠI, nếu có vòng sau: mỗi bài kiểm mang một LƯỚI CHỐNG TEST
// RỖNG tường minh — assert rằng hai phân loại đem so THẬT SỰ cho hai chuỗi
// (bs, diff) khác nhau, và độ lệch nằm ở SỐ BACKSPACE (chỗ ăn mất chữ), chứ không
// phải ở chỗ hiển thị. Thiếu lưới đó, một test "ổn định" xanh được bằng cách chốt
// cứng SAI. `HeadParityGoldenTests` phía dưới thừa kế đúng kỹ thuật này.

// MARK: - ===========================================
// MARK: - EmitPlan — BẤT BIẾN v4.15 GIỜ DO KIỂU GIỮ
// MARK: - ===========================================
//
// ĐÂY LÀ GIÁ TRỊ CÒN LẠI CỦA CẢ ĐỢT, sau khi chốt trục theo từ, cổng chụp AX theo
// ranh giới từ và sticky-on-miss đều đã lùi.
//
//   Bất biến v4.15: dạng dùng để ĐẾM backspace phải ĐÚNG BẰNG dạng PHÁT ra.
//   Vi phạm = số backspace lệch scalar = ăn ngược vào chữ đã gõ. Đó chính là
//   v4.14 ("gửi" → "ửi"), hồi quy nặng nhất lịch sử repo.
//
// Trước đây bất biến ấy chỉ là QUY ƯỚC: mỗi call site tự gọi
// `usesNFCForFocusedField()`, tự NHỚ truyền đúng cái `Bool` đó xuống transport, và
// người review phải tự kiểm 13 chỗ. Giờ số đếm và trục đi chung MỘT giá trị:
// `EmitPlan.Replacement.init` là `fileprivate` nên chỉ factory của `EmitPlan` dựng
// được, mọi đường dựng đều đếm bằng CHÍNH trục của plan đó, và transport nhận
// `normalizeToNFC: replacement.plan.usesNFC` chứ không phải một tham số rời.
//
// ⚠️ `EmitPlan` KHÔNG NHỚ GÌ. `emitPlan()` đo lại mỗi lần gọi, hệt HEAD — đó là
// điều `HeadParityGoldenTests` ngay dưới chứng minh bằng số. Đừng đọc lớp này như
// di tích của chốt: chốt đã gỡ, cái này thì không.
//
// Lớp dưới khoá cả hai vế. Vế CHẠY ĐƯỢC: mọi đường dựng đếm đúng trục của mình, và
// dạng đi ra dây có đúng số scalar như lúc đếm. Vế KHÔNG DIỄN ĐẠT ĐƯỢC BẰNG ASSERT
// ("không còn đường nào khác để một trục lạ tới được transport") phải kiểm ở mức
// NGUỒN — một `Replacement` dựng lậu làm test KHÔNG BIÊN DỊCH chứ không đỏ, nên
// không có cách nào viết nó thành `XCTAssert`.
final class EmitPlanTypeConstraintTests: XCTestCase {

  /// Electron ngoài whitelist NFC (lớp Zalo/Messenger/Slack/Discord) — app DUY
  /// NHẤT mà `fieldKind` thật sự quyết định trục, nên là chỗ duy nhất dựng được
  /// hai trục cạnh nhau để so.
  private static let electronApp = "com.tinyspeck.slackmacgap"
  private static let browserApp = "com.google.Chrome"

  private var savedZWJF = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.allowedZWJF] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  /// Dựng một bước phát THẬT có mang dấu: gõ "tieeng" rồi phím `s`, tức
  /// `lastTransformed == "tiêng"` → `transformed == "tiếng"`, diff = "ếng".
  /// Bước này được chọn vì nó là bước DUY NHẤT trong từ mà hai trục cho hai số
  /// backspace khác nhau — mọi assert dưới đây vô nghĩa nếu chọn bước khác.
  private func processorAtToneStep(app: String, kind: Focused.FieldKind) -> InputProcessor {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(app)
    p.focusedFieldKind = kind
    for c in "tieengs" { p.push(char: c) }
    return p
  }

  /// (1) MỌI đường dựng `Replacement` đều đếm bằng CHÍNH trục của plan sinh ra nó,
  /// và trục ấy ĐI THEO giá trị chứ không nằm rời ở đâu đó.
  ///
  /// Ba đường dựng, đủ bộ: `replacement(from:to:)` (đường chính),
  /// `insertion(of:)` (dự đoán từ / lưới an toàn auto-capitalize), và
  /// `pop(plan:)` (cầu nối duy nhất cho số đếm tính ở nơi khác — `WordBuffer.pop`
  /// phải replay state trước khi đếm nên không đếm hộ từ `EmitPlan` được).
  func testEveryConstructionPathCountsOnItsOwnPlansAxis() throws {
    for (app, kind) in [(Self.electronApp, Focused.FieldKind.webContent),
                        (Self.browserApp, Focused.FieldKind.webContent),
                        (Self.electronApp, Focused.FieldKind.windowField)] {
      let p = processorAtToneStep(app: app, kind: kind)
      let plan = p.emitPlan()

      // LƯỚI CHỐNG TEST RỖNG, đặt TRƯỚC mọi assert khác: bước này phải phân biệt
      // được hai trục, nếu không thì "đếm đúng trục" đúng một cách vô nghĩa.
      let onPlanAxis = EventSimulator.calcKeyStrokes(
        from: p.lastTransformed, to: p.transformed, usesNFC: plan.usesNFC)
      let onOtherAxis = EventSimulator.calcKeyStrokes(
        from: p.lastTransformed, to: p.transformed, usesNFC: !plan.usesNFC)
      XCTAssertNotEqual(
        T3EmitStep(onPlanAxis.0, onPlanAxis.1), T3EmitStep(onOtherAxis.0, onOtherAxis.1),
        "\(app) × \(kind): bước 'tiêng'→'tiếng' PHẢI cho hai số khác nhau ở hai trục")

      // (a) đường chính
      let r = plan.replacement(from: p.lastTransformed, to: p.transformed)
      XCTAssertEqual(r.plan.usesNFC, plan.usesNFC,
        "trục ĐI THEO giá trị `Replacement`, không phải một Bool rời bên cạnh")
      XCTAssertEqual(r.plan.fieldIsBrowserChrome, plan.fieldIsBrowserChrome,
        "đường gửi cũng đi cùng — tách hai vế là mở lại cửa cho 'trường'→'truường'")
      XCTAssertEqual(T3EmitStep(r.backspaceCount, r.diffChars),
                     T3EmitStep(onPlanAxis.0, onPlanAxis.1),
        "\(app) × \(kind): số đếm phải là số của trục TRONG plan")

      // (b) chèn thuần — không có backspace nào để lệch, nhưng trục vẫn phải
      //     đi theo vì transport dùng nó để chọn dạng emit.
      let ins = plan.insertion(of: Array("ếng"))
      XCTAssertEqual(ins.backspaceCount, 0, "insertion không xoá gì")
      XCTAssertEqual(ins.plan.usesNFC, plan.usesNFC)
      XCTAssertEqual(ins.plan.fieldIsBrowserChrome, plan.fieldIsBrowserChrome)

      // (c) `pop(plan:)` — trục dùng để replay/đếm BÊN TRONG `WordBuffer.pop`
      //     đúng bằng trục sẽ phát ra.
      let popped = p.pop(plan: plan)
      XCTAssertEqual(popped.plan.usesNFC, plan.usesNFC)
      let raw = processorAtToneStep(app: app, kind: kind).pop(usesNFC: plan.usesNFC)
      XCTAssertEqual(T3EmitStep(popped.backspaceCount, popped.diffChars),
                     T3EmitStep(raw.0, raw.1),
        "\(app) × \(kind): pop(plan:) phải ra đúng cái pop(usesNFC: plan.usesNFC) ra")
    }
  }

  /// (2) DẠNG ĐI RA DÂY == DẠNG ĐÃ ĐẾM. Bất biến v4.15 viết thành số scalar.
  ///
  /// `EventSimulator.sendReplacement` KHÔNG phát thẳng `diffChars`: nó chạy qua
  /// `emittedCharacters(_:normalizeToNFC:)` trước. Nếu `normalizeToNFC` khác trục
  /// đã đếm, số scalar THỰC PHÁT khác số scalar đã đếm backspace — đó đúng là hình
  /// dạng của v4.14. Test đo cả chiều đúng lẫn chiều sai.
  func testWireFormHasTheSameScalarCountAsTheCountedForm() throws {
    for (app, kind) in [(Self.electronApp, Focused.FieldKind.webContent),
                        (Self.browserApp, Focused.FieldKind.webContent)] {
      let p = processorAtToneStep(app: app, kind: kind)
      let counted = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      let countedScalars = String(counted.diffChars).unicodeScalars.count

      // CHIỀU ĐÚNG — đúng tham số mà `sendTypedReplacement` truyền xuống.
      let wire = EventSimulator.emittedCharacters(
        counted.diffChars, normalizeToNFC: counted.plan.usesNFC)
      XCTAssertEqual(String(wire).unicodeScalars.count, countedScalars,
        "\(app) × \(kind): transport KHÔNG được đổi số scalar so với lúc đếm")

      // CHIỀU SAI — cùng `diffChars`, trục ngược. Chỉ nhánh NFD quan sát được:
      // precompose bóp cụm NFD lại, phát ÍT scalar hơn số backspace đã đếm.
      // (Nhánh NFC vô hại theo đúng phép đo T4 — ở dạng NFC 1 grapheme đã bằng 1
      // scalar nên `normalizeToNFC: false` không đổi gì. Đó là lý do trục sai
      // KHÔNG ĐỐI XỨNG, và cũng là một trong ba lý do lùi chốt theo từ.)
      let wrongWire = EventSimulator.emittedCharacters(
        counted.diffChars, normalizeToNFC: !counted.plan.usesNFC)
      if counted.plan.usesNFC {
        XCTAssertEqual(String(wrongWire).unicodeScalars.count, countedScalars,
          "\(app): trục NFC — 1 grapheme == 1 scalar nên chiều ngược vô hại (T4)")
      } else {
        XCTAssertLessThan(String(wrongWire).unicodeScalars.count, countedScalars,
          "\(app): trục NFD + normalizeToNFC=true ⇒ phát ít scalar hơn số đã đếm "
            + "backspace = ăn mất ký tự trước nguyên âm mang dấu. ĐÂY là v4.14.")
      }
    }
  }

  /// (3) KHÔNG CÒN ĐƯỜNG NÀO KHÁC để một trục lạ tới được transport.
  ///
  /// Vế này không viết thành assert chạy được: dựng lậu một `Replacement` làm test
  /// KHÔNG BIÊN DỊCH chứ không đỏ. Nên kiểm ở mức NGUỒN, mức TOKEN, và tự bỏ qua
  /// nếu không đọc được file (test có thể chạy trên máy khác nơi biên dịch).
  ///
  /// Bốn thứ được khoá, mỗi thứ là một cách khác nhau để bất biến v4.15 tuột:
  ///   (a) `init` của `Replacement` còn `fileprivate`;
  ///   (b) mọi chỗ dựng `Replacement(plan:` nằm TRONG `struct EmitPlan`;
  ///   (c) cả cây `vkey/` có ĐÚNG MỘT chỗ gọi `EventSimulator.sendReplacement(`;
  ///   (d) và chỗ đó truyền `normalizeToNFC: replacement.plan.usesNFC`.
  func testTheAxisCannotReachTransportByAnyOtherRoute() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()   // vkeyTests/
      .deletingLastPathComponent()   // <repo>
    let ipPath = repoRoot.appendingPathComponent("vkey/App/InputProcessor.swift")
    guard let src = try? String(contentsOf: ipPath, encoding: .utf8) else {
      throw XCTSkip("không đọc được \(ipPath.path) — lưới bổ sung, bỏ qua")
    }
    let lines = src.components(separatedBy: "\n")
    func isCode(_ l: String) -> Bool {
      let t = l.trimmingCharacters(in: .whitespaces)
      return !t.hasPrefix("//") && !t.hasPrefix("///") && !t.hasPrefix("*")
    }

    // (a)
    XCTAssertTrue(
      lines.contains { isCode($0) && $0.contains("fileprivate init(plan: EmitPlan") },
      "`EmitPlan.Replacement.init` phải còn `fileprivate`. Nới nó ra là trả bất biến "
        + "v4.15 về làm quy ước review — đúng trạng thái đã đẻ ra v4.14 (\"gửi\"→\"ửi\").")

    // (b) — thân `struct EmitPlan` = từ dòng khai báo tới `// MARK:` kế tiếp.
    guard let planDecl = lines.firstIndex(where: { isCode($0) && $0.hasPrefix("struct EmitPlan") })
    else {
      return XCTFail("`struct EmitPlan` đã biến mất khỏi InputProcessor.swift")
    }
    let planEnd = lines[(planDecl + 1)...].firstIndex { $0.hasPrefix("// MARK:") } ?? lines.endIndex
    let planRange = planDecl..<planEnd
    for i in lines.indices where isCode(lines[i]) && lines[i].contains("Replacement(plan:") {
      XCTAssertTrue(planRange.contains(i),
        "InputProcessor.swift:\(i + 1) dựng `Replacement` NGOÀI `EmitPlan`. Mọi đường "
          + "dựng phải đếm bằng chính trục của plan; một đường ngoài là một đường "
          + "truyền lệch trục xuống transport.")
    }

    // (c) — quét CẢ cây nguồn, không chỉ file này.
    let appRoot = repoRoot.appendingPathComponent("vkey")
    var callSites: [String] = []
    if let walker = FileManager.default.enumerator(atPath: appRoot.path) {
      for case let rel as String in walker where rel.hasSuffix(".swift") {
        // Bản thân transport khai báo hàm; chỉ đếm NGƯỜI GỌI.
        if rel.hasSuffix("EventSimulator.swift") { continue }
        let p = appRoot.appendingPathComponent(rel)
        guard let text = try? String(contentsOf: p, encoding: .utf8) else { continue }
        for (n, l) in text.components(separatedBy: "\n").enumerated()
        where isCode(l) && l.contains("EventSimulator.sendReplacement(") {
          callSites.append("\(rel):\(n + 1)")
        }
      }
    }
    XCTAssertEqual(callSites.count, 1,
      "transport chỉ được có MỘT người gọi (`sendTypedReplacement`). Thêm người gọi "
        + "thứ hai là thêm một chỗ tự chọn `normalizeToNFC`. Thấy: \(callSites)")
    XCTAssertTrue(callSites.first?.contains("InputProcessor.swift") ?? false,
      "…và người gọi đó phải là `InputProcessor.sendTypedReplacement`. Thấy: \(callSites)")

    // (d) — và người gọi đó lấy trục TỪ CHÍNH `replacement`.
    let nfcArgs = lines.filter { isCode($0) && $0.contains("normalizeToNFC:") }
      .map { $0.trimmingCharacters(in: .whitespaces) }
    XCTAssertEqual(nfcArgs, ["normalizeToNFC: replacement.plan.usesNFC"],
      "trục xuống transport phải đọc từ chính `Replacement` đã đếm ra số backspace. "
        + "Một `Bool` rời ở đây là hình dạng chính xác của hồi quy v4.14.")
  }
}

// MARK: - ===========================================
// MARK: - ĐỐI CHIẾU HEAD — chuỗi (bs, diff) VIẾT CỨNG
// MARK: - ===========================================
//
// ⚠️ SỐ TRONG BẢNG DƯỚI KHÔNG LẤY TỪ HÀNH VI HIỆN TẠI. Chúng được ĐO trên chính
// HEAD (commit 5e22d85 — trước B1/B2, tức trước `EmitPlan`), theo đúng cách này:
//
//   git archive HEAD | tar -x -C <tmp>/head          # bản HEAD sạch, NGOÀI repo
//   # thêm vào <tmp>/head/vkeyTests một test chỉ để in số, rồi:
//   xcodebuild -project vkey.xcodeproj -scheme vkey -destination 'platform=macOS' \
//     -derivedDataPath <tmp>/dd-head -only-testing:vkeyTests/<probe> test
//
// Đường đo trên HEAD chép nguyên văn `handleTextChar` của HEAD:
//   push(char:) → EventSimulator.calcKeyStrokes(from: lastTransformed,
//                   to: transformed, usesNFC: usesNFCForFocusedField())
// Backspace: `pop(usesNFC: usesNFCForFocusedField())`. Macro: `macroTarget(...)`
// rồi `calcKeyStrokes(from: current, to: target, usesNFC:)` — đúng số học của
// `expandMacroIfMatch`. (Chính hàm đó KHÔNG gọi được trong test: nó phát event
// thật vào ô đang focus của máy chạy test.)
//
// VÌ SAO CẦN BẢNG NÀY BÊN CẠNH `testT3_StableFieldEmitsExactlyThePreT3Sequence`.
// Test kia so HAI ĐƯỜNG TRONG CÙNG MỘT CÂY NGUỒN, mà cả hai vế đều gọi chính
// `EventSimulator.calcKeyStrokes` — nên một thay đổi trong THUẬT TOÁN DIFF đẩy cả
// hai vế lệch CÙNG CHIỀU và test kia vẫn xanh.
//
// Đã kiểm bằng ĐỘT BIẾN chứ không suy luận (chạy trên bản sao ngoài repo): tắt
// vòng lùi-prefix v3.6 trong `calcKeyStrokesNFD` (đổi điều kiện thành
// `if false && …`) thì CẢ BA test của `EmitPlanWordLockT3Tests` vẫn XANH, còn
// `testTypingSequencesMatchHeadExactly` dưới đây ĐỎ 8 chỗ. Đó chính xác là khoảng
// trống mà bảng vàng lấp: một mỏ neo NGOÀI cây nguồn.
//
// Chiều còn lại thì hai bên trùng nhau — đột biến bảng app × field → trục (cho
// `.webContent` trả `true` vô điều kiện) làm CẢ HAI cùng đỏ. Bảng vàng chỉ hơn ở
// thông điệp: nó nói thẳng app nào, ô nào, từ nào, và in ra cả hai chuỗi số.
//
// NÓ CŨNG LÀ BẰNG CHỨNG NGHIỆM THU CỦA VÒNG LÙI: sau khi gỡ chốt trục theo từ,
// cổng chụp AX và sticky-on-miss, hành vi phát ra phải trùng HEAD tới từng scalar.
//
// ⚠️ CÁCH ĐỌC MỘT DÒNG VÀNG. `scalars` có mặt vì Swift so sánh `String` theo TƯƠNG
// ĐƯƠNG CHUẨN TẮC: "ếng" dạng NFC `==` "ếng" dạng NFD, mà chính hai dạng đó mới là
// thứ đi ra dây. Chuỗi trong bảng viết ở dạng NFC cho dễ đọc; cột `scalars` là chỗ
// duy nhất phân biệt hai trục.
private struct GoldenSeq {
  let word: String
  let result: String
  /// (backspaceCount, diff dạng NFC để đọc, SỐ SCALAR thật sự phát ra)
  let steps: [(Int, String, Int)]
}

final class HeadParityGoldenTests: XCTestCase {

  private static let electronApp = "com.tinyspeck.slackmacgap"
  private static let browserApp = "com.google.Chrome"
  private static let appleApp = "com.apple.Notes"

  private var savedZWJF = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.allowedZWJF] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  // MARK: Bảng vàng, đo trên HEAD

  /// Trục NFD — đếm theo SCALAR. Ô Blink/Electron ngoài whitelist NFC: đúng lớp ô
  /// soạn tin Zalo / Messenger / Slack / Discord.
  private static let nfdGolden: [GoldenSeq] = [
    GoldenSeq(word: "tieengs", result: "tiếng", steps: [
      (0, "t", 1), (0, "i", 1), (0, "e", 1), (1, "ê", 2), (0, "n", 1), (0, "g", 1),
      (4, "ếng", 5),
    ]),
    GoldenSeq(word: "ddieeuf", result: "điều", steps: [
      (0, "d", 1), (1, "đ", 1), (0, "i", 1), (0, "e", 1), (1, "ê", 2), (0, "u", 1),
      (3, "ều", 4),
    ]),
    GoldenSeq(word: "nguoiwf", result: "người", steps: [
      (0, "n", 1), (0, "g", 1), (0, "u", 1), (0, "o", 1), (0, "i", 1),
      (3, "ươi", 5), (3, "ời", 4),
    ]),
    // `Nooij` là ca mà lời bàn về trục hay viện tới: chốt nhầm NFD trong một ô
    // AppKit làm nó ra `Ṇ̂i`. Độ lệch cụ thể nằm ở bước cuối — 3 backspace ở đây
    // so với 2 ở bảng NFC ngay dưới.
    GoldenSeq(word: "Nooij", result: "Nội", steps: [
      (0, "N", 1), (0, "o", 1), (1, "ô", 2), (0, "i", 1), (3, "ội", 4),
    ]),
  ]

  /// Trục NFC — đếm theo GRAPHEME. App Apple/whitelist, web content trình duyệt
  /// thật (từ v4.21), và ô cửa sổ (omnibox) của app nhóm NFD.
  private static let nfcGolden: [GoldenSeq] = [
    GoldenSeq(word: "tieengs", result: "tiếng", steps: [
      (0, "t", 1), (0, "i", 1), (0, "e", 1), (1, "ê", 1), (0, "n", 1), (0, "g", 1),
      (3, "ếng", 3),
    ]),
    GoldenSeq(word: "ddieeuf", result: "điều", steps: [
      (0, "d", 1), (1, "đ", 1), (0, "i", 1), (0, "e", 1), (1, "ê", 1), (0, "u", 1),
      (2, "ều", 2),
    ]),
    GoldenSeq(word: "nguoiwf", result: "người", steps: [
      (0, "n", 1), (0, "g", 1), (0, "u", 1), (0, "o", 1), (0, "i", 1),
      (3, "ươi", 3), (2, "ời", 2),
    ]),
    GoldenSeq(word: "Nooij", result: "Nội", steps: [
      (0, "N", 1), (0, "o", 1), (1, "ô", 1), (0, "i", 1), (2, "ội", 2),
    ]),
  ]

  /// Backspace: gõ trọn từ rồi bấm Delete 9 lần (nhiều hơn số phím đã gõ — để ca
  /// "xoá quá tay trên bộ đệm đã cạn" cũng nằm trong bảng).
  private static let nfdPopGolden: [(String, [(Int, String, Int)])] = [
    ("ddieeuf", [(2, "u", 1), (0, "", 0), (0, "", 0), (0, "", 0), (0, "", 0),
                 (1, "d", 1), (0, "", 0), (0, "", 0), (0, "", 0)]),
    ("tieengs", [(3, "ng", 2), (0, "", 0), (0, "", 0), (0, "", 0), (0, "", 0),
                 (0, "", 0), (0, "", 0), (0, "", 0), (0, "", 0)]),
  ]

  private static let nfcPopGolden: [(String, [(Int, String, Int)])] = [
    ("ddieeuf", [(2, "êu", 2), (0, "", 0), (1, "e", 1), (0, "", 0), (0, "", 0),
                 (1, "d", 1), (0, "", 0), (0, "", 0), (0, "", 0)]),
    ("tieengs", [(3, "êng", 3), (0, "", 0), (0, "", 0), (1, "e", 1), (0, "", 0),
                 (0, "", 0), (0, "", 0), (0, "", 0), (0, "", 0)]),
  ]

  // MARK: Tiện ích

  private func expected(_ g: (Int, String, Int)) -> T3EmitStep {
    T3EmitStep(golden: g.0, g.1, scalars: g.2)
  }

  /// Đường gõ THẬT của cây hiện tại: `push` → `emitPlan().replacement(from:to:)`.
  /// Đây đúng là dòng ở `handleTextChar`; đổi nó thì test này hết là đối chiếu.
  private func typeSequence(app: String, kind: Focused.FieldKind, word: String)
    -> (steps: [T3EmitStep], result: String)
  {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(app)
    p.focusedFieldKind = kind
    var out: [T3EmitStep] = []
    for c in word {
      p.push(char: c)
      let r = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      out.append(T3EmitStep(r.backspaceCount, r.diffChars))
    }
    return (out, p.transformed)
  }

  // MARK: Các bài đối chiếu

  /// (1) GÕ — gồm cả bỏ dấu cuối từ ("tieengs", "ddieeuf") lẫn thay CẢ CỤM
  /// ("nguoiwf": `w` viết lại "uo"→"ươ" giữa từ, rồi `f` viết lại "ươi"→"ời").
  ///
  /// Bảng ô ở đây cố ý phủ CẢ BỐN nhánh của việc gán trục, vì đó là thứ dễ bị
  /// "sửa" nhất: whitelist NFC (short-circuit TRƯỚC fieldKind), trình duyệt thật,
  /// Electron ngoài whitelist, và ô cửa sổ của app nhóm NFD.
  func testTypingSequencesMatchHeadExactly() throws {
    let cases: [(String, Focused.FieldKind, [GoldenSeq], Bool, Bool)] = [
      (Self.electronApp, .webContent, Self.nfdGolden, false, false),
      (Self.electronApp, .unknown, Self.nfdGolden, false, false),
      (Self.electronApp, .windowField, Self.nfcGolden, true, true),   // omnibox-like
      (Self.browserApp, .webContent, Self.nfcGolden, true, false),
      (Self.appleApp, .unknown, Self.nfcGolden, true, false),         // whitelist NFC
    ]

    for (app, kind, golden, expectNFC, expectChrome) in cases {
      // Bảng ánh xạ app × field → trục: khoá TRƯỚC, vì mọi con số dưới đây chỉ có
      // nghĩa khi ô này thật sự đang ở trục ta nghĩ.
      let probe = InputProcessor(method: .Telex)
      probe.changeActiveApp(app)
      probe.focusedFieldKind = kind
      XCTAssertEqual(probe.usesNFCForFocusedField(), expectNFC, "\(app) × \(kind): trục")
      XCTAssertEqual(probe.focusedFieldIsBrowserChrome(), expectChrome,
        "\(app) × \(kind): axDirect?")

      for g in golden {
        let got = typeSequence(app: app, kind: kind, word: g.word)
        XCTAssertEqual(got.result, g.result, "\(app) × \(kind) × \(g.word): engine")
        XCTAssertEqual(got.steps, g.steps.map(expected),
          "\(app) × \(kind) × \"\(g.word)\": chuỗi (bs, diff) LỆCH so với HEAD")
      }
    }
  }

  /// (2) BACKSPACE — đường duy nhất mà số đếm được tính ở nơi khác
  /// (`WordBuffer.pop` phải replay state trước khi đếm).
  func testBackspaceSequencesMatchHeadExactly() throws {
    let cases: [(String, Focused.FieldKind, [(String, [(Int, String, Int)])])] = [
      (Self.electronApp, .webContent, Self.nfdPopGolden),
      (Self.browserApp, .webContent, Self.nfcPopGolden),
      (Self.appleApp, .unknown, Self.nfcPopGolden),
    ]

    for (app, kind, golden) in cases {
      for (word, steps) in golden {
        let p = InputProcessor(method: .Telex)
        p.changeActiveApp(app)
        p.focusedFieldKind = kind
        for c in word { p.push(char: c) }

        var got: [T3EmitStep] = []
        for _ in 0..<steps.count {
          let r = p.pop(plan: p.emitPlan())   // = đúng dòng của nhánh `.Delete`
          got.append(T3EmitStep(r.backspaceCount, r.diffChars))
        }
        XCTAssertEqual(got, steps.map(expected),
          "\(app) × \(kind) × \"\(word)\": chuỗi Backspace LỆCH so với HEAD")
      }
    }
  }

  /// (3) MACRO — bung cả cụm một lần, và là đường phát có `diffChars` DÀI NHẤT
  /// trong vkey, nên cũng là chỗ độ lệch trục nhìn rõ nhất: "Việt Nam " đi ra dây
  /// là 11 scalar ở trục NFD nhưng 9 ở trục NFC.
  ///
  /// Bảng macro lấy `DefaultMacros.allDefaults` — bản seed sẵn cho mọi máy mới —
  /// chứ không phải `Defaults[.macros]`, vì tiến trình test không có bảng của
  /// người dùng. Số học thì y hệt `expandMacroIfMatch`.
  func testMacroExpansionMatchesHeadExactly() throws {
    let golden: [(String, Focused.FieldKind, [(String, String, Int, String, Int)])] = [
      (Self.electronApp, .webContent, [
        ("vn", "Việt Nam ", 2, "Việt Nam ", 11),
        ("hn", "Hà Nội ", 2, "Hà Nội ", 10),
      ]),
      (Self.browserApp, .webContent, [
        ("vn", "Việt Nam ", 2, "Việt Nam ", 9),
        ("hn", "Hà Nội ", 2, "Hà Nội ", 7),
      ]),
      (Self.appleApp, .unknown, [
        ("vn", "Việt Nam ", 2, "Việt Nam ", 9),
        ("hn", "Hà Nội ", 2, "Hà Nội ", 7),
      ]),
    ]

    for (app, kind, rows) in golden {
      for (trigger, target, bs, diffText, diffScalars) in rows {
        let p = InputProcessor(method: .Telex)
        p.changeActiveApp(app)
        p.focusedFieldKind = kind
        for c in trigger { p.push(char: c) }

        let current = p.transformed
        let got = try XCTUnwrap(
          InputProcessor.macroTarget(
            for: current, endingChar: " ", macros: DefaultMacros.allDefaults),
          "\(trigger): macro seed sẵn phải khớp — nếu không, ba assert dưới vô nghĩa")
        XCTAssertEqual(got, target, "\(trigger): phần bung")

        // Đúng dòng của `expandMacroIfMatch` trong cây hiện tại.
        let r = p.emitPlan().replacement(from: current, to: got)
        XCTAssertEqual(T3EmitStep(r.backspaceCount, r.diffChars),
                       T3EmitStep(golden: bs, diffText, scalars: diffScalars),
          "\(app) × \(kind) × macro \"\(trigger)\": LỆCH so với HEAD")
      }
    }
  }

  /// (4) LƯỚI CHỐNG BẢNG VÀNG RỖNG.
  ///
  /// Nếu hai bảng NFC/NFD trùng nhau thì ba bài trên xanh mà chẳng khoá được gì —
  /// đúng cái bẫy đã làm 419 test xanh trong khi hai lỗi mức CAO đi qua. Bài này
  /// assert rằng chúng KHÁC, và khác ở SỐ BACKSPACE (chỗ ăn mất chữ), chứ không
  /// phải chỉ ở số scalar (chỗ hiển thị).
  ///
  /// Đồng thời ghi lại phép đo T4 dưới dạng bất đẳng thức: `Nooij` cần 2 backspace
  /// ở ô AppKit (xoá GRAPHEME) và 3 ở ô Blink (xoá SCALAR). Chốt nhầm trục NFD
  /// trong ô AppKit ⇒ gửi thừa 1 backspace ⇒ ăn ngược vào chữ đã gõ (`Ṇ̂i`); chốt
  /// nhầm trục NFC trong ô Blink thì KHÔNG có độ lệch nào — trục sai không đối
  /// xứng, và đó là một trong ba lý do lùi chốt theo từ.
  func testTheTwoGoldenTablesActuallyDiffer() throws {
    XCTAssertEqual(Self.nfdGolden.count, Self.nfcGolden.count)
    for (nfd, nfc) in zip(Self.nfdGolden, Self.nfcGolden) {
      XCTAssertEqual(nfd.word, nfc.word)
      XCTAssertEqual(nfd.result, nfc.result, "hai trục phải cho CÙNG kết quả trên màn hình")
      XCTAssertNotNil(zip(nfd.steps, nfc.steps).first { $0.0.0 != $0.1.0 },
        "\"\(nfd.word)\": hai bảng phải khác nhau ở SỐ BACKSPACE, nếu không bảng vàng "
          + "này không phân biệt được trục nào cả")
    }

    // T4 viết thành số: đơn vị xoá của hai engine, đo bằng `Tools/probe`.
    let nfdNooij = try XCTUnwrap(Self.nfdGolden.first { $0.word == "Nooij" })
    let nfcNooij = try XCTUnwrap(Self.nfcGolden.first { $0.word == "Nooij" })
    XCTAssertEqual(nfcNooij.steps.last?.0, 2,
      "ô AppKit xoá GRAPHEME ⇒ 1 phím ăn trọn cụm ⇒ đếm grapheme = 2")
    XCTAssertEqual(nfdNooij.steps.last?.0, 3,
      "ô Blink xoá SCALAR ⇒ mỗi phím bóc 1 scalar ⇒ đếm scalar = 3")
  }
}

// MARK: - ===========================================
// MARK: - F4 — HAI NGÂN SÁCH AX, KHÔNG PHẢI MỘT
// MARK: - ===========================================
final class HotPathAXBudgetF4Tests: XCTestCase {

  /// F4 — `testB1_2_AXTimeoutHasOneStableDefault` khoá được "có MỘT mặc định ổn
  /// định", nhưng KHÔNG khoá được ngân sách của đường NÓNG — nên vòng B1 nâng
  /// `Focused.snapshot()` và `isSecureField()` từ 0,05 lên 0,1 mà 419 test vẫn
  /// xanh. Đó là nhân đôi cận trên thời gian chẹn event tap, ở đúng đường chạy
  /// mỗi phím, cho một lần leo cây tới ~50 message AX.
  ///
  /// Hai hằng vì có thật hai ngân sách: `defaultAXTimeout` cho việc chạy NGOÀI
  /// tap thread (`simulationQueue`, `focusRefreshQueue` — nơi nhịp trễ 0,5s tồn
  /// tại chính để chờ hộp thoại native hiện ra), `hotPathAXTimeout` cho mọi thứ
  /// chạy TRÊN tap thread.
  ///
  /// ⚠️ SAU VÒNG LÙI, HẰNG NÀY CÀNG CẦN CHỨ KHÔNG PHẢI BỚT CẦN. Đợt T3 từng gắn
  /// một cổng `if input.isAtWordBoundary` trước lời gọi chụp AX, tức mỗi TỪ mới
  /// chụp một lần; cổng đó đã lùi cùng chốt trục, nên `Focused.snapshot()` chạy
  /// lại MỖI keyDown như HEAD. Ai thấy "chỉ còn một chỗ gọi, gộp hai hằng cho
  /// gọn" thì đang nhân đôi cận trên thời gian chẹn event tap của đường chạy mỗi
  /// phím. Lý do lùi cổng: xem MARK "[ĐÃ XOÁ] test khoá cổng chụp AX theo ranh
  /// giới từ" phía trên.
  func testF4_HotPathAXBudgetIsSeparateFromTheBackgroundBudget() throws {
    XCTAssertEqual(Focused.hotPathAXTimeout, 0.05, accuracy: 0.0001,
      "ngân sách đường nóng — giá trị mà HEAD vô tình chốt lại qua focusedOverlayBundle()")
    XCTAssertEqual(Focused.defaultAXTimeout, 0.1, accuracy: 0.0001,
      "ngân sách nền — KHÔNG đổi ở đợt này")
    XCTAssertLessThan(Focused.hotPathAXTimeout, Focused.defaultAXTimeout,
      "gom hai hằng làm một là nâng cận trên chẹn tap của đường chạy mỗi phím")

    // `snapshot` phải NHẬN ngân sách. Chữ ký là chỗ duy nhất ép được điều đó:
    // nếu ai gỡ tham số, `performFocusedElementRefresh` hết đường xin ngân sách
    // nền và cả hai người gọi lại dùng chung một con số.
    // CỐ Ý KHÔNG GỌI — `snapshot()` đọc AX của máy đang chạy test.
    let signatureLock: [Any] = [
      Focused.snapshot(timeout:) as (Float) -> Focused.FocusSnapshot,
      Focused.focusedElement(timeout:) as (Float) -> AXUIElement?
    ]
    XCTAssertEqual(signatureLock.count, 2,
      "Focused.snapshot + focusedElement phải nhận `timeout:` — fetch system-wide "
        + "tách khỏi leo cây element-scope")

    // `withAXTimeout` vẫn là SCOPE (mượn có thời hạn), không phải một lần ghi.
    XCTAssertEqual(Focused.withAXTimeout(Focused.hotPathAXTimeout) { 7 }, 7)
  }
}
