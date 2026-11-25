//
//  Telex.swift
//  vkey
//
//  Created by KhanhIceTea on 17/02/2024.
//

import Foundation

/// Telex - Kiểu gõ tiếng Việt (s/f/r/x/j dấu thanh, aa/ee/oo/aw/ow/uw/w dấu mũ, dd → đ).
class Telex: TypingMethod {

  private static let dTriggerChars: Set<Character> = ["d", "D"]
  private static let simpleCancelSuffixes = ["ss", "ff", "rr", "xx", "jj", "ww"]

  // MARK: - TypingMethod Protocol

  public func shouldStopProcessing(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()

    if Self.simpleCancelSuffixes.contains(where: { lowerKeyStr.hasSuffix($0) }) {
      return true
    }

    if let lastChar = lowerKeyStr.last, lastChar.isNumber {
      return true
    }

    // "aa", "oo", "ee", "dd" -> Cancel mark if the character exists before
    if lowerKeyStr.hasSuffix("aa") { return lowerKeyStr.dropLast(2).contains("a") }
    if lowerKeyStr.hasSuffix("oo") { return lowerKeyStr.dropLast(2).contains("o") }
    if lowerKeyStr.hasSuffix("ee") { return lowerKeyStr.dropLast(2).contains("e") }
    if lowerKeyStr.hasSuffix("dd") { return lowerKeyStr.dropLast(2).hasPrefix("d") }

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
      if let lower = char.lowercased().first, let tone = TiengViet.TelexToneKeys[lower] {
        return (state.withTone(tone), true)
      }

      switch char {
      // Phím dấu mũ: aa=â, ee=ê, oo=ô (gõ đúp nguyên âm)
      case "a", "o", "e", "A", "O", "E":
        let chuThuong = Character(char.lowercased())
        let chuHoa = Character(char.uppercased())
        let dangDungNguyenAmBa = state.chuKhongDau.last.map { lienTruoc in
          lienTruoc != chuThuong && lienTruoc != chuHoa
            && (lienTruoc.lowercased().first.map { TiengViet.NguyenAmDonSet.contains($0) } ?? false)
            && TiengViet.NguyenAmHopLeSet.contains(
              String(thanhPhan.nguyenAm + [chuThuong]).lowercased())
        } ?? false

        // Bất đối xứng hoa/thường có chủ ý: phím thường khớp cả hoa/thường ("Aa"→"Â"),
        // phím hoa chỉ khớp hoa ("aA" giữ nguyên camelCase).
        let khopHoaThuong: [Character] = char.isUppercase ? [chuHoa] : [chuThuong, chuHoa]
        if !dangDungNguyenAmBa,
           thanhPhan.nguyenAmChua1KyTu(mangKyTu: khopHoaThuong)
        {
          let daCoMuHoacMoc = state.dauMu != .khongMu && state.dauMu != .muUp
          let goDoiLienKe = state.chuKhongDau.last == chuThuong
            || state.chuKhongDau.last == chuHoa
          let chuGhepDoiGoSauPhimThanh = state.chuKhongDau.count > state.viTriGoDauThanh
          let daCoThanhChanMu = state.dauThanh != .bang
            && !(goDoiLienKe && chuGhepDoiGoSauPhimThanh)

          if !daCoMuHoacMoc, !daCoThanhChanMu {
            return (state.withMu(.muUp), true)
          }
        }

      // Phím w: dấu móc (ơ, ư) hoặc dấu trăng (ă)
      case "w", "W":
        if state.nguyenAmTuSinhTuW {
          break
        }
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["u", "U"]) {
          if let giuNguyen = state.giuMuMocTrenUO() {
            return (giuNguyen, true)
          }
          return (state.withMu(.muMoc), true)
        } else if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          return (state.withMu(.muNgua), true)
        } else if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["o", "O"]) {
          return (state.withMu(.muMoc), true)
        }

      default:
        break
      }
    }

    // Telex cổ điển khi allowedZWJF tắt: "w" đứng không → ư ("w"→ư, "tw"→tư).
    if (char == "w" || char == "W"),
       thanhPhan.nguyenAm.isEmpty,
       !options.allowedZWJF
    {
      let base: Character = (char == "W") ? "U" : "u"
      return (state.push(base, tuSinhTuW: true, options: options).withMu(.muMoc), true)
    }

    return (state.push(char, options: options), false)
  }
}
