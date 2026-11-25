import XCTest
import Defaults
@testable import vkey

final class EngineRegressionTests: SpellResetTestCase {
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

}

// MARK: - ===========================================
// MARK: - Upstream Regression Suite (gonhanh.org & xkey)
// MARK: - ===========================================

/// Đối chiếu các bug fix của gonhanh.org (khaphanspace) & xkey (xmannv) để
/// chống hồi quy trên vkey. Đặt trong vkeyTests.swift vì project liệt kê file
/// test thủ công (không synchronized group) — file .swift riêng sẽ KHÔNG được
/// biên dịch vào target.
final class UpstreamRegressionTests: XCTestCase {

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
