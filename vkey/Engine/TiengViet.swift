//
//  TiengViet.swift
//  vkey
//
//  Created by KhanhIceTea on 24/02/2024.
//

import Foundation

// MARK: - Enums (Dấu tiếng Việt)

/// DauThanh - 6 thanh điệu tiếng Việt
enum DauThanh: UInt8 {
  case bang = 0    // Thanh ngang (không dấu)
  case sac = 2     // Thanh sắc (´)
  case huyen = 4   // Thanh huyền (`)
  case hoi = 8     // Thanh hỏi (ˀ)
  case nga = 16    // Thanh ngã (~)
  case nang = 32   // Thanh nặng (.)
}

/// DauMu - Dấu phụ trên nguyên âm
enum DauMu: UInt8 {
  case khongMu = 0  // Không có dấu phụ
  case muUp = 2     // Mũ (^): â, ê, ô
  case muMoc = 4    // Móc (˘): ư, ơ
  case muNgua = 8   // Trăng (˘): ă
}

// MARK: - ThanhPhanTieng (Các thành phần âm tiết)

/// ThanhPhanTieng - Các thành phần đã phân tích của âm tiết tiếng Việt:
/// Phụ âm đầu + Nguyên âm + Phụ âm cuối + Phần dư.
struct ThanhPhanTieng {
  var phuAmDau: [Character] = []
  var nguyenAm: [Character] = []
  var phuAmCuoi: [Character] = []
  var conLai: [Character] = []

  var viTriDauMu = -1
  var viTriDauThanh = -1
  var chuaNguyenAmUO = false
  var uuTienDauThanh: DauThanh? = nil

  /// Kiểm tra nguyên âm có chứa ít nhất một ký tự trong danh sách không
  func nguyenAmChua1KyTu(mangKyTu: [Character]) -> Bool {
    mangKyTu.contains { nguyenAm.contains($0) }
  }
}

// MARK: - TiengViet (Namespace cho hằng số)

/// TiengViet - Hằng số ngôn ngữ học và quy tắc chuyển đổi tiếng Việt (100% bất biến).
enum TiengViet {

  // MARK: - Bảng phím dấu dùng chung (Telex / VNI / Parser / Validator / WordBuffer)

  static let TelexToneKeys: [Character: DauThanh] = [
    "s": .sac, "f": .huyen, "r": .hoi, "x": .nga, "j": .nang,
  ]

  static let VNIToneKeys: [Character: DauThanh] = [
    "1": .sac, "2": .huyen, "3": .hoi, "4": .nga, "5": .nang,
  ]

  static let TelexToneKeyChars: Set<Character> = [
    "s", "S", "f", "F", "r", "R", "x", "X", "j", "J",
  ]

  // MARK: - Bảng phụ âm (dạng chữ thường; Trie xử lý case-insensitive và giữ nguyên hoa/thường đầu vào)

  static let PhuAmDon: [String] = [
    "b", "c", "d", "g", "h", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "x",
  ]

  static let PhuAmDonNuocNgoai: [String] = ["z", "w", "j", "f"]

  static let ForeignConsonants: Set<Character> = ["z", "w", "j", "f"]

  static let PhuAmGhep: [String] = [
    "ngh", "ch", "gh", "gi", "kh", "kr", "ng", "nh", "ph", "qu", "th", "tr",
  ]

  static let PhuAmCuoi: [String] = [
    "nh", "ng", "ch", "m", "n", "c", "p", "t", "k",
  ]

  // MARK: - Bảng nguyên âm

  static let NguyenAmDon: [String] = ["a", "e", "i", "y", "o", "u"]

  static let NguyenAmDonSet: Set<Character> = ["a", "e", "i", "y", "o", "u"]

  static let NguyenAmGhep: [String] = [
    // Nguyên âm ba
    "ieu", "oai", "uou", "oeo", "oao", "oay", "uya", "uyu", "uye", "uoi", "yeu", "uay",
    // Nguyên âm đôi
    "uo", "uu", "ua", "ia", "ai", "io", "ao", "au", "oi", "ie", "ay", "oa",
    "eo", "oe", "oo", "ui", "uy", "ye", "eu", "ue", "iu",
  ]

  static let NguyenAm: [String] = NguyenAmGhep + NguyenAmDon

  static let NguyenAmHopLeSet: Set<String> = Set(NguyenAm)

  /// Nguyên âm chứa "uo" - cần xử lý đặc biệt khi đặt dấu móc (→ "ươ")
  static let NguyenAmUO: Set<String> = ["uo", "uou", "uoi"]

  // MARK: - Immutable Case-Insensitive Tries (không còn trạng thái ghi đè / data race)

  private static func buildTrie(_ words: [String]) -> Trie {
    let trie = Trie(caseInsensitive: true)
    words.forEach { trie.insert($0) }
    return trie
  }

  static let PhuAmDauTrieStandard: Trie = buildTrie(PhuAmGhep + PhuAmDon)
  static let PhuAmDauTrieWithZWJF: Trie = buildTrie(PhuAmGhep + PhuAmDon + PhuAmDonNuocNgoai)

  static func phuAmDauTrie(allowedZWJF: Bool) -> Trie {
    allowedZWJF ? PhuAmDauTrieWithZWJF : PhuAmDauTrieStandard
  }

