//
//  TiengVietParser.swift
//  vkey
//
//  Hàm thuần phân tích âm tiết tiếng Việt (Pure parsing functions)
//

import Foundation

/// TiengVietParser - Hàm thuần phân tích, không có side effects.
///
/// Chuyển đổi mảng ký tự chưa có dấu thành cấu trúc ThanhPhanTieng.
/// Quy trình: Phụ âm đầu → Nguyên âm → Phụ âm cuối → Phần dư.
///
/// Parser **không** đọc `Defaults` — mọi tuỳ chọn (vd autoTypoCorrection)
/// được truyền vào qua tham số. `TiengVietState` là điểm đọc Defaults duy
/// nhất và truyền cờ xuống. Điều này cho phép unit test dễ dàng và tách
/// rõ trách nhiệm giữa pure logic và stateful UI layer.
enum TiengVietParser {

  // MARK: - API chính

  /// Phân tích chuỗi ký tự thành các thành phần âm tiết tiếng Việt.
  /// - Parameters:
  ///   - chuKhongDau: Mảng ký tự chưa có dấu (từ bàn phím)
  ///   - autoTypoCorrection: Bật/tắt sửa lỗi gõ nhầm tự động
  /// - Returns: ThanhPhanTieng với các thành phần đã phân tích
  static func parse(_ chuKhongDau: [Character], autoTypoCorrection: Bool = true) -> ThanhPhanTieng {
    var result = rawParse(chuKhongDau)
    if autoTypoCorrection {
      applyTypoCorrections(to: &result, originalInput: chuKhongDau)
    }
    return result
  }

  /// Phân tích chuỗi ký tự thành các thành phần âm tiết tiếng Việt (không áp dụng sửa lỗi tự động)
  static func rawParse(_ chuKhongDau: [Character]) -> ThanhPhanTieng {
    var result = ThanhPhanTieng()
    var remaining = String(chuKhongDau)

    guard !remaining.isEmpty else { return result }

    // Bước 1: Tách phụ âm đầu bằng Trie
    if let matched = TiengViet.PhuAmDauTrie.findLongestPrefix(in: remaining) {
      result.phuAmDau = Array(matched)
      remaining = String(remaining.dropFirst(matched.count))
    }

    // Tiếp tục với nguyên âm, phụ âm cuối, phần dư
    result = finishParsing(result: &result, remaining: remaining)

    // Xử lý đặc biệt cho "gi":
    // Trie ban đầu match "gi" như phụ âm ghép, nhưng trong tiếng Việt "gi" có ngữ nghĩa kép:
    // - Phụ âm "gi": gia, giá, giáng, giữ (gi + nguyên âm)
    // - Phụ âm "g" + nguyên âm "i": gì, gin, giếng, giết (g + i...)
    // Dùng classifyGi() để quyết định cách tách.
    if result.phuAmDau.count == 2,
       result.phuAmDau[0].lowercased() == "g",
       result.phuAmDau[1].lowercased() == "i" {
      let iChar = result.phuAmDau[1]

      switch classifyGi(
        iChar: iChar,
        originalVowel: result.nguyenAm,
        originalFinal: result.phuAmCuoi,
        originalLeftover: result.conLai
      ) {
      case .splitG:
        // "g" là phụ âm, "i" ghép vào nhóm nguyên âm
        result.phuAmDau = [result.phuAmDau[0]]
        if result.nguyenAm.isEmpty {
          // "gi", "gin" → g + i, g + i + n
          result.nguyenAm = [iChar]
        } else {
          // "giếng" → g + iê + ng, "giết" → g + iê + t
          let newRemaining = String([iChar] + result.nguyenAm + result.phuAmCuoi + result.conLai)
          result.nguyenAm = []
          result.phuAmCuoi = []
          result.conLai = []
          result = finishParsing(result: &result, remaining: newRemaining)
        }

      case .keepGi:
        // "gi" giữ nguyên là phụ âm ghép
        break
      }
    }

    return result
  }

