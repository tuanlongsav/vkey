//
//  vkeyTests.swift
//  vkeyTests
//
//  Created by KhanhIceTea on 20/02/2024.
//

import XCTest
import Defaults
import AppKit

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

    // Test 2: "go" → "gô" (step thêm dấu mũ). NFD chỉ cần append combining mark.
    let (gôBs, gôDiff) = EventSimulator.calcKeyStrokesNFD(from: "go", to: "gô")
    XCTAssertEqual(gôBs, 0, "0 backspace — chỉ thêm combining mark")
    XCTAssertEqual(gôDiff.count, 1, "1 char (combining mark) thêm vào")
    XCTAssertEqual(String(gôDiff).unicodeScalars.first?.value, 0x0302,
                   "Diff là combining circumflex U+0302")

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
    
    let (backspaces1, diff1) = processor.pop()
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
    let (backspaces2, diff2) = processor.pop()
    XCTAssertEqual(backspaces2, 0) // lets OS handle it (1-char delete)
    XCTAssertEqual(String(diff2), "")
    XCTAssertEqual(processor.transformed, "dinhjh")
    
    // Backspace again to restore "dịnh" (keys: "dinjh", from snapshot)
    let (backspaces3, diff3) = processor.pop()
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
    
    let (vniB1, vniD1) = vniProcessor.pop()
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

    let engine = SpellDecisionEngine.shared
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

  /// Test mixed case
  func testTelexMixedCase() throws {
    XCTAssertEqual(transform_text_telex(for: "Vieejt"), "Việt")
    XCTAssertEqual(transform_text_telex(for: "DDuowngf"), "Đường")
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
    // Riêng "pass" (prefix "pa" hợp lệ VN, không impossible) bị tone-cancel
    // catch ở second 's' → "pas". Trade-off chấp nhận được.
    XCTAssertEqual(transform_text_telex(for: "off"), "off")
    XCTAssertEqual(transform_text_telex(for: "class"), "class")
    XCTAssertEqual(transform_text_telex(for: "pass"), "pas")
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
    let _ = inputProcessor.pop()
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
    let (numBackspaces, diffChars) = inputProcessor.pop()

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
    let (bs1, diff1) = inputProcessor.pop()
    XCTAssertEqual(bs1, 0)
    XCTAssertEqual(diff1, [])
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "st")
    
    // Press backspace again -> rolls back to "s", which is valid, so recovery disarms!
    let (bs2, diff2) = inputProcessor.pop()
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

    let (backspaces, diff) = buffer.pop(engine: engine)
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
    _ = buffer.pop(engine: engine)
    XCTAssertFalse(buffer.stopProcessing)
    XCTAssertEqual(buffer.transformed, "hồ")
  }

  /// Pop without prior recovery removes the last character normally.
  func testPopRemovesLastChar() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chao" { buffer.push(char: char, engine: engine) }
    XCTAssertEqual(buffer.transformed, "chao")

    _ = buffer.pop(engine: engine)
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

  func testIsNumberKey() throws {
    let layout = KeyboardUS()
    XCTAssertTrue(layout.isNumberKey(keyCode: 18)) // 1
    XCTAssertTrue(layout.isNumberKey(keyCode: 29)) // 0
    XCTAssertFalse(layout.isNumberKey(keyCode: 0)) // A
    XCTAssertFalse(layout.isNumberKey(keyCode: 49)) // Space
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
      macros: macros
    )

    XCTAssertEqual(replacement?.backspaceCount, 2)
    XCTAssertEqual(String(replacement?.diffChars ?? []), "địa chỉ ")
  }

  func testMacroReplacementWithPunctuation() throws {
    let macros = [Macro(from: "email", to: "long@example.com")]
    let replacement = InputProcessor.macroReplacement(
      for: "email",
      endingChar: ".",
      macros: macros
    )

    XCTAssertEqual(replacement?.backspaceCount, 5)
    XCTAssertEqual(String(replacement?.diffChars ?? []), "long@example.com.")
  }

  func testMacroReplacementNoMatch() throws {
    let macros = [Macro(from: "dc", to: "địa chỉ")]

    XCTAssertNil(InputProcessor.macroReplacement(for: "dt", endingChar: " ", macros: macros))
  }

  func testMacroReplacementIgnoresEmptyCurrentAndFields() throws {
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "",
        endingChar: " ",
        macros: [Macro(from: "dc", to: "địa chỉ")]
      )
    )
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "dc",
        endingChar: " ",
        macros: [Macro(from: "", to: "địa chỉ")]
      )
    )
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "dc",
        endingChar: " ",
        macros: [Macro(from: "dc", to: "")]
      )
    )
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

  func testTransformationTrackerDetectsRepeatedFailureSignals() throws {
    var tracker = TransformationTracker()
    tracker.resetForApp("com.example.app")

    let failure = EventSendTelemetry(
      attemptedTransform: true,
      createdEvents: false,
      usedAsyncQueue: false,
      touchedCharacters: 4
    )

    XCTAssertFalse(tracker.detectFailure(telemetry: failure, appLikelySensitive: true))
    XCTAssertTrue(tracker.detectFailure(telemetry: failure, appLikelySensitive: true))
  }

  func testStepByStepUnicodeUnitsPreserveWholeCharacter() throws {
    XCTAssertEqual(
      EventSimulator.unicodeUnits(for: "ắ"),
      String("ắ").utf16.map { UniChar($0) }
    )
    XCTAssertEqual(EventSimulator.unicodeUnits(for: "😀").count, 2)
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
    defer {
      Defaults.reset(.userAllowWords)
      Defaults.reset(.macros)
      Defaults.reset(.perAppOverride)
    }

    let export = UserDataMigration.currentExport(includeStatistics: false)
    XCTAssertEqual(export.schemaVersion, UserDataExport.currentSchemaVersion)
    XCTAssertEqual(export.userAllowWords?.sorted(), ["alpha", "beta"])
    XCTAssertEqual(export.macros?.first?.from, "vn")
    XCTAssertEqual(export.perAppOverride?["com.apple.Terminal"], "off")
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
    XCTAssertTrue(changes.contains { $0.contains("Allow words: +1") })
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
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 2, backspaceCount: 1), 1)
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 2, backspaceCount: 2), 0)
  }

  func testNFDCombiningMark() throws {
    // "gõ" NFD: g(1) + o(1) + ◌̃(1) = length 3; xoá 1 phải lùi NGUYÊN cụm o+◌̃ → 1
    let s = "go\u{0303}"
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 1), 1)
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 2), 0)
  }

  func testClampsAtZeroAndHandlesEmptyValue() throws {
    XCTAssertEqual(EventSimulator.axDeleteStart("", caretUTF16: 0, backspaceCount: 3), 0)
    XCTAssertEqual(EventSimulator.axDeleteStart("ab", caretUTF16: 2, backspaceCount: 99), 0)
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
}
