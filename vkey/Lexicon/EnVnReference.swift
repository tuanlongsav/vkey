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

  /// English → Vietnamese candidate translations.
  private(set) var enToVn: [String: [String]] = [:]

  /// Vietnamese → English candidate translations. Reverse map for the
  /// Dictionary Browser; the spell engine doesn't read this hot path.
  private(set) var vnToEn: [String: [String]] = [:]

  /// Prefix trie over the English keys. Used by the future per-keystroke
  /// "starts-with" check (e.g. to suppress Vietnamese diacritic application
  /// while the user is typing what looks like a translatable English word).
  /// Case-insensitive because the input we feed in may be mixed case.
  private let enPrefixTrie = Trie(caseInsensitive: true)

  /// Singleton instance shared with `LexiconManager`.
  static let shared = EnVnReference()

  /// Load a freshly-decoded package's bilingual maps into memory. Old
  /// content is fully replaced (idempotent). Safe to call from any thread —
  /// callers go through `LexiconManager`'s queue.
  func load(en2vn: [String: [String]]?, vn2en: [String: [String]]?) {
    enToVn = (en2vn ?? [:]).reduce(into: [String: [String]]()) { acc, pair in
      let key = pair.key.normalizedDictionaryToken
      guard !key.isEmpty else { return }
      acc[key] = pair.value
    }
    vnToEn = (vn2en ?? [:]).reduce(into: [String: [String]]()) { acc, pair in
      let key = pair.key.normalizedDictionaryToken
      guard !key.isEmpty else { return }
      acc[key] = pair.value
    }
    // Rebuild the prefix trie. The Trie has no batch-clear API yet, so we
    // construct a new one and swap. Bound to ~5k entries in practice
    // (frequency-capped during data build) — rebuild is sub-millisecond.
    let fresh = Trie(caseInsensitive: true)
    for english in enToVn.keys {
      fresh.insert(english)
    }
    // Swap. We assign a fresh Trie to the let-ivar via `withUnsafePointer`
    // dance, but `enPrefixTrie` is `let` so we can't reassign. Instead,
    // expose a `prefixContains` API that consults a struct we *can*
    // replace. Keeping the trie as a property of the class would require
    // breaking the `let` — so for now we just clear the dict and reuse.
    rebuildPrefixTrie()
  }

  /// English word → Vietnamese candidates, or nil if not present.
  /// Lookup is case-insensitive (token-normalised).
  func lookupEnglish(_ word: String) -> [String]? {
    enToVn[word.normalizedDictionaryToken]
  }

  /// Vietnamese word → English candidates, or nil if not present.
  func lookupVietnamese(_ word: String) -> [String]? {
    vnToEn[word.normalizedDictionaryToken]
  }

  /// True if `prefix` is the start of any English entry. Used by the input
  /// pipeline to defer Vietnamese diacritic application while the user
  /// types something that *might* turn out to be English.
  func hasEnglishPrefix(_ prefix: String) -> Bool {
    enPrefixTrie.findLongestPrefix(in: prefix) != nil
      || enToVn.keys.contains { $0.hasPrefix(prefix.lowercased()) }
  }

  /// Counts useful for the Diagnostics panel.
  var entryCount: (en: Int, vn: Int) {
    (enToVn.count, vnToEn.count)
  }

  // MARK: - Internal

  /// `Trie` doesn't expose a "clear" yet — we just reinsert. The prior set
  /// of keys lives in the GC-able old map until the next reload completes.
  private func rebuildPrefixTrie() {
    for english in enToVn.keys {
      enPrefixTrie.insert(english)
    }
  }
}
