import XCTest
import Defaults
@testable import vkey

/// Focused unit tests for the syllable validator.
/// The integration tests above exercise validator indirectly through transform_text_*.
/// These tests pin down individual rules so regressions are easy to diagnose.
final class TiengVietValidatorTests: SpellResetTestCase {

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


// MARK: - ===========================================
// MARK: - Vowel Typo-Correction Final-Consonant Guard (v2.15)
// MARK: - ===========================================

/// Typo-correction "ou→uo" / "ei→ie" / "aoi→oai" KHÔNG được nuốt phụ âm cuối.
/// Bug "Opus"→"uOs": gõ "opu" cho o=nguyênÂm, p=phụÂmCuối, u=conLai; reparse
/// "uo" nuốt mất 'p'. Fix: chỉ reparse khi phuAmCuoi rỗng.
final class VowelTypoFinalConsonantTests: XCTestCase {
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
