//
//  MacroExpander.swift
//  vkey
//
//  Tra cứu macro, khớp biến thể hoa chữ đầu (auto-capitalize) và bảo toàn kiểu chữ.
//

import Defaults
import Foundation

enum MacroExpander {
  /// Bảng macro đã giải mã (tránh giải mã JSON lại ở mọi phím kết từ).
  private static let macrosCache = DefaultsDerivedCache<[Macro]>(.macros) {
    Defaults[.macros]
  }

  static var cachedMacros: [Macro] {
    macrosCache.value
  }

  /// Tra macro khớp CHÍNH XÁC từ hiện tại, rồi tới đúng một biến thể bị
  /// auto-capitalize viết hoa chữ đầu (KHÔNG khớp ALL-CAPS có chủ ý).
  static func macroTarget(
    for current: String,
    endingChar: Character,
    macros: [Macro]
  ) -> String? {
    guard !current.isEmpty else { return nil }
    let usable = macros.filter { !$0.from.isEmpty && !$0.to.isEmpty }

    if let macro = usable.first(where: { $0.from == current }) {
      return macro.to + String(endingChar)
    }

    guard
      let macro = usable.first(where: { Self.autoCapitalizedVariant(of: $0.from) == current })
    else {
      return nil
    }
    return matchCase(of: current, to: macro.to) + String(endingChar)
  }

  /// Chuỗi mà auto-capitalize tạo ra từ một trigger: viết hoa ĐÚNG chữ cái đầu.
  static func autoCapitalizedVariant(of trigger: String) -> String? {
    guard let first = trigger.first, first.isLowercase else { return nil }
    return String(first).uppercased() + trigger.dropFirst()
  }

  /// Diff thay từ trigger bằng phần macro bung ra dùng chung `TextDiff`.
  static func macroReplacement(
    for current: String,
    endingChar: Character,
    macros: [Macro],
    usesNFC: Bool
  ) -> (backspaceCount: Int, diffChars: [Character])? {
    guard
      let target = macroTarget(for: current, endingChar: endingChar, macros: macros)
    else {
      return nil
    }
    return TextDiff.calcKeyStrokes(from: current, to: target, usesNFC: usesNFC)
  }

  static func commitReplacementTarget(
    word: String,
    endingChar: Character,
    includeEndingChar: Bool
  ) -> String {
    includeEndingChar ? word + String(endingChar) : word
  }

  /// 4.12: áp kiểu hoa/thường của từ user gõ lên từ thay thế.
  static func matchCase(of source: String, to replacement: String) -> String {
    guard source.first(where: { $0.isLetter })?.isUppercase == true else {
      return replacement
    }
    let letters = source.filter { $0.isLetter }
    if letters.count > 1, letters.allSatisfy({ $0.isUppercase }) {
      return replacement.uppercased()
    }
    guard let first = replacement.first else { return replacement }
    return String(first).uppercased() + replacement.dropFirst()
  }
}
