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

  enum CodingKeys: String, CodingKey {
    case version, vietnamese, english, keep
    case enVnMapping = "en_vn_mapping"
    case vnEnMapping = "vn_en_mapping"
    case macrosRecommended = "macros_recommended"
    case meta = "_meta"
  }
}
