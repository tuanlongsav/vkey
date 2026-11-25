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
enum TiengVietParser {

  // MARK: - API chính

  static func parse(
    _ chuKhongDau: [Character],
    autoTypoCorrection: Bool = true,
    allowedZWJF: Bool = true
  ) -> ThanhPhanTieng {
    var result = rawParse(chuKhongDau, allowedZWJF: allowedZWJF)
    if autoTypoCorrection {
      let options = EngineOptions(
        autoTypoCorrection: autoTypoCorrection,
        allowedZWJF: allowedZWJF
      )
      applyTypoCorrections(to: &result, originalInput: chuKhongDau, options: options)
    }
    return result
  }

  /// Phân tích chuỗi ký tự thành các thành phần âm tiết tiếng Việt (không áp dụng sửa lỗi tự động)
  static func rawParse(_ chuKhongDau: [Character], allowedZWJF: Bool = true) -> ThanhPhanTieng {
    var result = ThanhPhanTieng()
    var remaining = String(chuKhongDau)

    guard !remaining.isEmpty else { return result }

    // Bước 1: Tách phụ âm đầu bằng Trie (giữ nguyên hoa/thường đầu vào)
    let initialLen = TiengViet.phuAmDauTrie(allowedZWJF: allowedZWJF).longestPrefixLength(in: remaining)
    if initialLen > 0 {
      result.phuAmDau = Array(remaining.prefix(initialLen))
      remaining = String(remaining.dropFirst(initialLen))
    }

    // Tiếp tục với nguyên âm, phụ âm cuối, phần dư
    result = finishParsing(result: &result, remaining: remaining)

    // Xử lý đặc biệt cho "gi":
    // - Phụ âm "gi": gia, giá, giáng, giữ (gi + nguyên âm)
    // - Phụ âm "g" + nguyên âm "i": gì, gin, giếng, giết (g + i...)
    if result.phuAmDau.count == 2,
       result.phuAmDau[0].lowercased() == "g",
       result.phuAmDau[1].lowercased() == "i" {
      let iChar = result.phuAmDau[1]

      switch classifyGi(
        iChar: iChar,
        originalVowel: result.nguyenAm,
        originalFinal: result.phuAmCuoi,
        originalLeftover: result.conLai,
        allowedZWJF: allowedZWJF
      ) {
      case .splitG:
        result.phuAmDau = [result.phuAmDau[0]]
        if result.nguyenAm.isEmpty {
          result.nguyenAm = [iChar]
        } else {
          let newRemaining = String([iChar] + result.nguyenAm + result.phuAmCuoi + result.conLai)
          result.nguyenAm = []
          result.phuAmCuoi = []
          result.conLai = []
          result = finishParsing(result: &result, remaining: newRemaining)
        }

      case .keepGi:
        break
      }
    }

    return result
  }

  // MARK: - Hàm nội bộ

  private static func finishParsing(
    result: inout ThanhPhanTieng,
    remaining: String
  ) -> ThanhPhanTieng {
    var remaining = remaining

    // Bước 2: Tách nguyên âm bằng Trie
    let vowelLen = TiengViet.NguyenAmTrie.longestPrefixLength(in: remaining)
    if vowelLen > 0 {
      result.nguyenAm = Array(remaining.prefix(vowelLen))
      result.chuaNguyenAmUO = isNguyenAmUO(result.nguyenAm)
      remaining = String(remaining.dropFirst(vowelLen))
    }

    // Bước 3: Tách phụ âm cuối bằng Trie
    let finalLen = TiengViet.PhuAmCuoiTrie.longestPrefixLength(in: remaining)
    if finalLen > 0 {
      result.phuAmCuoi = Array(remaining.prefix(finalLen))
      remaining = String(remaining.dropFirst(finalLen))
    }

    // Bước 4: Phần còn lại
    result.conLai = Array(remaining)
    return result
  }

