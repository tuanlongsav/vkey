//
//  EmbeddedLexiconData.swift
//  vkey
//
//  Vietnamese (7,184 syllables loaded from Resources/syllables.txt),
//  hand-curated English conflict list, OU typo guard, keep-word, and legacy
//  restore datasets shipped inside the app bundle.
//
//  Attribution (kept here so it travels with the data):
//  - Vietnamese syllables: @hieuthi / common-vietnamese-syllables
//    https://github.com/vietnameselanguage/syllable
//    https://gist.github.com/hieuthi/1f5d80fca871f3642f61f7e3de883f3a
//  - 1.5.0 extensions credit Wiktionary / Kaikki.org and wordfreq —
//    see CHANGELOG.md and README.md "Ghi công" section.
//

import Foundation

/// Embedded data shipped inside the app bundle.
struct EmbeddedLexiconData {
  static let version = 2

  /// Bộ 7.184 âm tiết tiếng Việt chuẩn (@hieuthi), đọc một lần từ
  /// `Resources/syllables.txt` thay vì nhân đôi trong binary + asset catalog.
  static let vietnameseWords: Set<String> = {
    let url = Bundle.main.url(forResource: "syllables", withExtension: "txt")
      ?? Bundle.allBundles.compactMap { $0.url(forResource: "syllables", withExtension: "txt") }.first
    guard let url, let raw = try? String(contentsOf: url, encoding: .utf8) else {
      return []
    }
    let list = raw.components(separatedBy: "\n")
      .map { $0.normalizedDictionaryToken }
      .filter { !$0.isEmpty }
    return Set(list)
  }()

  static let englishWords: Set<String> = Set([
    // 4.13: "list" đã loại — Telex thuần "list" → "lít" (từ VN phổ biến),
    // cùng quy tắc v2.8/v2.9 bên dưới (như docs→dóc). EN "list" gõ "lisst"
    // (double-s) hoặc chuyển mode. "this"→"thí", "sax"→"sã" vẫn ở list nhưng
    // bị guard toneKeyCompletesVietnameseWord (WordBuffer) cho VN thắng.
    "of", "if", "see", "text", "expect", "choose", "business", "address", "email",
    "long", "example", "com", "view", "about", "keep", "deep", "sleep", "risk",
    "desk", "disk", "cursor", "param", "career", "peer", "sax", "toto",
    "nurses", "horses", "house", "metric", "off", "class", "pass", "staff",
    "ass", "aff", "arr", "axx", "ajj",
    "they", "them", "their", "then", "there", "these", "this", "that", "those", "than",
    // v2.2.0: vowel-consonant-vowel English words misfiring Telex mũ rule.
    // Pattern: 'e..e', 'a..a', 'o..o' where the second vowel triggers mũ
    // application even though syllable already closed by final consonant.
    "themes", "scheme", "schemes", "scene", "scenes",
    "phone", "phones", "tone", "tones", "stone", "stones", "throne", "thrones",
    "type", "types", "hype", "ripe", "pipe", "wipe", "wine", "vine", "line", "lines",
    "mine", "fine", "dine", "nine", "prime", "time", "times", "lime", "dime",
    "gate", "late", "mate", "rate", "date", "fate", "hate", "plate", "state",
    "page", "rage", "cage", "wage", "age", "stage", "image",
    "code", "node", "mode", "rode", "make", "take", "lake", "fake", "wake", "stake",
    "size", "rise", "wise", "prize", "price", "nice", "rice", "spice", "mice",
    "more", "store", "core", "score", "shore", "before",
    "side", "ride", "hide", "wide", "guide", "slide",
    "bite", "site", "kite", "white", "write", "quite",
    "vote", "note", "wrote", "remote", "quote",
    "rude", "dude",
    "rope", "hope", "scope", "slope",
    "cake", "bake", "snake", "shake", "brake",
    "save", "wave", "have", "behave", "brave", "gave",
    // E-mid words: 'e' + cons + 'e'
    "here", "where",
    // 'a' + cons + 'a' (rare but possible)
    "data", "java", "lava",
    // v2.3.8: Common tech/brand + "oo"-pattern English words bị Telex áp
    // `oo → ô`. Match đầy đủ vào instantRestore để engine bypass Telex NGAY.
    "google", "youtube", "facebook", "twitter", "instagram", "yahoo",
    "amazon", "outlook", "linkedin", "tools", "tool", "sheet", "sheets",
    "doc", "spreadsheet", "spreadsheets",
    // Common "oo" English words mid-typing dễ trigger Telex mu.
    "good", "goods", "wood", "woods", "look", "looks", "looking",
    "book", "books", "cook", "cooks", "took", "boot", "shoot", "shoots", "root",
    "tooth", "teeth", "smooth", "school", "schools", "food", "foods",
    "mood", "moods", "loop", "scoop", "scoops",
    // Common "ee" English words mid-typing dễ trigger Telex mu.
    "feed", "feeds", "need", "needs", "seed", "seeds", "feet", "meet",
    "week", "weeks", "weekend", "weekends",
    // v2.8/v2.9: đã loại các từ EN mà Telex thuần biến đổi ra MỘT TỪ VIỆT HỢP
    // LỆ & phổ biến — instant-restore không được đè khi đang gõ tiếng Việt.
    "screen", "screens", "green", "greens", "feel",
    "feels", "feeling", "feelings", "wheel", "wheels", "three", "agree",
    "between", "freeze", "free", "trees",
    // v3.11+: từ EN có `ou` — instant-restore khi gõ xong cả từ.
    "source", "sources", "count", "counts", "double", "soup", "sound", "sounds",
    "your", "yours", "you", "young", "youth",
  ])

  static let keepVietnameseWords: Set<String> = Set([
    "lisa", "maria", "para", "sara"
  ])

  static let legacyRestorePairs: [String: String] = [
    "ò": "of",
    "ì": "if",
    "sê": "see",
    "tê": "tee",
  ]
}
