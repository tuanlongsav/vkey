//
//  LexiconUpdatePackage.swift
//  vkey
//
//  Codable shape of `lexicon/lexicon-update.json`. Schema v5 (1.5.0) adds the
//  optional `en_vn_mapping`, `vn_en_mapping`, `macros_recommended` and
//  `_meta` fields alongside the original word lists. Older builds simply
//  ignore the extra keys — forward-compatible by design (JSONDecoder treats
//  unknown keys as no-ops).
//

import CryptoKit
import Foundation

/// Top-level metadata describing where the data came from. Optional so older
/// JSON files without it still decode.
struct LexiconUpdateMeta: Codable, Equatable {
  let version: Int?
  let generatedAt: String?
  let sources: [LexiconSourceInfo]?
  let licenseOfAggregate: String?

  enum CodingKeys: String, CodingKey {
    case version
    case generatedAt = "generated_at"
    case sources
    case licenseOfAggregate = "license_of_aggregate"
  }
}

struct LexiconSourceInfo: Codable, Equatable {
  let name: String?
  let url: String?
  let license: String?
  let usedFor: String?

  enum CodingKeys: String, CodingKey {
    case name, url, license
    case usedFor = "used_for"
  }
}

/// A macro suggestion the onboarding flow can offer the user to import.
/// Decoupled from the runtime `Macro` struct so the JSON shape doesn't have
/// to ship a UUID.
struct MacroSeed: Codable, Equatable {
  let from: String
  let to: String
}

struct LexiconUpdatePackage: Codable {
  let version: Int
  let vietnamese: [String]
  let english: [String]
  let keep: [String]

  /// Schema v5: optional English → [Vietnamese candidates] map.
  /// Powers translation suggestions and informs `SpellDecisionEngine` when a
  /// raw English token has a canonical Vietnamese rendering.
  let enVnMapping: [String: [String]]?

  /// Schema v5: optional Vietnamese → [English candidates] map.
  /// Used by the Dictionary Browser; not consulted by the main spell engine.
  let vnEnMapping: [String: [String]]?

  /// Schema v5: optional recommended macros (consumed by the onboarding
  /// "import preset" flow).
  let macrosRecommended: [MacroSeed]?

  /// Schema v5: optional metadata block with attribution and license info.
  /// JSON key is `_meta` (the underscore prefix marks "metadata older
  /// decoders may ignore" — JSONDecoder doesn't enforce it, so we just map
  /// the key explicitly).
  let meta: LexiconUpdateMeta?

  /// L1: optional detached Ed25519 signature (base64) over the canonical
  /// payload (see `LexiconSignatureVerifier`). Absent in older/unsigned files
  /// — verification is only enforced when a public key is configured in
  /// `LexiconManager`, so this stays forward/backward compatible.
  let signature: String?

  enum CodingKeys: String, CodingKey {
    case version, vietnamese, english, keep
    case enVnMapping = "en_vn_mapping"
    case vnEnMapping = "vn_en_mapping"
    case macrosRecommended = "macros_recommended"
    case meta = "_meta"
    case signature = "sig"
  }
}

// MARK: - L4: structural bounds validation

extension LexiconUpdatePackage {
  enum ValidationError: Error { case tooLarge }

  /// Số entry / độ dài tối đa chấp nhận. Chặn gói JSON hợp lệ về cú pháp nhưng
  /// lớn bất thường (nếu endpoint bị chiếm) khiến materialize Set/Trie phình bộ nhớ.
  static let maxEntries = 200_000
  static let maxStringLength = 256
  /// Macro `to` là đoạn văn bản mở rộng (chữ ký, mẫu câu, có thể nhiều dòng) nên
  /// nới rộng hơn token từ điển — nhưng vẫn chặn để 1 macro khổng lồ không phình bộ nhớ.
  static let maxMacroExpansionLength = 8192

