//
//  TiengVietValidator.swift
//  vkey
//
//  Kiểm tra tính hợp lệ của âm tiết tiếng Việt
//

import Foundation
import Defaults

/// TiengVietValidator - Kiểm tra cấu trúc âm tiết tiếng Việt
///
/// Phát hiện khi đầu vào không thể tạo thành âm tiết tiếng Việt hợp lệ,
/// kích hoạt recovery về chuỗi gốc.
enum TiengVietValidator {

  // MARK: - Bảng phụ âm cuối hợp lệ

  /// Phụ âm cuối hợp lệ trong tiếng Việt
  /// Chỉ có các phụ âm này mới có thể xuất hiện ở cuối âm tiết
  static let ValidPhuAmCuoi: Set<String> = [
    "c", "ch", "m", "n", "ng", "nh", "p", "t", "k",
  ]

  // MARK: - Bảng phụ âm đầu hợp lệ
  static let ValidInitials: Set<String> = [
    "b", "c", "d", "đ", "g", "h", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "x",
    "ch", "gh", "gi", "kh", "kr", "ng", "nh", "ph", "qu", "th", "tr", "ngh"
  ]

  // MARK: - Bảng cặp nguyên âm hợp lệ (Inclusion Vowel Pairs)
  static let ValidVowelPairs: Set<String> = [
    "ai", "ao", "au", "ay",
    "ei", "eo", "eu",
    "ia", "ie", "iu",
    "oa", "oe", "oi",
    "ua", "ue", "ui", "uo", "uy", "uu",
    "ye",
    "ou", "yu", "ya",
    // Telex intermediate states:
    "aa", "ee", "oo"
  ]

  // MARK: - Bảng kết hợp nguyên âm + phụ âm cuối hợp lệ
  
  /// Quy tắc kết hợp nguyên âm với phụ âm cuối theo ngữ âm học tiếng Việt
  ///
  /// Key: nguyên âm (chữ thường)
  /// Value: tập hợp phụ âm cuối hợp lệ
  ///
  /// Ghi chú: Hầu hết nguyên âm ghép (ai, ao, au, ay, âu, ây, eo, êu, oi, ôi, ơi, ui, ưi, ưu...)
  /// KHÔNG có phụ âm cuối - chúng là nhân âm tiết hoàn chỉnh.
  static let ValidVowelEndings: [String: Set<String>] = [
    // Nguyên âm đơn - có thể kết hợp với nhiều phụ âm cuối
    "a": ["c", "ch", "m", "n", "ng", "nh", "p", "t", "k"],
    "ă": ["c", "m", "n", "ng", "p", "t", "k"],
    "â": ["c", "m", "n", "ng", "p", "t"],
    "e": ["c", "m", "n", "p", "t"],
    "ê": ["c", "ch", "m", "n", "nh", "p", "t"],
    "i": ["c", "ch", "m", "n", "nh", "p", "t"],
    "o": ["c", "m", "n", "ng", "p", "t"],
    "ô": ["c", "m", "n", "ng", "p", "t"],
    "ơ": ["m", "n", "p", "t"],
    "u": ["c", "m", "n", "ng", "p", "t"],
    "ư": ["c", "m", "n", "ng", "p", "t", "k"],
    "y": ["c", "ch", "m", "n", "nh", "p", "t"],

    // Nguyên âm ghép CÓ THỂ có phụ âm cuối
    // iê/ie - tiếng, biết, kiếm, điện...
    "iê": ["c", "m", "n", "ng", "p", "t"],
    "ie": ["c", "m", "n", "ng", "p", "t"],

    // uô - cuốc, muốn, buồng...
    "uô": ["c", "m", "n", "ng", "p", "t"],
    "uo": ["c", "m", "n", "ng", "p", "t"],

    // ươ - lướt, mượn, hương...
    "ươ": ["c", "m", "n", "ng", "p", "t", "k"],

    // oa - hoạch, toàn, khoang, loan...
    "oa": ["c", "ch", "m", "n", "ng", "nh", "p", "t"],

    // oă - xoắn, loắt...
    "oă": ["c", "m", "n", "ng", "p", "t"],

    // uâ - luật, xuân...
    "uâ": ["n", "t"],

    // uê - huệch, tuềnh... (hiếm)
    "uê": ["c", "ch", "n", "nh"],

    // uy - huynh, quýt...
    "uy": ["c", "ch", "n", "nh", "p", "t"],

    // uyê - khuyên, duyệt...
    "uyê": ["n", "t"],
    "uye": ["n", "t"],

    // yê - yến, yêm...
    "yê": ["m", "n", "p", "t"],
    "ye": ["m", "n", "p", "t"],

    // Nguyên âm ghép KHÔNG có phụ âm cuối (tập rỗng)
    // Đây là các nhân âm tiết hoàn chỉnh
    "ai": [],
    "ao": [],
    "au": [],
    "ay": [],
    "âu": [],
    "ây": [],
    "eo": [],
    "êu": [],
    "ia": [],
    "iu": [],
    "oi": [],
    "ôi": [],
    "ơi": [],
    "ua": [],
    "uya": [],
    "uơ": [],
    "ui": [],
    "ưa": [],
    "ưi": [],
    "ươi": [],
    "ưu": [],
  ]