  // MARK: - Hàm nội bộ

  /// Tiếp tục phân tích sau khi đã tách phụ âm đầu
  private static func finishParsing(
    result: inout ThanhPhanTieng,
    remaining: String
  ) -> ThanhPhanTieng {
    var remaining = remaining

    // Bước 2: Tách nguyên âm bằng Trie
    if let matched = TiengViet.NguyenAmTrie.findLongestPrefix(in: remaining) {
      result.nguyenAm = Array(matched)
      result.chuaNguyenAmUO = TiengViet.NguyenAmUO.contains {
        $0.lowercased() == matched.lowercased()
      }
      remaining = String(remaining.dropFirst(matched.count))
    }

    // Bước 3: Tách phụ âm cuối bằng Trie
    if let matched = TiengViet.PhuAmCuoiTrie.findLongestPrefix(in: remaining) {
      result.phuAmCuoi = Array(matched)
      remaining = String(remaining.dropFirst(matched.count))
    }

    // Bước 4: Phần còn lại (không thuộc âm tiết tiếng Việt hợp lệ)
    result.conLai = Array(remaining)
    return result
  }

  /// Re-compute whether the given vowel group should be flagged as a "uo"-class
  /// vowel (móc on both u and o → "ươ"). Reads from `TiengViet.NguyenAmUO` so
  /// future additions to that table propagate without code changes here.
  private static func isNguyenAmUO(_ nguyenAm: [Character]) -> Bool {
    let key = String(nguyenAm).lowercased()
    return TiengViet.NguyenAmUO.contains { $0.lowercased() == key }
  }

