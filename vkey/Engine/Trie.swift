//
//  Trie.swift
//  vkey
//
//  Data structure for fast prefix matching.
//
//  Supports an optional case-insensitive mode: when enabled, all inserts and
//  lookups are normalised to lowercase. `longestPrefixLength(in:)` returns the
//  matched prefix length on the original input string so callers can slice
//  `text.prefix(length)` while preserving the user's exact casing.
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
  /// Returns the matched word with the stored casing from `insert(_:)`.
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

  /// Find the character count of the longest prefix of `text` that exists in the Trie.
  /// Preserves input indexing so callers can slice `text.prefix(len)` with exact input casing.
  func longestPrefixLength(in text: String) -> Int {
    var current = root
    var longestLen = 0
    var index = 0

    for ch in text {
      index += 1
      if caseInsensitive {
        var matchedAll = true
        for foldedChar in ch.lowercased() {
          if let nextNode = current.children[foldedChar] {
            current = nextNode
          } else {
            matchedAll = false
            break
          }
        }
        guard matchedAll else { break }
      } else {
        guard let nextNode = current.children[ch] else { break }
        current = nextNode
      }
      if current.isEndOfWord {
        longestLen = index
      }
    }
    return longestLen
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

  private func fold(_ s: String) -> [Character] {
    caseInsensitive ? Array(s.lowercased()) : Array(s)
  }
}