  /// Phân tích PHẦN ĐUÔI đứng sau nguyên âm: chỉ tách phụ âm cuối + phần dư,
  /// KHÔNG tách nguyên âm (tránh ghi đè nguyên âm vừa swap).
  private static func parseDuoiSauNguyenAm(
    result: inout ThanhPhanTieng,
    remaining: String
  ) -> ThanhPhanTieng {
    var remaining = remaining

    let finalLen = TiengViet.PhuAmCuoiTrie.longestPrefixLength(in: remaining)
    if finalLen > 0 {
      result.phuAmCuoi = Array(remaining.prefix(finalLen))
      remaining = String(remaining.dropFirst(finalLen))
    }

    result.conLai = Array(remaining)
    return result
  }

  private static func isNguyenAmUO(_ nguyenAm: [Character]) -> Bool {
    TiengViet.NguyenAmUO.contains(String(nguyenAm).lowercased())
  }

  private static func startsWithForeignConsonant(_ phuAmDau: [Character]) -> Bool {
    guard let first = phuAmDau.first?.lowercased().first else { return false }
    return TiengViet.ForeignConsonants.contains(first)
  }

  /// Helper dùng chung cho 4 rule swap nguyên âm (`ei→ie`, `ou→uo`, `aoi→oai`, `ao+C→oa+C`).
  private static func trySwapVowel(
    into result: inout ThanhPhanTieng,
    swappedVowel: [Character],
    tail: String,
    shouldCommit: (ThanhPhanTieng) -> Bool = { $0.conLai.isEmpty }
  ) {
    var reparsed = ThanhPhanTieng()
    reparsed.nguyenAm = swappedVowel
    reparsed = parseDuoiSauNguyenAm(result: &reparsed, remaining: tail)
    guard shouldCommit(reparsed) else { return }
    result.nguyenAm = reparsed.nguyenAm
    result.phuAmCuoi = reparsed.phuAmCuoi
    result.conLai = reparsed.conLai
    result.chuaNguyenAmUO = isNguyenAmUO(result.nguyenAm)
  }