  /// Auto-correct common adjacent-key ordering mistakes before validation.
  private static func applyTypoCorrections(to result: inout ThanhPhanTieng, originalInput: [Character]) {
    // "veit" -> "viet": users sometimes type the second "e" before "i"
    // when aiming for "việt". The first parse sees "e" + leftover "i...";
    // reparsing the tail lets final consonants such as "t" or "ng" attach normally.
    if result.nguyenAm.count == 1,
      result.nguyenAm[0].lowercased() == "e",
      let firstLeftover = result.conLai.first,
      firstLeftover.lowercased() == "i"
    {
      let eChar = result.nguyenAm[0]
      let iChar = firstLeftover
      let tail = String(result.conLai.dropFirst())
      var reparsed = ThanhPhanTieng()
      reparsed.nguyenAm = [iChar, eChar]
      reparsed = finishParsing(result: &reparsed, remaining: tail)
      result.nguyenAm = reparsed.nguyenAm
      result.phuAmCuoi = reparsed.phuAmCuoi
      result.conLai = reparsed.conLai
      // chuaNguyenAmUO recomputed by finishParsing against NguyenAmUO table —
      // never hardcode here, otherwise new vowel patterns added to that table
      // would not propagate through typo recovery.
      result.chuaNguyenAmUO = isNguyenAmUO(result.nguyenAm)
    }

    // "bous" -> "buos" (to become "buốt" when tone/diacritics applied)
    // "ou" is not a valid Vietnamese vowel group, so vowel trie parses "o"
    // leaving "u" in conLai.
    if result.nguyenAm.count == 1,
      result.nguyenAm[0].lowercased() == "o",
      let firstLeftover = result.conLai.first,
      firstLeftover.lowercased() == "u"
    {
      let oChar = result.nguyenAm[0]
      let uChar = firstLeftover
      let tail = String(result.conLai.dropFirst())
      var reparsed = ThanhPhanTieng()
      reparsed.nguyenAm = [uChar, oChar]
      reparsed = finishParsing(result: &reparsed, remaining: tail)
      result.nguyenAm = reparsed.nguyenAm
      result.phuAmCuoi = reparsed.phuAmCuoi
      result.conLai = reparsed.conLai
      result.chuaNguyenAmUO = isNguyenAmUO(result.nguyenAm)
    }

    // "haois" -> "hoais" (to become "hoái")
    // "aoi" is not valid. Vowel trie parses "ao" -> nguyenAm = ["a", "o"], leaving "i" in conLai.
    if result.nguyenAm.count == 2,
      result.nguyenAm[0].lowercased() == "a",
      result.nguyenAm[1].lowercased() == "o",
      let firstLeftover = result.conLai.first,
      firstLeftover.lowercased() == "i"
    {
      let aChar = result.nguyenAm[0]
      let oChar = result.nguyenAm[1]
      let iChar = firstLeftover
      let tail = String(result.conLai.dropFirst())
      var reparsed = ThanhPhanTieng()
      reparsed.nguyenAm = [oChar, aChar, iChar]
      reparsed = finishParsing(result: &reparsed, remaining: tail)
      result.nguyenAm = reparsed.nguyenAm
      result.phuAmCuoi = reparsed.phuAmCuoi
      result.conLai = reparsed.conLai
      result.chuaNguyenAmUO = isNguyenAmUO(result.nguyenAm)
    }

    // "haoc" -> "hoac" (to become "hoác").
    // Vowel trie parses "ao" -> nguyenAm = ["a", "o"].
    // If we have "ao" and either phuAmCuoi or conLai is not empty, we try to re-parse with "oa" as the vowel group.
    // If the re-parsed result successfully extracts a final consonant (phuAmCuoi is not empty),
    // then this was indeed a typo of "oa" followed by final consonant!
    if result.nguyenAm.count == 2,
      result.nguyenAm[0].lowercased() == "a",
      result.nguyenAm[1].lowercased() == "o",
      (!result.phuAmCuoi.isEmpty || !result.conLai.isEmpty)
    {
      let aChar = result.nguyenAm[0]
      let oChar = result.nguyenAm[1]
      let remainingStr = String(result.phuAmCuoi + result.conLai)
      var reparsed = ThanhPhanTieng()
      reparsed.nguyenAm = [oChar, aChar]
      reparsed = finishParsing(result: &reparsed, remaining: remainingStr)
      if !reparsed.phuAmCuoi.isEmpty {
        result.nguyenAm = reparsed.nguyenAm
        result.phuAmCuoi = reparsed.phuAmCuoi
        result.conLai = reparsed.conLai
        result.chuaNguyenAmUO = isNguyenAmUO(result.nguyenAm)
      }
    }

    // "phuowgn" -> "phuong": transpose a trailing "gn" into the valid
    // Vietnamese final consonant "ng".
    if result.phuAmCuoi.isEmpty,
      result.conLai.count >= 2,
      result.conLai[0].lowercased() == "g",
      result.conLai[1].lowercased() == "n"
    {
      let gChar = result.conLai[0]
      let nChar = result.conLai[1]
      result.phuAmCuoi = [
        nChar.isUppercase ? "N" : "n",
        gChar.isUppercase ? "G" : "g",
      ]
      result.conLai = Array(result.conLai.dropFirst(2))
    }

    // Rule 5: Misplaced tone-mark auto-correction (e.g. "thfi" -> "thì", "dinhj" -> "dịnh" which can be combined, etc.)
    // We try to find and strip any misplaced tone mark key and see if the rest forms a perfect syllable
    if result.nguyenAm.isEmpty || !result.conLai.isEmpty || TiengVietValidator.needsRecovery(result) {
      let telexTones: [Character: DauThanh] = ["s": .sac, "f": .huyen, "r": .hoi, "x": .nga, "j": .nang]
      let vniTones: [Character: DauThanh] = ["1": .sac, "2": .huyen, "3": .hoi, "4": .nga, "5": .nang]

      // Check if there is a tone mark and it is NOT the last character in the input (otherwise it is a trailing tone mark, not misplaced)
      var toneIndex: Int? = nil
      for (i, char) in originalInput.enumerated() {
        let lower = char.lowercased().first!
        if telexTones[lower] != nil || vniTones[lower] != nil {
          toneIndex = i
          break
        }
      }

      if let index = toneIndex, index > 0, index < originalInput.count - 1 {
        var foundTone: DauThanh? = nil
        var strippedChars: [Character] = []

        // Try Telex tones
        for char in originalInput {
          let lower = char.lowercased().first!
          if let tone = telexTones[lower], foundTone == nil {
            foundTone = tone
          } else {
            strippedChars.append(char)
          }
        }

        // If not found in Telex, try VNI tones
        if foundTone == nil {
          strippedChars = []
          for char in originalInput {
            let lower = char.lowercased().first!
            if let tone = vniTones[lower], foundTone == nil {
              foundTone = tone
            } else {
              strippedChars.append(char)
            }
          }
        }

        if let tone = foundTone, !strippedChars.isEmpty {
          let tempResult = rawParse(strippedChars)
          if !tempResult.nguyenAm.isEmpty && tempResult.conLai.isEmpty && !TiengVietValidator.needsRecovery(tempResult) {
            result.phuAmDau = tempResult.phuAmDau
            result.nguyenAm = tempResult.nguyenAm
            result.phuAmCuoi = tempResult.phuAmCuoi
            result.conLai = tempResult.conLai
            result.chuaNguyenAmUO = tempResult.chuaNguyenAmUO
            result.viTriDauMu = tempResult.viTriDauMu
            result.viTriDauThanh = tempResult.viTriDauThanh
            result.uuTienDauThanh = tone
          }
        }
      }
    }
  }

