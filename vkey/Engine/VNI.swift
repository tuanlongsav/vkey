//
//  VNI.swift
//  vkey
//
//  Created by KhanhIceTea on 17/02/2024.
//

import Foundation

/// VNI - Kiểu gõ tiếng Việt sử dụng phím số (1–5 dấu thanh, 6 mũ, 7 móc, 8 trăng, 9 đ).
class VNI: TypingMethod {

  private static let dTriggerChars: Set<Character> = ["9"]
  private static let simpleCancelSuffixes = ["11", "22", "33", "44", "55", "77", "88"]

  // MARK: - TypingMethod Protocol

  public func shouldStopProcessing(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()

    if Self.simpleCancelSuffixes.contains(where: { lowerKeyStr.hasSuffix($0) }) {
      return true
    }

    if lowerKeyStr.hasSuffix("66") {
      let prefix = lowerKeyStr.dropLast(2)
      return prefix.contains("a") || prefix.contains("e") || prefix.contains("o")
    }

    if lowerKeyStr.hasSuffix("99") {
      return lowerKeyStr.dropLast(2).hasPrefix("d")
    }

    return false
  }

  public func push(
    char: Character,
    state: TiengVietState,
    options: EngineOptions
  ) -> (state: TiengVietState, appliedMark: Bool) {
    if let common = tryCommonPushPrefix(
      char: char, state: state, dTriggerChars: Self.dTriggerChars, options: options
    ) {
      return common
    }

    let thanhPhan = state.thanhPhanTieng

    if !thanhPhan.nguyenAm.isEmpty {
      if let tone = TiengViet.VNIToneKeys[char] {
        return (state.withTone(tone), true)
      }

      switch char {
      case "6":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A", "o", "O", "e", "E"]) {
          return (state.withMu(.muUp), true)
        }

      case "7":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["u", "o", "U", "O"]) {
          if let giuNguyen = state.giuMuMocTrenUO() {
            return (giuNguyen, true)
          }
          return (state.withMu(.muMoc), true)
        }

      case "8":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          return (state.withMu(.muNgua), true)
        }

      default:
        break
      }
    }

    return (state.push(char, options: options), false)
  }
}
