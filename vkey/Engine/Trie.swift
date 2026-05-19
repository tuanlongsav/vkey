//
//  Trie.swift
//  vkey
//
//  Data structure for fast prefix matching.
//
//  Supports an optional case-insensitive mode: when enabled, all inserts and
//  lookups are normalised to lowercase. This is used for the bilingual
//  lexicon (English ↔ Vietnamese reference, where user input may be in any
//  casing). The Vietnamese-syllable Tries keep the original case-sensitive
//  behaviour because they need to distinguish "Nh"/"nH"/"NH" variants for
//  precise syllable matching.
//

import Foundation

final class TrieNode {
  var children: [Character: TrieNode] = [:]
  var isEndOfWord: Bool = false
  /// Original (non-folded) word stored at this terminal node.
  var value: String?
}

final class Trie {
  private let root = TrieNode()
  private let caseInsensitive: Bool

  init(caseInsensitive: Bool = false) {
    self.caseInsensitive = caseInsensitive
  }

  /// Insert a string into the Trie.
  /// In case-insensitive mode the lookup key is folded to lowercase but the
  /// stored `value` keeps the original casing.
  func insert(_ word: String) {
    var current = root
    for char in fold(word) {
      if current.children[char] == nil {
        current.children[char] = TrieNode()
      }
      current = current.children[char]!
    }
    current.isEndOfWord = true
    current.value = word
  }

  /// Find the longest prefix of `text` that exists in the Trie.
  /// Returns the matched word with its **original casing** (not folded).
  func findLongestPrefix(in text: String) -> String? {
    var current = root
    var longestMatch: String?

    for char in fold(text) {
      if let nextNode = current.children[char] {
        current = nextNode
        if current.isEndOfWord {
          longestMatch = current.value
        }
      } else {
        break
      }
    }
    return longestMatch
  }

  /// Exact-match lookup. Returns true if `word` was previously inserted.
  func contains(_ word: String) -> Bool {
    var current = root
    for char in fold(word) {
      guard let next = current.children[char] else { return false }
      current = next
    }
    return current.isEndOfWord
  }

  // MARK: - Internal

  /// Apply case folding when the trie is case-insensitive. We fold the entire
  /// string in one pass so that mappings like "İ" → "i̇" (multi-character
  /// lowercasing) produce a deterministic sequence of characters.
  private func fold(_ s: String) -> [Character] {
    caseInsensitive ? Array(s.lowercased()) : Array(s)
  }
}