  /// Tổ hợp nguyên âm không tồn tại trong tiếng Việt
  /// Các chuỗi này cần recovery ngay lập tức
  static let InvalidVowelCombinations: Set<String> = [
    "ae", "ea", "ey", "iy", "yi", "yo", "yu",
  ]

  // MARK: - Phương thức kiểm tra

  /// Kiểm tra âm tiết có cần recovery không (không hợp lệ tiếng Việt)
  /// - Parameters:
  ///   - thanhPhan: Các thành phần âm tiết đã phân tích
  ///   - dauMu: Dấu mũ hiện tại (mũ, móc, trăng)
  /// - Returns: true nếu âm tiết không hợp lệ và cần recovery
  static func needsRecovery(_ thanhPhan: ThanhPhanTieng, dauMu: DauMu = .khongMu) -> Bool {
    // Rule 2: Valid Initial
    if !thanhPhan.phuAmDau.isEmpty {
      let initial = String(thanhPhan.phuAmDau).lowercased()
      var validInitials = ValidInitials
      if Defaults[.allowedZWJF] {
        validInitials.formUnion(["z", "w", "j", "f"])
      }
      if !validInitials.contains(initial) {
        return true
      }
    }

    // Rule 3: All Chars Parsed (conLai must be empty, with typo correction exceptions)
    if !thanhPhan.conLai.isEmpty {
      // Allow a transient trailing "g" after a vowel so the next "n" can be
      // corrected from the common "gn" typo into the valid final "ng".
      if thanhPhan.conLai.count == 1,
        thanhPhan.conLai[0].lowercased() == "g",
        !thanhPhan.nguyenAm.isEmpty,
        thanhPhan.phuAmCuoi.isEmpty
      {
        return false
      }

      // Allow a transient trailing tone mark key so it can be corrected when subsequent vowels are typed
      if Defaults[.autoTypoCorrection],
         thanhPhan.nguyenAm.isEmpty,
         thanhPhan.conLai.count == 1,
         let firstConLai = thanhPhan.conLai.first {
        let lower = firstConLai.lowercased().first!
        let telexTones: Set<Character> = ["s", "f", "r", "x", "j"]
        let vniTones: Set<Character> = ["1", "2", "3", "4", "5"]
        if telexTones.contains(lower) || vniTones.contains(lower) {
          return false
        }
      }

      return true
    }

    // Rule 4: Spelling Rules
    if !thanhPhan.phuAmDau.isEmpty && !thanhPhan.nguyenAm.isEmpty {
      let initial = String(thanhPhan.phuAmDau).lowercased()
      let firstVowel = String(thanhPhan.nguyenAm.first!).lowercased()
      if initial == "c" && ["e", "i", "y"].contains(firstVowel) { return true }
      if initial == "k" && ["a", "o", "u"].contains(firstVowel) { return true }
      if initial == "g" && firstVowel == "e" { return true }
      if initial == "ng" && ["e", "i"].contains(firstVowel) { return true }
      if initial == "gh" && ["a", "o", "u"].contains(firstVowel) { return true }
      if initial == "ngh" && ["a", "o", "u"].contains(firstVowel) { return true }
    }

    // Rule 5: Valid Final Consonant & Vowel Ending Combination
    if !thanhPhan.phuAmCuoi.isEmpty {
      let phuAmCuoi = String(thanhPhan.phuAmCuoi).lowercased()

      // Kiểm tra phụ âm cuối có hợp lệ không
      if !ValidPhuAmCuoi.contains(phuAmCuoi) {
        return true
      }

      // Kiểm tra kết hợp nguyên âm + phụ âm cuối
      let nguyenAm = String(thanhPhan.nguyenAm).lowercased()
      if !isValidVowelEnding(nguyenAm: nguyenAm, phuAmCuoi: phuAmCuoi, dauMu: dauMu) {
        return true
      }
    }

    // Rule 6: Valid Vowel Pattern (Inclusion Vowel Pairs)
    if thanhPhan.nguyenAm.count > 1 {
      let vowelStr = String(thanhPhan.nguyenAm).lowercased()
      let vowelChars = Array(vowelStr)
      for i in 0..<(vowelChars.count - 1) {
        let pair = String(vowelChars[i...(i+1)])
        if !ValidVowelPairs.contains(pair) {
          return true
        }
      }
    }

    // Trường hợp bổ sung: Tổ hợp nguyên âm không hợp lệ
    let nguyenAm = String(thanhPhan.nguyenAm).lowercased()
    if InvalidVowelCombinations.contains(nguyenAm) {
      return true
    }

    return false
  }