  /// Trả về chính nó nếu trong giới hạn, ném `ValidationError.tooLarge` nếu vượt.
  @discardableResult
  func validated() throws -> LexiconUpdatePackage {
    guard vietnamese.count <= Self.maxEntries,
          english.count <= Self.maxEntries,
          keep.count <= Self.maxEntries,
          (enVnMapping?.count ?? 0) <= Self.maxEntries,
          (vnEnMapping?.count ?? 0) <= Self.maxEntries,
          (macrosRecommended?.count ?? 0) <= Self.maxEntries
    else { throw ValidationError.tooLarge }

    let overLong: (String) -> Bool = { $0.count > Self.maxStringLength }
    if vietnamese.contains(where: overLong)
        || english.contains(where: overLong)
        || keep.contains(where: overLong) {
      throw ValidationError.tooLarge
    }
    // Mapping (key + từng candidate) cũng phải trong giới hạn độ dài/số lượng —
    // 1 entry khổng lồ vẫn phình bộ nhớ dù tổng count nhỏ.
    for map in [enVnMapping, vnEnMapping] {
      guard let map else { continue }
      for (key, candidates) in map {
        if overLong(key) || candidates.count > Self.maxEntries
            || candidates.contains(where: overLong) {
          throw ValidationError.tooLarge
        }
      }
    }
    // Macro: `from` (trigger) ngắn như token; `to` (đoạn mở rộng) nới rộng hơn.
    for macro in macrosRecommended ?? [] {
      if overLong(macro.from) || macro.to.count > Self.maxMacroExpansionLength {
        throw ValidationError.tooLarge
      }
    }
    return self
  }
}

// MARK: - L1: Ed25519 signature verification

/// Xác minh chữ ký gói từ điển. Kênh update từ điển hiện KHÔNG ký (chỉ check
/// `version >`); đây là cơ chế để bật khi publisher ký server-side.
///
/// Bật bằng cách: sinh cặp khóa Ed25519, ký `canonicalPayload(for:)` phía
/// server, đặt chuỗi base64 vào field `sig` của `lexicon-update.json`, rồi dán
/// public key (base64) vào `LexiconManager.lexiconPublicKeyBase64`.
enum LexiconSignatureVerifier {
  /// Chuỗi canonical được ký: version + TẤT CẢ trường ảnh hưởng hành vi runtime
  /// (word-lists, en_vn/vn_en mapping, macros) — không chỉ 3 word-list. Mọi giá
  /// trị được length-prefix (`<byteCount>:<utf8>`) nên KHÔNG nhập nhằng dù token/
  /// macro chứa '\n', ':' hay ký tự phân tách (chống second-preimage kiểu gộp/
  /// tách entry). Mọi list/map/macro sort trước khi nối → độc lập thứ tự JSON,
  /// deterministic.
  static func canonicalPayload(for p: LexiconUpdatePackage) -> Data {
    var out = Data()
    func put(_ s: String) {
      let bytes = Array(s.utf8)
      out.append(contentsOf: "\(bytes.count):".utf8)
      out.append(contentsOf: bytes)
    }
    func putList(_ list: [String]) {
      let sorted = list.sorted()
      put("#\(sorted.count)")
      for item in sorted { put(item) }
    }
    func putMap(_ map: [String: [String]]?) {
      let map = map ?? [:]
      let keys = map.keys.sorted()
      put("#\(keys.count)")
      for key in keys {
        put(key)
        putList(map[key] ?? [])
      }
    }
    put("v\(p.version)")
    putList(p.vietnamese)
    putList(p.english)
    putList(p.keep)
    putMap(p.enVnMapping)
    putMap(p.vnEnMapping)
    let macros = (p.macrosRecommended ?? [])
      .map { ($0.from, $0.to) }
      .sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
    put("#\(macros.count)")
    for (from, to) in macros { put(from); put(to) }
    return out
  }

  /// True nếu verification TẮT (public key rỗng) HOẶC chữ ký hợp lệ. Chỉ trả
  /// false khi đã cấu hình public key mà chữ ký thiếu/sai.
  static func verify(package: LexiconUpdatePackage, publicKeyBase64: String) -> Bool {
    guard !publicKeyBase64.isEmpty else { return true }  // verification disabled
    guard let sigB64 = package.signature,
          let sig = Data(base64Encoded: sigB64),
          let keyData = Data(base64Encoded: publicKeyBase64),
          let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    else { return false }
    return key.isValidSignature(sig, for: canonicalPayload(for: package))
  }
}
