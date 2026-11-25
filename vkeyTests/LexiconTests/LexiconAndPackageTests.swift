import XCTest
import CryptoKit
import Defaults
@testable import vkey

final class LexiconPackageSecurityTests: SpellResetTestCase {
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
