import XCTest
import Defaults
@testable import vkey

final class VNITypingTests: SpellResetTestCase {
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

}