  // MARK: - Phân loại "gi"

  /// Kết quả phân loại cách xử lý "gi"
  private enum GiClassification {
    /// "g" là phụ âm đầu, "i" ghép vào nhóm nguyên âm
    /// Ví dụ: gi → g+i, gin → g+i+n, giếng → g+iê+ng, giết → g+iê+t
    case splitG

    /// "gi" giữ nguyên là phụ âm ghép, phần sau là nguyên âm
    /// Ví dụ: gia → gi+a, giáng → gi+a+ng, giữ → gi+ư
    case keepGi
  }

  /// Quyết định cách xử lý "gi" dựa trên ngữ cảnh phía sau
  ///
  /// Quy tắc:
  /// 1. Không có nguyên âm sau → tách "g" + "i" (i là nguyên âm duy nhất)
  /// 2. Có nguyên âm nhưng không có phụ âm cuối → giữ "gi" (để đặt dấu đúng)
  /// 3. Có nguyên âm + phụ âm cuối → thử ghép "i" vào nguyên âm:
  ///    - Nếu kết quả hợp lệ (ie+ng) → tách "g"
  ///    - Nếu không hợp lệ (ia+ng) → giữ "gi"
  private static func classifyGi(
    iChar: Character,
    originalVowel: [Character],
    originalFinal: [Character],
    originalLeftover: [Character]
  ) -> GiClassification {
    // Trường hợp 1: Không có nguyên âm sau "gi" → "i" phải là nguyên âm
    // Ví dụ: "gi" → g+i, "gin" → g+i+n
    if originalVowel.isEmpty {
      return .splitG
    }

    // Trường hợp 2: Có nguyên âm nhưng không có phụ âm cuối → giữ "gi"
    // Để đặt dấu thanh đúng vị trí. Ví dụ: "giá" = gi+á (dấu trên 'a')
    if originalFinal.isEmpty {
      return .keepGi
    }

    // Trường hợp 3: Có nguyên âm + phụ âm cuối → thử ghép "i" vào nguyên âm
    // Dùng probe riêng để kiểm tra, không ảnh hưởng kết quả gốc
    let candidate = String([iChar] + originalVowel + originalFinal + originalLeftover)
    var probe = ThanhPhanTieng()
    probe = finishParsing(result: &probe, remaining: candidate)

    // Nếu kết quả hợp lệ (ví dụ ie+ng), tách "g"
    // Nếu không hợp lệ (ví dụ ia+ng), giữ "gi"
    if !probe.phuAmCuoi.isEmpty && !TiengVietValidator.needsRecovery(probe) {
      return .splitG
    }

    return .keepGi
  }
}