  /// Auto-correct common adjacent-key ordering mistakes before validation.
  private static func applyTypoCorrections(
    to result: inout ThanhPhanTieng,
    originalInput: [Character],
    options: EngineOptions
  ) {
    // Fast path: âm tiết đã sạch và không cần recovery → không rule nào có thể fire.
    if !result.nguyenAm.isEmpty,
       result.conLai.isEmpty,
       !TiengVietValidator.needsRecovery(result, options: options) {
      return
    }

    let isForeign = startsWithForeignConsonant(result.phuAmDau)

    // "veit" -> "viet"
    if !isForeign,
       result.nguyenAm.count == 1,
       result.nguyenAm[0].lowercased() == "e",
       result.phuAmCuoi.isEmpty,
       let firstLeftover = result.conLai.first,
       firstLeftover.lowercased() == "i"
    {
      trySwapVowel(
        into: &result,
        swappedVowel: [firstLeftover, result.nguyenAm[0]],
        tail: String(result.conLai.dropFirst())
      )
    }

    // "bous" -> "buos" (guard prefix EN `sou`→`source` + không nuốt phụ âm cuối như "opu")
    if !isForeign,
       result.nguyenAm.count == 1,
       result.nguyenAm[0].lowercased() == "o",
       result.phuAmCuoi.isEmpty,
       let firstLeftover = result.conLai.first,
       firstLeftover.lowercased() == "u"
    {
      let tail = String(result.conLai.dropFirst())
      let englishOuPrefix = tail.isEmpty && TiengViet.isEnglishOuTypoInProgress(originalInput)
      if !englishOuPrefix {
        trySwapVowel(
          into: &result,
          swappedVowel: [firstLeftover, result.nguyenAm[0]],
          tail: tail
        )
      }
    }

    // "haois" -> "hoais"
    if !isForeign,
       result.nguyenAm.count == 2,
       result.nguyenAm[0].lowercased() == "a",
       result.nguyenAm[1].lowercased() == "o",
       result.phuAmCuoi.isEmpty,
       let firstLeftover = result.conLai.first,
       firstLeftover.lowercased() == "i"
    {
      trySwapVowel(
        into: &result,
        swappedVowel: [result.nguyenAm[1], result.nguyenAm[0], firstLeftover],
        tail: String(result.conLai.dropFirst())
      )
    }

    // "haoc" -> "hoac" (chặn camelCase "DaoTao" bằng guard hoa/thường ở phụ âm cuối)
    if !isForeign,
       result.nguyenAm.count == 2,
       result.nguyenAm[0].lowercased() == "a",
       result.nguyenAm[1].lowercased() == "o",
       (!result.phuAmCuoi.isEmpty || !result.conLai.isEmpty)
    {
      let oChar = result.nguyenAm[1]
      trySwapVowel(
        into: &result,
        swappedVowel: [oChar, result.nguyenAm[0]],
        tail: String(result.phuAmCuoi + result.conLai)
      ) { reparsed in
        let capitalBoundary = (reparsed.phuAmCuoi.first?.isUppercase ?? false) && oChar.isLowercase
        return !reparsed.phuAmCuoi.isEmpty && reparsed.conLai.isEmpty && !capitalBoundary
      }
    }

    // "phuowgn" -> "phuong"
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

    // Rule 5: Misplaced tone-mark auto-correction (e.g. "thfi" -> "thì", "trfong" -> "trồng")
    if result.nguyenAm.isEmpty || !result.conLai.isEmpty
      || TiengVietValidator.needsRecovery(result, options: options)
    {
      let inputStr = String(originalInput)
      let initialLen = TiengViet.phuAmDauTrie(allowedZWJF: options.allowedZWJF)
        .longestPrefixLength(in: inputStr)
      let matchedInitial = initialLen > 0 ? Array(inputStr.prefix(initialLen)) : []
      let doDaiPhuAmDau = startsWithForeignConsonant(matchedInitial) ? 0 : initialLen

      var toneIndex: Int? = nil
      if doDaiPhuAmDau < originalInput.count {
        for i in doDaiPhuAmDau..<originalInput.count {
          let lower = originalInput[i].lowercased().first!
          if TiengViet.TelexToneKeys[lower] != nil || TiengViet.VNIToneKeys[lower] != nil {
            toneIndex = i
            break
          }
        }
      }

      if let index = toneIndex, index > 0, index < originalInput.count - 1 {
        let kyTuDau = originalInput[index].lowercased().first!
        let foundTone = TiengViet.TelexToneKeys[kyTuDau] ?? TiengViet.VNIToneKeys[kyTuDau]
        var strippedChars = originalInput
        strippedChars.remove(at: index)

        if let tone = foundTone, !strippedChars.isEmpty {
          let tempResult = rawParse(strippedChars, allowedZWJF: options.allowedZWJF)
          if !tempResult.nguyenAm.isEmpty && tempResult.conLai.isEmpty
            && !TiengVietValidator.needsRecovery(tempResult, options: options)
          {
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

  private enum GiClassification {
    case splitG
    case keepGi
  }

  private static func classifyGi(
    iChar: Character,
    originalVowel: [Character],
    originalFinal: [Character],
    originalLeftover: [Character],
    allowedZWJF: Bool
  ) -> GiClassification {
    if originalVowel.isEmpty { return .splitG }
    if originalFinal.isEmpty { return .keepGi }

    let candidate = String([iChar] + originalVowel + originalFinal + originalLeftover)
    var probe = ThanhPhanTieng()
    probe = finishParsing(result: &probe, remaining: candidate)

    let opts = EngineOptions(allowedZWJF: allowedZWJF)
    if !probe.phuAmCuoi.isEmpty && !TiengVietValidator.needsRecovery(probe, options: opts) {
      return .splitG
    }

    return .keepGi
  }
}
