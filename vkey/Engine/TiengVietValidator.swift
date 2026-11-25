//
//  TiengVietValidator.swift
//  vkey
//
//  Kiểm tra tính hợp lệ của âm tiết tiếng Việt
//

import Foundation

/// TiengVietValidator - Kiểm tra cấu trúc âm tiết tiếng Việt (pure Foundation).
enum TiengVietValidator {

  // MARK: - Bảng phụ âm hợp lệ

  static let ValidPhuAmCuoi: Set<String> = Set(TiengViet.PhuAmCuoi)

  static let ValidInitials: Set<String> = Set(TiengViet.PhuAmDon + TiengViet.PhuAmGhep + ["đ"])

  private static let ValidInitialsWithZWJF: Set<String> =
    ValidInitials.union(TiengViet.PhuAmDonNuocNgoai)

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
    "aa", "ee", "oo",
  ]

  // MARK: - Bảng kết hợp nguyên âm + phụ âm cuối hợp lệ

  static let ValidVowelEndings: [String: Set<String>] = [
    // Nguyên âm đơn
    "a": ["c", "ch", "m", "n", "ng", "nh", "p", "t", "k"],
    "ă": ["c", "m", "n", "ng", "p", "t", "k"],
    "â": ["c", "m", "n", "ng", "p", "t"],
    "e": ["c", "m", "n", "ng", "p", "t"],
    "ê": ["c", "ch", "m", "n", "nh", "p", "t"],
    "i": ["c", "ch", "m", "n", "nh", "p", "t"],
    "o": ["c", "m", "n", "ng", "p", "t"],
    "ô": ["c", "m", "n", "ng", "p", "t"],
    "ơ": ["m", "n", "p", "t"],
    "u": ["c", "m", "n", "ng", "p", "t"],
    "ư": ["c", "m", "n", "ng", "p", "t", "k"],
    "y": ["c", "ch", "m", "n", "nh", "p", "t"],

    // Nguyên âm ghép CÓ THỂ có phụ âm cuối
    "iê": ["c", "m", "n", "ng", "p", "t"],
    "ie": ["c", "m", "n", "ng", "p", "t"],
    "uô": ["c", "m", "n", "ng", "p", "t"],
    "uo": ["c", "m", "n", "ng", "p", "t"],
    "ươ": ["c", "m", "n", "ng", "p", "t", "k"],
    "oa": ["c", "ch", "m", "n", "ng", "nh", "p", "t"],
    "oă": ["c", "m", "n", "ng", "p", "t"],
    "uâ": ["n", "ng", "t"],
    "uê": ["c", "ch", "n", "nh"],
    "uy": ["c", "ch", "n", "nh", "p", "t"],
    "uyê": ["n", "t"],
    "uye": ["n", "t"],
    "yê": ["m", "n", "ng", "p", "t"],
    "ye": ["m", "n", "ng", "p", "t"],

    // Nguyên âm ghép KHÔNG có phụ âm cuối
    "ai": [], "ao": [], "au": [], "ay": [], "âu": [], "ây": [],
    "eo": [], "êu": [], "ia": [], "iu": [], "oi": [], "ôi": [], "ơi": [],
    "ua": [], "uya": [], "uơ": [], "ui": [], "ưa": [], "ưi": [], "ươi": [], "ưu": [],
  ]

  /// Nhân âm tiết (≥ 2 nguyên âm) hợp lệ SAU khi đã đặt dấu mũ/móc/trăng.
  static let NhanCoDauMuHopLe: Set<String> = [
    "iê", "yê", "uô", "uâ", "uê", "uyê", "âu", "ây", "ôi", "êu",
    "uôi", "iêu", "yêu", "uây",
    "ươ", "uơ", "ươi", "ươu", "ưa", "ưi", "ưu", "ơi",
    "oă",
  ]

  static let InvalidVowelCombinations: Set<String> = [
    "ae", "ea", "ey", "iy", "yi", "yo", "yu",
  ]

  // MARK: - Phụ âm cuối tắc (thanh nhập)

  static let PhuAmCuoiTac: Set<String> = ["c", "ch", "p", "t", "k"]
  static let ThanhKhongDiVoiAmTac: Set<DauThanh> = [.huyen, .hoi, .nga]

  // MARK: - Phương thức kiểm tra

  static func needsRecovery(
    _ thanhPhan: ThanhPhanTieng,
    dauMu: DauMu = .khongMu,
    dauThanh: DauThanh = .bang,
    options: EngineOptions = .default
  ) -> Bool {
    // Rule 2: Valid Initial
    if !thanhPhan.phuAmDau.isEmpty {
      let initial = String(thanhPhan.phuAmDau).lowercased()
      let allowed = options.allowedZWJF ? ValidInitialsWithZWJF : ValidInitials
      if !allowed.contains(initial) {
        return true
      }
    }

    // Rule 3: All Chars Parsed (conLai must be empty, with typo correction exceptions)
    if !thanhPhan.conLai.isEmpty {
      // Transient trailing "g" so the next "n" can correct "gn" -> "ng".
      if thanhPhan.conLai.count == 1,
         thanhPhan.conLai[0].lowercased() == "g",
         !thanhPhan.nguyenAm.isEmpty,
         thanhPhan.phuAmCuoi.isEmpty
      {
        return false
      }

      // Kéo dài nguyên âm kiểu chat sau khi âm tiết đã mang dấu mũ/móc ("chưaaa").
      if thanhPhan.phuAmCuoi.isEmpty,
         dauMu != .khongMu,
         let nguyenAmCuoi = thanhPhan.nguyenAm.last?.lowercased(),
         thanhPhan.conLai.allSatisfy({ $0.lowercased() == nguyenAmCuoi })
      {
        return false
      }

      // Transient trailing tone mark key when autoTypoCorrection is on.
      if options.autoTypoCorrection,
         thanhPhan.nguyenAm.isEmpty,
         thanhPhan.conLai.count == 1,
         let firstConLai = thanhPhan.conLai.first {
        let lower = firstConLai.lowercased().first!
        if TiengViet.TelexToneKeys[lower] != nil || TiengViet.VNIToneKeys[lower] != nil {
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

      if !ValidPhuAmCuoi.contains(phuAmCuoi) {
        return true
      }

      if !isValidVowelEnding(thanhPhan: thanhPhan, phuAmCuoi: phuAmCuoi, dauMu: dauMu) {
        return true
      }

      // Rule 5b (thanh nhập)
      if viPhamThanhNhap(thanhPhan, dauThanh: dauThanh) {
        return true
      }
    }

    // Rule 5c: không có vần ăi/ăo/ău/ăy
    if dauMu == .muNgua, thanhPhan.nguyenAm.count > 1,
       let nguyenAmDau = thanhPhan.nguyenAm.first,
       String(nguyenAmDau).lowercased() == "a"
    {
      if !dangChoPhuAmCuoiDeDaoAO(thanhPhan, dauMu: dauMu) {
        return true
      }
    }

    // Rule 6: Valid Vowel Pattern (Inclusion Vowel Pairs)
    if thanhPhan.nguyenAm.count > 1 {
      let vowelChars = Array(String(thanhPhan.nguyenAm).lowercased())
      for i in 0..<(vowelChars.count - 1) {
        let pair = String(vowelChars[i...(i + 1)])
        if !ValidVowelPairs.contains(pair) {
          return true
        }
      }
    }

    let nguyenAm = String(thanhPhan.nguyenAm).lowercased()
    if InvalidVowelCombinations.contains(nguyenAm) {
      return true
    }

    // Rule 7: nhân âm tiết SAU khi áp dấu mũ phải là vần có thật.
    if dauMu != .khongMu, thanhPhan.nguyenAm.count >= 2,
       !dangChoPhuAmCuoiDeDaoAO(thanhPhan, dauMu: dauMu)
    {
      let nhan = TiengVietTransformer
        .nhanSauDauMu(thanhPhanTieng: thanhPhan, dauMu: dauMu)
        .lowercased()
      if !NhanCoDauMuHopLe.contains(nhan) {
        return true
      }
    }

    return false
  }

  /// Trạng thái trung gian "ao" + dấu trăng, chưa có phụ âm cuối (dùng chung cho Rule 5c & 7).
  private static func dangChoPhuAmCuoiDeDaoAO(
    _ thanhPhan: ThanhPhanTieng, dauMu: DauMu
  ) -> Bool {
    dauMu == .muNgua
      && thanhPhan.phuAmCuoi.isEmpty
      && String(thanhPhan.nguyenAm).lowercased() == "ao"
  }

  /// Luật thanh nhập (Rule 5b).
  static func viPhamThanhNhap(_ thanhPhan: ThanhPhanTieng, dauThanh: DauThanh) -> Bool {
    guard !thanhPhan.phuAmCuoi.isEmpty else { return false }
    let phuAmCuoi = String(thanhPhan.phuAmCuoi).lowercased()
    return PhuAmCuoiTac.contains(phuAmCuoi) && ThanhKhongDiVoiAmTac.contains(dauThanh)
  }

  // MARK: - Phương thức nội bộ

  private static func isValidVowelEnding(
    thanhPhan: ThanhPhanTieng,
    phuAmCuoi: String,
    dauMu: DauMu
  ) -> Bool {
    let nguyenAm = String(thanhPhan.nguyenAm).lowercased()
    let transformedVowel = dauMu == .khongMu
      ? nguyenAm
      : TiengVietTransformer.nhanSauDauMu(thanhPhanTieng: thanhPhan, dauMu: dauMu).lowercased()

    if let validEndings = ValidVowelEndings[transformedVowel] {
      return validEndings.contains(phuAmCuoi)
    }

    if let validEndings = ValidVowelEndings[nguyenAm] {
      return validEndings.contains(phuAmCuoi)
    }

    return ValidPhuAmCuoi.contains(phuAmCuoi)
  }
}
