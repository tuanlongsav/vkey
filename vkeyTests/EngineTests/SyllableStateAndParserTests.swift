import XCTest
import Defaults
@testable import vkey

final class SyllableStateAndParserTests: SpellResetTestCase {
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


  /// v2.3.6 — Loanword consonants (w/z/j/f) KHÔNG được áp swap typo-correction.
  /// Bug: gõ "weight" trong ô tìm kiếm → "wieght" vì rule veit→viet swap "ei" → "ie".
  /// Tiếng Việt không có từ bản địa bắt đầu bằng w/z/j/f → mọi từ w-/z-/j-/f- là loanword.
  func testForeignConsonantSkipsVowelSwapTypoCorrection() throws {
    // Setup: allowedZWJF = true để w/z/j/f là phụ âm đầu (mặc định của TiengVietParser.parse).
    // veit→viet rule: KHÔNG fire cho phụ âm đầu loanword.
    // "wei" — nguyenAm phải giữ là "e", "i" ở conLai (raw). KHÔNG được swap thành "ie".
    let wei = TiengVietParser.parse(Array("wei"), allowedZWJF: true)
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
}

// MARK: - vkey 1.5.0 Phase 1 — Engine regression suite

/// Tests added in the 1.5.0 engine pass:
/// - Parametric tone placement for kiểu cũ vs kiểu mới (1.4)
/// - chuaNguyenAmUO recomputed after typo correction (1.1)
/// - Trie case-insensitive option (1.3)
/// - Late D toggle shared between Telex & VNI (1.6)
/// - pop() keeps tone when vowel remains (1.7)
final class EngineV150Tests: XCTestCase {

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
