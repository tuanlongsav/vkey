//
//  AutoCapitalizer.swift
//  vkey
//
//  Máy trạng thái tự viết hoa đầu câu (sau Enter hoặc sau `. ! ?` kèm Space).
//

import Foundation

struct AutoCapitalizer {
  /// `. ! ?` vừa commit, chưa có Space — chờ promote sang `pendingCapitalize`.
  private(set) var sentenceJustEnded = false
  /// Đầu câu thật (sau Enter, hoặc `. ! ?` rồi Space).
  private(set) var pendingCapitalize = false

  /// Chỉ `. ! ?` đánh dấu kết thúc câu; dấu câu khác (`, ; :`…) không trigger.
  private static let sentenceEndingChars: Set<Character> = [".", "!", "?"]

  /// Mọi thao tác di chuyển con trỏ / gián đoạn (click chuột, mũi tên, Home/End,
  /// Escape, tổ hợp Cmd/Ctrl/Alt, đổi app) làm mất ngữ cảnh đầu câu.
  mutating func reset() {
    pendingCapitalize = false
    sentenceJustEnded = false
  }

  mutating func handlePunctuation(_ char: Character) {
    if Self.sentenceEndingChars.contains(char) {
      sentenceJustEnded = true
      pendingCapitalize = false
    } else {
      sentenceJustEnded = false
      pendingCapitalize = false
    }
  }

  mutating func handleTaskKey(_ taskKey: TaskKey) {
    switch taskKey {
    case .Enter:
      pendingCapitalize = true
      sentenceJustEnded = false
    case .Space:
      if sentenceJustEnded {
        pendingCapitalize = true
        sentenceJustEnded = false
      } else if pendingCapitalize {
        // Space thừa sau đầu câu (vd ".  ") — giữ chờ chữ hoa kế tiếp.
        break
      } else {
        pendingCapitalize = false
      }
    default:
      break
    }
  }

  /// Nếu đang chờ viết hoa và `enabled`, biến chữ cái thường đầu tiên thành chữ hoa.
  mutating func transformIncomingChar(
    _ incomingChar: Character,
    enabled: Bool
  ) -> (char: Character, didAutoCapitalize: Bool) {
    var result = incomingChar
    var didAutoCapitalize = false

    if enabled, pendingCapitalize, result.isLetter, result.isLowercase {
      if let upperChar = String(result).uppercased().first {
        result = upperChar
      }
      pendingCapitalize = false
      sentenceJustEnded = false
      didAutoCapitalize = true
    } else if !result.isWhitespace {
      pendingCapitalize = false
      sentenceJustEnded = false
    }

    return (result, didAutoCapitalize)
  }
}
