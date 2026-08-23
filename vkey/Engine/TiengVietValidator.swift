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
    // "ng" bị thiếu ⇒ leng keng / xẻng / kẻng bị needsRecovery ném về phím thô.
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

    // uâ - luật, xuân, bâng khuâng ("ng" từng bị thiếu ⇒ "khuaang" không gõ được)
    "uâ": ["n", "ng", "t"],

    // uê - huệch, tuềnh... (hiếm)
    "uê": ["c", "ch", "n", "nh"],

    // uy - huynh, quýt...
    "uy": ["c", "ch", "n", "nh", "p", "t"],

    // uyê - khuyên, duyệt...
    "uyê": ["n", "t"],
    "uye": ["n", "t"],

    // yê - yến, yêm, yểng ("ng" từng bị thiếu ⇒ "yeengr" không gõ được)
    "yê": ["m", "n", "ng", "p", "t"],
    "ye": ["m", "n", "ng", "p", "t"],

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

  /// Nhân âm tiết (từ 2 nguyên âm trở lên) hợp lệ SAU khi đã đặt dấu mũ/móc/trăng
  /// — tức đúng chuỗi nguyên âm sắp hiện lên màn hình.
  ///
  /// Rule 5 chỉ chạy khi âm tiết CÓ phụ âm cuối và Rule 6 chỉ soi cụm nguyên âm
  /// GỐC (chưa mang mũ), nên không luật nào bắt được nhân bất khả sinh ra SAU khi
  /// áp mũ: "khoee" → "khôe", "hoaan" → "hoân", "tauw" → "taư", "cuwuc" → "cuưc"
  /// đều lọt validator và hiện ra màn hình dù ôe/oâ/aư/uư không tồn tại.
  ///
  /// Liệt kê theo VỊ TRÍ đặt mũ thật (xem `TiengVietTransformer.nhanSauDauMu`),
  /// nên "ưu" (mũ ở chữ u đầu) hợp lệ còn "uư" (mũ ở chữ u sau) thì không.
  static let NhanCoDauMuHopLe: Set<String> = [
    // Dấu mũ (^)
    "iê", "yê", "uô", "uâ", "uê", "uyê", "âu", "ây", "ôi", "êu",
    "uôi", "iêu", "yêu", "uây",
    // Dấu móc
    "ươ", "uơ", "ươi", "ươu", "ưa", "ưi", "ưu", "ơi",
    // Dấu trăng
    "oă",
  ]

  /// Tổ hợp nguyên âm không tồn tại trong tiếng Việt
  /// Các chuỗi này cần recovery ngay lập tức
  static let InvalidVowelCombinations: Set<String> = [
    "ae", "ea", "ey", "iy", "yi", "yo", "yu",
  ]

  // MARK: - Phụ âm cuối tắc (thanh nhập)

  /// Phụ âm tắc cuối âm tiết. Âm tiết kết bằng các phụ âm này mang **thanh nhập**
  /// — theo ngữ âm tiếng Việt chỉ nhận được sắc hoặc nặng, không bao giờ nhận
  /// huyền/hỏi/ngã ("ỏt", "òc", "ãch" không tồn tại).
  static let PhuAmCuoiTac: Set<String> = ["c", "ch", "p", "t", "k"]

  /// Dấu thanh KHÔNG thể đi với phụ âm cuối tắc.
  static let ThanhKhongDiVoiAmTac: Set<DauThanh> = [.huyen, .hoi, .nga]

  // MARK: - Phương thức kiểm tra

  /// Kiểm tra âm tiết có cần recovery không (không hợp lệ tiếng Việt)
  /// - Parameters:
  ///   - thanhPhan: Các thành phần âm tiết đã phân tích
  ///   - dauMu: Dấu mũ hiện tại (mũ, móc, trăng)
  ///   - dauThanh: Dấu thanh người dùng đã gõ (dùng cho luật thanh nhập)
  /// - Returns: true nếu âm tiết không hợp lệ và cần recovery
  static func needsRecovery(
    _ thanhPhan: ThanhPhanTieng,
    dauMu: DauMu = .khongMu,
    dauThanh: DauThanh = .bang
  ) -> Bool {
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

      // Kéo dài nguyên âm kiểu chat sau khi âm tiết đã mang DẤU MŨ/MÓC
      // ("chưaa", "chưaaa"): phần dư chỉ gồm chính nguyên âm cuối lặp lại, tức
      // vẫn là âm tiết hợp lệ cộng đuôi kéo dài — không phải input rác.
      // `transform` vốn nối `conLai` vào cuối nên hiển thị đúng ngay.
      //
      // Gate ở `dauMu` chứ KHÔNG ở `dauThanh`: chỉ dấu thanh thôi thì không đủ
      // để phân biệt. "wifi" có chuKhongDau "wii" (chữ f bị nuốt làm huyền) —
      // cấu trúc y hệt "quaa", nên nới theo dấu thanh sẽ biến "wifi" thành
      // "wìi". Ca chỉ-có-dấu-thanh vẫn đi recovery về phím thô như trước, và
      // dấu cũ không còn bị phá (xem Telex.push).
      if thanhPhan.phuAmCuoi.isEmpty,
        dauMu != .khongMu,
        let nguyenAmCuoi = thanhPhan.nguyenAm.last?.lowercased(),
        thanhPhan.conLai.allSatisfy({ $0.lowercased() == nguyenAmCuoi })
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

      // Rule 5b (thanh nhập) — xem `viPhamThanhNhap`.
      if viPhamThanhNhap(thanhPhan, dauThanh: dauThanh) {
        return true
      }
    }

    // Rule 5c: không có vần ăi/ăo/ău/ăy — "ă" chỉ đứng trước phụ âm cuối
    // (ăn, ắp) hoặc đứng SAU o (xoăn). "taiw" → "tăi" phải recovery về phím thô.
    if dauMu == .muNgua, thanhPhan.nguyenAm.count > 1,
      let nguyenAmDau = thanhPhan.nguyenAm.first,
      String(nguyenAmDau).lowercased() == "a"
    {
      // Các cặp còn lại (ai/au/ay) parser không bao giờ đảo nên bắn ngay là đúng.
      if !dangChoPhuAmCuoiDeDaoAO(thanhPhan, dauMu: dauMu) {
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

    // Rule 7: nhân âm tiết SAU khi áp dấu mũ phải là vần có thật. Rule 5 bỏ qua
    // âm tiết MỞ và Rule 6 chỉ soi cụm nguyên âm gốc, nên "khoee"/"hoaan"/"tauw"
    // lọt tới màn hình. Chỉ xét khi đã có mũ và nhân từ 2 nguyên âm trở lên —
    // nhân một nguyên âm mang mũ (â/ê/ô/ư/ơ/ă) luôn hợp lệ.
    //
    // Phải tôn trọng carve-out của Rule 5c, nếu không luật này bắn đúng vào
    // trạng thái trung gian mà Rule 5c cố ý tha ("ăo" mở): nhân là "ăo" — không
    // có trong bảng — nên thứ tự gõ đảo a/o ("haowcj" → hoặc, "chaowts" → choắt,
    // "ngaowcj" → ngoặc, "khaown" → khoăn) bị chốt recovery ngay ở phím `w` và
    // không bao giờ tới được bước đảo "ao" → "oa".
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

  /// Trạng thái TRUNG GIAN "ao" + dấu trăng, CHƯA có phụ âm cuối.
  ///
  /// Ngay khi phụ âm cuối tới, parser đảo "ao" → "oa" và âm tiết thành hoặc /
  /// ngoặc / khoăn / choắt. Đảo được cả khi người dùng gõ nghịch thứ tự a/o
  /// ("haowcj"), nên trạng thái này là đường đi hợp lệ chứ không phải input rác.
  /// Bắn recovery ở đây chốt `stopProcessing` và chặn luôn đường đó — recovery
  /// không nhả ra. Rule 5c và Rule 7 cùng phải tha, nên tách thành một hàm để
  /// hai luật không lệch nhau nữa.
  private static func dangChoPhuAmCuoiDeDaoAO(
    _ thanhPhan: ThanhPhanTieng, dauMu: DauMu
  ) -> Bool {
    dauMu == .muNgua
      && thanhPhan.phuAmCuoi.isEmpty
      && String(thanhPhan.nguyenAm).lowercased() == "ao"
  }

  /// Luật thanh nhập (Rule 5b), tách riêng để `TiengVietState` gọi được.
  ///
  /// Âm tiết kết bằng phụ âm tắc (c/ch/p/t/k) chỉ nhận sắc hoặc nặng. Gõ trúng
  /// huyền/hỏi/ngã ⇒ âm tiết bất khả ("ỏt", "òc", "ãch"), nên phím dấu phải rơi
  /// xuống thành chữ cái thường qua đường recovery. Đây là quy luật tuyệt đối,
  /// không ngoại lệ, nên guard này không bao giờ chặn nhầm từ thật — kể cả khi
  /// người dùng bật Free Mark Mode (xem `TiengVietState.needsRecovery`).
  static func viPhamThanhNhap(_ thanhPhan: ThanhPhanTieng, dauThanh: DauThanh) -> Bool {
    guard !thanhPhan.phuAmCuoi.isEmpty else { return false }
    let phuAmCuoi = String(thanhPhan.phuAmCuoi).lowercased()
    return PhuAmCuoiTac.contains(phuAmCuoi) && ThanhKhongDiVoiAmTac.contains(dauThanh)
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