  // MARK: - Phương thức nội bộ

  /// Kiểm tra kết hợp nguyên âm + phụ âm cuối có hợp lệ không
  /// - Parameters:
  ///   - nguyenAm: Nguyên âm (chữ thường, dạng gốc chưa có dấu)
  ///   - phuAmCuoi: Phụ âm cuối (chữ thường)
  ///   - dauMu: Dấu mũ đang áp dụng
  /// - Returns: true nếu kết hợp hợp lệ
  private static func isValidVowelEnding(
    nguyenAm: String,
    phuAmCuoi: String,
    dauMu: DauMu
  ) -> Bool {
    // Biến đổi nguyên âm với dấu mũ để kiểm tra nguyên âm thực tế
    // Quan trọng vì một số nguyên âm gốc (như "ua") không có phụ âm cuối,
    // nhưng dạng biến đổi (như "uâ") lại có thể kết hợp.
    let transformedVowel = transformVowelWithMu(nguyenAm: nguyenAm, dauMu: dauMu)

    // Kiểm tra nguyên âm đã biến đổi trước
    if let validEndings = ValidVowelEndings[transformedVowel] {
      return validEndings.contains(phuAmCuoi)
    }

    // Nếu không có quy tắc cho nguyên âm đã biến đổi, kiểm tra nguyên âm gốc
    if let validEndings = ValidVowelEndings[nguyenAm] {
      return validEndings.contains(phuAmCuoi)
    }

    // Với nguyên âm không có trong bảng, cho phép tất cả phụ âm cuối chuẩn
    // Đây là cách tiếp cận an toàn - tốt hơn là cho phép thay vì từ chối sai
    return ValidPhuAmCuoi.contains(phuAmCuoi)
  }

  /// Biến đổi nguyên âm gốc thành dạng có dấu mũ
  /// - Parameters:
  ///   - nguyenAm: Nguyên âm gốc (chữ thường)
  ///   - dauMu: Dấu mũ cần áp dụng
  /// - Returns: Nguyên âm đã biến đổi
  private static func transformVowelWithMu(nguyenAm: String, dauMu: DauMu) -> String {
    switch dauMu {
    case .khongMu:
      return nguyenAm
    case .muUp:  // Mũ: a→â, e→ê, o→ô
      var result = nguyenAm
      result = result.replacingOccurrences(of: "a", with: "â")
      result = result.replacingOccurrences(of: "e", with: "ê")
      result = result.replacingOccurrences(of: "o", with: "ô")
      return result
    case .muMoc:  // Móc: o→ơ, u→ư
      var result = nguyenAm
      result = result.replacingOccurrences(of: "o", with: "ơ")
      result = result.replacingOccurrences(of: "u", with: "ư")
      return result
    case .muNgua:  // Trăng: a→ă
      return nguyenAm.replacingOccurrences(of: "a", with: "ă")
    }
  }
}