  static let NguyenAmTrie: Trie = buildTrie(NguyenAm)
  static let PhuAmCuoiTrie: Trie = buildTrie(PhuAmCuoi)

  // MARK: - Guard chống swap `ou→uo` sớm trên prefix từ tiếng Anh

  /// English words chứa `ou` — khi keys đang là prefix (vd `sou` → `source`),
  /// không áp typo-swap `ou→uo` lúc tail rỗng (tránh `Sou` → `Suo` → `Suorce`).
  /// Không gồm `bout`/`bound`/… để giữ path VN `bou`→`buo`.
  private static let englishOuTypoGuardWords: Set<String> = [
    "about", "source", "sources", "soup", "sound", "sounds",
    "south", "southern", "southeast", "southwest",
    "count", "counts", "country", "countries", "county", "counties",
    "couple", "course", "court", "cousin", "courage",
    "double", "doubt", "dough", "downtown",
    "your", "yours", "yourself", "yourselves", "you", "young", "youth",
    "hour", "hours", "house", "mouse", "group", "route", "resource",
    "trouble", "through", "though", "thought", "cloud", "loud", "proud",
    "round", "ground", "wound", "would", "could", "should", "mount", "mountain",
    "pour", "tour", "tours", "flour", "found", "around", "amount",
  ]

  static func isEnglishOuTypoInProgress(_ keys: [Character]) -> Bool {
    let s = String(keys).lowercased()
    guard s.count >= 3 else { return false }
    if s.hasPrefix("bou") { return false }
    if englishOuTypoGuardWords.contains(s) { return true }
    return englishOuTypoGuardWords.contains { $0.hasPrefix(s) && $0.count > s.count }
  }

  // MARK: - Quy tắc chuyển đổi O(1)

  static let QuyTacDatDau: [DauThanh: [Character: Character]] = [
    .bang: [:],
    .sac: [
      "u": "ú", "ư": "ứ", "e": "é", "ê": "ế", "o": "ó", "ô": "ố", "ơ": "ớ",
      "a": "á", "â": "ấ", "ă": "ắ", "i": "í", "y": "ý",
      "U": "Ú", "Ư": "Ứ", "E": "É", "Ê": "Ế", "O": "Ó", "Ô": "Ố", "Ơ": "Ớ",
      "A": "Á", "Â": "Ấ", "Ă": "Ắ", "I": "Í", "Y": "Ý",
    ],
    .huyen: [
      "u": "ù", "ư": "ừ", "e": "è", "ê": "ề", "o": "ò", "ô": "ồ", "ơ": "ờ",
      "a": "à", "â": "ầ", "ă": "ằ", "i": "ì", "y": "ỳ",
      "U": "Ù", "Ư": "Ừ", "E": "È", "Ê": "Ề", "O": "Ò", "Ô": "Ồ", "Ơ": "Ờ",
      "A": "À", "Â": "Ầ", "Ă": "Ằ", "I": "Ì", "Y": "Ỳ",
    ],
    .hoi: [
      "u": "ủ", "ư": "ử", "e": "ẻ", "ê": "ể", "o": "ỏ", "ô": "ổ", "ơ": "ở",
      "a": "ả", "â": "ẩ", "ă": "ẳ", "i": "ỉ", "y": "ỷ",
      "U": "Ủ", "Ư": "Ử", "E": "Ẻ", "Ê": "Ể", "O": "Ỏ", "Ô": "Ổ", "Ơ": "Ở",
      "A": "Ả", "Â": "Ẩ", "Ă": "Ẳ", "I": "Ỉ", "Y": "Ỷ",
    ],
    .nga: [
      "u": "ũ", "ư": "ữ", "e": "ẽ", "ê": "ễ", "o": "õ", "ô": "ỗ", "ơ": "ỡ",
      "a": "ã", "â": "ẫ", "ă": "ẵ", "i": "ĩ", "y": "ỹ",
      "U": "Ũ", "Ư": "Ữ", "E": "Ẽ", "Ê": "Ễ", "O": "Õ", "Ô": "Ỗ", "Ơ": "Ỡ",
      "A": "Ã", "Â": "Ẫ", "Ă": "Ẵ", "I": "Ĩ", "Y": "Ỹ",
    ],
    .nang: [
      "u": "ụ", "ư": "ự", "e": "ẹ", "ê": "ệ", "o": "ọ", "ô": "ộ", "ơ": "ợ",
      "a": "ạ", "â": "ậ", "ă": "ặ", "i": "ị", "y": "ỵ",
      "U": "Ụ", "Ư": "Ự", "E": "Ẹ", "Ê": "Ệ", "O": "Ọ", "Ô": "Ộ", "Ơ": "Ợ",
      "A": "Ạ", "Â": "Ậ", "Ă": "Ặ", "I": "Ị", "Y": "Ỵ",
    ],
  ]

  static let QuyTacDatMu: [DauMu: [Character: Character]] = [
    .khongMu: [:],
    .muUp: ["a": "â", "e": "ê", "o": "ô", "A": "Â", "E": "Ê", "O": "Ô"],
    .muNgua: ["a": "ă", "A": "Ă"],
    .muMoc: ["o": "ơ", "u": "ư", "O": "Ơ", "U": "Ư"],
  ]

  static let QuyTacGachD: [Character: Character] = ["d": "đ", "D": "Đ"]
}
