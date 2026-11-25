//
//  TextDiff.swift
//  vkey
//
//  Thuật toán tính diff NFC/NFD và lùi con trỏ UTF-16 (thuần Foundation).
//

import Foundation

enum TextDiff {
  /// Diff theo cụm grapheme (NFC): dùng cho field lưu NFC và xoá theo grapheme
  /// (Apple native, Office native, native editors, trình duyệt).
  static func calcKeyStrokes(from: String, to: String) -> (Int, [Character]) {
    let fromChars = Array(from)
    let toChars = Array(to)
    var commonPrefixLength = 0
    let minLength = min(fromChars.count, toChars.count)

    while commonPrefixLength < minLength
      && fromChars[commonPrefixLength] == toChars[commonPrefixLength]
    {
      commonPrefixLength += 1
    }

    let backspaceCount = fromChars.count - commonPrefixLength
    let diffChars = Array(toChars.dropFirst(commonPrefixLength))

    return (backspaceCount, diffChars)
  }

  /// v2.3.8: NFD scalar-aware diff cho field lưu văn bản dạng decomposed (NFD)
  /// và xoá từng scalar.
  static func calcKeyStrokesNFD(from: String, to: String) -> (Int, [Character]) {
    let fromNFD = from.decomposedStringWithCanonicalMapping
    let toNFD = to.decomposedStringWithCanonicalMapping
    let fromScalars = Array(fromNFD.unicodeScalars)
    let toScalars = Array(toNFD.unicodeScalars)
    var commonPrefixLength = 0
    let minLength = min(fromScalars.count, toScalars.count)
    while commonPrefixLength < minLength
      && fromScalars[commonPrefixLength] == toScalars[commonPrefixLength]
    {
      commonPrefixLength += 1
    }

    // v3.6: KHÔNG BAO GIỜ gửi combining mark "trần" mở đầu diff. Nếu phần
    // retype bắt đầu bằng dấu rời (ccc != 0), lùi ranh giới prefix về đầu cụm
    // grapheme để xoá nguyên cụm và retype cụm hoàn chỉnh.
    func isCombining(_ s: Unicode.Scalar) -> Bool {
      s.properties.canonicalCombiningClass != .notReordered
    }
    if commonPrefixLength < toScalars.count && isCombining(toScalars[commonPrefixLength]) {
      while commonPrefixLength > 0 {
        let splitsFrom = commonPrefixLength < fromScalars.count
          && isCombining(fromScalars[commonPrefixLength])
        let splitsTo = commonPrefixLength < toScalars.count
          && isCombining(toScalars[commonPrefixLength])
        if splitsFrom || splitsTo {
          commonPrefixLength -= 1
        } else {
          break
        }
      }
    }

    let backspaceCount = fromScalars.count - commonPrefixLength
    var remainingScalars = String.UnicodeScalarView()
    for s in toScalars.dropFirst(commonPrefixLength) {
      remainingScalars.append(s)
    }
    return (backspaceCount, Array(String(remainingScalars)))
  }

  /// Chọn trục diff theo dạng lưu của field — grapheme (`calcKeyStrokes`) cho
  /// field NFC, scalar NFD (`calcKeyStrokesNFD`) cho field NFD.
  static func calcKeyStrokes(from: String, to: String, usesNFC: Bool) -> (Int, [Character]) {
    usesNFC
      ? calcKeyStrokes(from: from, to: to)
      : calcKeyStrokesNFD(from: from, to: to)
  }

  /// v4.15: dạng ký tự THỰC SỰ phát ra, bám theo dạng lưu của field.
  /// - Field NFC → precompose (gộp combining mark vào base).
  /// - Field NFD → giữ nguyên combining mark để khớp số backspace đã đếm.
  static func emittedCharacters(_ diffChars: [Character], normalizeToNFC: Bool) -> [Character] {
    guard normalizeToNFC else { return diffChars }
    return Array(String(diffChars).precomposedStringWithCanonicalMapping)
  }

  /// Lùi từ caret `backspaceCount` đơn vị xoá trong không gian UTF-16.
  /// - `usesNFC == true` → mỗi cụm grapheme là 1 đơn vị.
  /// - `usesNFC == false` → mỗi Unicode scalar là 1 đơn vị (giữ nguyên surrogate pair).
  static func axDeleteStart(
    _ value: String, caretUTF16: Int, backspaceCount: Int, usesNFC: Bool
  ) -> Int {
    guard backspaceCount > 0, caretUTF16 > 0 else { return max(0, caretUTF16) }
    let ns = value as NSString
    var idx = min(caretUTF16, ns.length)
    for _ in 0..<backspaceCount {
      guard idx > 0 else { break }
      if usesNFC {
        idx = ns.rangeOfComposedCharacterSequence(at: idx - 1).location
      } else {
        idx -= 1
        if idx > 0,
          UTF16.isTrailSurrogate(ns.character(at: idx)),
          UTF16.isLeadSurrogate(ns.character(at: idx - 1))
        {
          idx -= 1
        }
      }
    }
    return idx
  }
}
