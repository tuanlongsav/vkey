//
//  EnVnReference.swift
//  vkey
//
//  Bilingual reference lookup: English ↔ Vietnamese. Introduced in 1.5.0 as
//  the foundation for two user-visible features:
//
//  1. Translation HUD (Phase 5.3) — when the user types an English word in
//     Vietnamese mode and we restore it, we can simultaneously surface the
//     Vietnamese candidate(s) so they're discoverable.
//  2. Better SpellDecisionEngine choices (Phase 4.4) — knowing that "love"
//     has a Vietnamese rendering lets us prefer English restoration over a
//     fuzzy Vietnamese suggestion when ambiguous.
//
//  Data source attribution (kept in lexicon-update.json's `_meta` block):
//  - English Wiktionary via Wiktextract / Kaikki.org, CC BY-SA 4.0.
//  - English frequency baseline: wordfreq by Robyn Speer (MIT + CC BY-SA 4.0
//    for Wiktionary-derived data).
//
//  No data is bundled inside this file — the embedded English/Vietnamese
//  word lists in `EmbeddedLexiconData` already serve as a fallback so the
//  app works offline before the first lexicon update lands.
//

import Foundation

/// Read-mostly bidirectional dictionary. Loads are infrequent (on app
/// startup + when the user pulls a fresh `lexicon-update.json`); reads are
/// hot (every committed word the user types).
final class EnVnReference {

  private struct ReferenceSnapshot {
    var enToVn: [String: [String]] = [:]
    var vnToEn: [String: [String]] = [:]
    var enPrefixTrie = Trie(caseInsensitive: true)
  }

  private let queue = DispatchQueue(
    label: "dev.longht.vkey.en-vn-reference",
    qos: .userInitiated,
    attributes: .concurrent
  )
  private var snapshot = ReferenceSnapshot()

  /// English → Vietnamese candidate translations.
  var enToVn: [String: [String]] {
    queue.sync { snapshot.enToVn }
  }

  /// Vietnamese → English candidate translations. Reverse map for the
  /// Dictionary Browser; the spell engine doesn't read this hot path.
  var vnToEn: [String: [String]] {
    queue.sync { snapshot.vnToEn }
  }

  /// Singleton instance shared with `LexiconManager`.
  static let shared = EnVnReference()

  /// Load a freshly-decoded package's bilingual maps into memory. Old
  /// content is fully replaced (idempotent). Safe to call from any thread —
  /// callers go through `LexiconManager`'s queue.
  func load(en2vn: [String: [String]]?, vn2en: [String: [String]]?) {
    let enToVn = (en2vn ?? [:]).reduce(into: [String: [String]]()) { acc, pair in
      let key = pair.key.normalizedDictionaryToken
      guard !key.isEmpty else { return }
      acc[key] = pair.value
    }
    let vnToEn = (vn2en ?? [:]).reduce(into: [String: [String]]()) { acc, pair in
      let key = pair.key.normalizedDictionaryToken
      guard !key.isEmpty else { return }
      acc[key] = pair.value
    }
    // 1.9.0: build fresh Trie và swap. Trước v1.9.0 enPrefixTrie là `let`
    // và rebuildPrefixTrie() chỉ insert thêm → cumulative + stale results
    // qua mỗi lexicon load. Giờ swap thật sự.
    let fresh = Trie(caseInsensitive: true)
    for english in enToVn.keys {
      fresh.insert(english)
    }
    let nextSnapshot = ReferenceSnapshot(
      enToVn: enToVn,
      vnToEn: vnToEn,
      enPrefixTrie: fresh
    )
    queue.sync(flags: .barrier) {
      snapshot = nextSnapshot
    }
  }

  /// English word → Vietnamese candidates, or nil if not present.
  /// Lookup is case-insensitive (token-normalised).
  func lookupEnglish(_ word: String) -> [String]? {
    let key = word.normalizedDictionaryToken
    return queue.sync { snapshot.enToVn[key] }
  }

  /// Vietnamese word → English candidates, or nil if not present.
  func lookupVietnamese(_ word: String) -> [String]? {
    let key = word.normalizedDictionaryToken
    return queue.sync { snapshot.vnToEn[key] }
  }

  /// True if `prefix` is the start of any English entry. Used by the input
  /// pipeline to defer Vietnamese diacritic application while the user
  /// types something that *might* turn out to be English.
  func hasEnglishPrefix(_ prefix: String) -> Bool {
    let normalized = prefix.normalizedDictionaryToken
    guard !normalized.isEmpty else { return false }
    return queue.sync {
      snapshot.enPrefixTrie.findLongestPrefix(in: normalized) != nil
        || snapshot.enToVn.keys.contains { $0.hasPrefix(normalized) }
    }
  }

  /// Counts useful for the Diagnostics panel.
  var entryCount: (en: Int, vn: Int) {
    queue.sync { (snapshot.enToVn.count, snapshot.vnToEn.count) }
  }

}
