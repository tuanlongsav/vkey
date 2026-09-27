//
//  SpellDecisionEngine.swift
//  vkey
//
//  Decides whether a committed word should stay Vietnamese, be restored
//  to the raw English keys, or surface suggestions. Extracted from
//  InputProcessor.swift in 1.5.0 to keep the input pipeline composable.
//

import Defaults
import Foundation

final class SpellDecisionEngine {
  static let shared = SpellDecisionEngine()

  private let lexiconManager: LexiconManager
  private let suggestionService: SuggestionService

  private let extremelyCommonVietnameseWords: Set<String> = [
    "mẹ", "ăn", "đi", "cho", "tôi", "anh", "em", "gì", "là", "và", "có", "không", "ở", "này",
    "của", "đã", "được", "trong", "người", "với", "một", "để", "những", "khi", "đến", "về",
    "tại", "cũng", "ra", "năm", "nhiều", "từ", "việc", "đồng", "nhà", "làm", "đó", "hiện",
    "ông", "vào", "học", "bị", "trên", "thể", "theo", "trường"
  ]

  /// 1.7.1: tập ký tự đặc trưng Việt (dấu thanh + nguyên âm râu/móc + đ).
  /// Nếu transformed chứa ít nhất 1 ký tự này, user intent rõ ràng là VN
  /// (đã gõ Telex/VNI để tạo dấu) → engine KHÔNG được restore raw.
  private static let vnDiacriticChars: Set<Character> = Set(
    "àáảãạăắằẳẵặâấầẩẫậ" +
    "èéẻẽẹêếềểễệ" +
    "ìíỉĩị" +
    "òóỏõọôốồổỗộơớờởỡợ" +
    "ùúủũụưứừửữự" +
    "ỳýỷỹỵđ"
  )

  static func hasVietnameseDiacritic(_ word: String) -> Bool {
    return word.lowercased().contains { vnDiacriticChars.contains($0) }
  }

  /// v2.3.21: detect Telex mu cancellation pattern.
  /// User gõ 3 nguyên âm liên tiếp (`ooo`, `aaa`, `eee`, `uuu`, `iii`) để
  /// cancel Telex mu (1 vowel với mu → 2 vowels raw). Engine processes:
  /// - 2nd vowel: apply mu (`oo` → `ô`).
  /// - 3rd vowel: toggle mu off + J2 raw append.
  /// - Result: transformed có 2 vowels (vd "google"), rawInput có 3 (vd "gooogle").
  ///
  /// Pattern detect: nếu rawInput có triple vowel AND collapse triple→double
  /// cho ra transformed → user dùng pattern này, keep transformed.
  ///
  /// Cover các English words không có trong lexicon (vd "footer", "noose",
  /// "smooth"…) khi user dùng pattern này.
  static func isLikelyTelexCancellation(rawInput: String, transformed: String) -> Bool {
    let raw = rawInput.lowercased()
    let trans = transformed.lowercased()
    let vowelTriples = ["ooo", "aaa", "eee", "uuu", "iii"]
    for triple in vowelTriples {
      if raw.contains(triple) {
        let doubled = String(triple.prefix(2))
        let collapsed = raw.replacingOccurrences(of: triple, with: doubled)
        if collapsed == trans {
          return true
        }
      }
    }
    return false
  }

  /// Màn hình là chữ Latin trơn và chỉ THIẾU so với chuỗi phím thô đúng
  /// những phím dấu Telex ⇒ phần thiếu là dấu vết của phím HUỶ, không phải chữ
  /// bị engine nuốt. Người gõ thấy "phôt", bấm thêm 'o' để về "photo"; chuỗi
  /// phím thô là "photoonicat" còn màn hình là "photonicat". Khôi phục về phím
  /// thô lúc này là gõ lại chính phím huỷ.
  ///
  /// Tổng quát hoá `isLikelyTelexCancellation` (chỉ bắt ba nguyên âm liền
  /// "ooo"): mũ gõ trễ ("phot"+o → "phôt") huỷ bằng "oo" KHÔNG liền với chữ o
  /// gốc, và huỷ móc/đ (ww, ddd) cũng để lại đúng kiểu dấu vết này.
  ///
  /// Engine chỉ nuốt phím khi biến nó thành dấu. Màn hình còn dấu thì là ca
  /// khôi phục thật ("text" → "tẽt"). Hết dấu mà vẫn thiếu phím thì phím đó đã
  /// bị nuốt rồi huỷ, vì mọi đường hồi phục khác đều trả nguyên chuỗi phím thô.
  ///
  /// Chỉ tính phím LẶP CHỮ (a/e/o/w/d) và phải đứng liền một phím giống hệt:
  /// người gõ huỷ ngay khi thấy dấu nên phím huỷ luôn liền phím vừa gõ. Phím
  /// thanh (s/f/r/x/j) KHÔNG tính: huỷ thanh cũng liền kề ("ss") và đã có luật
  /// `doubledTones` lo; phím thanh bị nuốt ở chỗ khác là do chính chữ tiếng Anh
  /// ("Jesus" → "Jeu", "asks" → "ak"), phải khôi phục như cũ.
  ///
  /// Chuỗi phím giống hệt vẫn có thể là người gõ nhanh gõ thẳng một từ có chữ
  /// đôi ("cocoon" → màn hình "cocon"). Không phân biệt được bằng phím, nên
  /// `evaluate` nhường cho từ điển: phím thô là từ tiếng Anh đã biết thì vẫn
  /// khôi phục.
  ///
  /// Đánh đổi đã đo trên 239.273 từ (/usr/share/dict/words + từ điển EN): gõ
  /// có huỷ ra sai 8.633 → 0 (Free Mark + ZWJF bật) và 7.302 → 0 (cả hai tắt);
  /// gõ thẳng đổi kết quả ở 55 / 49 từ ngoài từ điển, gần hết là từ hiếm
  /// (Canaanite, bowwow, homoousian…), phổ biến nhất là mongoose/veneer/tepee/
  /// powwow. Với các từ đó Space giữ đúng chữ đang hiện ("mongose") thay vì
  /// chuỗi phím.
  static func isTelexCancelResidue(rawInput: String, transformed: String) -> Bool {
    guard transformed.isASCIIAlphabeticWord else { return false }
    let raw = Array(rawInput.lowercased())
    let shown = Array(transformed.lowercased())
    guard raw.count > shown.count else { return false }
    let repeatMarkKeys: Set<Character> = ["a", "e", "o", "w", "d"]
    var matched = 0
    for (i, key) in raw.enumerated() {
      if matched < shown.count, key == shown[matched] {
        matched += 1
        continue
      }
      let repeatsNeighbour = (i > 0 && raw[i - 1] == key)
        || (i + 1 < raw.count && raw[i + 1] == key)
      guard repeatMarkKeys.contains(key), repeatsNeighbour else { return false }
    }
    return matched == shown.count
  }

  /// 1.7.4: detect English acronym pattern (e.g. ARM, USA, API, OK) ở
  /// rawInput. Khi user gõ all-caps short word không có double-letter
  /// Telex signal (dd/aa/oo/ee/uw/ow/aw) và không kết bằng tone key
  /// (s/f/r/x/j) → coi là English initialism. Tránh trường hợp R/S
  /// giữa các consonant bị Telex áp tone hỏi/sắc (ARM → Ảm).
  static func isLikelyEnglishAcronym(_ raw: String) -> Bool {
    let chars = Array(raw)
    guard chars.count >= 2, chars.count <= 5 else { return false }
    guard chars.allSatisfy({ $0.isASCII && $0.isUppercase && $0.isLetter }) else {
      return false
    }
    let lower = raw.lowercased()
    // VN typing markers (mũ, móc, đ) + tone-cancel patterns (rr/ss/ff/xx/jj
    // = user double-tap để xoá tone). Có bất kỳ pattern nào → KHÔNG phải
    // acronym, để các nhánh khác xử lý (keepRaw cho doubled-tone).
    let vnDoublePatterns = [
      "dd", "aa", "oo", "ee", "uu", "ww", "uw", "ow", "aw",
      "rr", "ss", "ff", "xx", "jj"
    ]
    if vnDoublePatterns.contains(where: { lower.contains($0) }) {
      return false
    }
    let toneEndKeys: Set<Character> = ["s", "f", "r", "x", "j"]
    if let last = lower.last, toneEndKeys.contains(last) {
      return false
    }
    return true
  }

  init(
    lexiconManager: LexiconManager = .shared,
    suggestionService: SuggestionService = .shared
  ) {
    self.lexiconManager = lexiconManager
    self.suggestionService = suggestionService
  }

  func evaluate(rawInput: String, transformed: String, needsRecovery: Bool) -> SpellDecision {
    guard Defaults[.spellCheckEnabled] else { return .keepVietnamese }
    guard !rawInput.isEmpty, !transformed.isEmpty else { return .keepVietnamese }

    let rawToken = rawInput.normalizedDictionaryToken
    let transformedToken = transformed.normalizedDictionaryToken
    guard !rawToken.isEmpty, !transformedToken.isEmpty else { return .keepRaw }

    // 1.7.4: English acronym pattern (ARM, USA, API, OK, ...). User gõ all
    // caps short word mà Telex vô tình áp tone (R/S/X/F/J giữa các consonant
    // → tone hỏi/sắc/...). Restore raw để giữ initialism tiếng Anh.
    // 4.12: từ VN viết HOA với phím dấu GIỮA từ ("TOASN"→"TOÁN", "HOJC"→
    // "HỌC") cũng khớp pattern all-caps này và từng bị restore nhầm thành
    // phím thô. Chỉ restore khi transformed không phải từ VN hợp lệ, hoặc
    // raw là từ EN thật (ARM→Ảm, USA→Úa); ngược lại rơi xuống nhánh thường
    // (từ VN hợp lệ → keepVietnamese).
    if Defaults[.englishAutoRestoreEnabled],
       Self.isLikelyEnglishAcronym(rawInput) {
      var rawLooksEnglish = lexiconManager.isEnglishWord(rawInput)
      if !rawLooksEnglish, Defaults[.useEnVnReference],
         EnVnReference.shared.lookupEnglish(rawInput) != nil {
        rawLooksEnglish = true
      }
      if rawLooksEnglish || !lexiconManager.isVietnameseWord(transformed) {
        return .restoreRawEnglish(rawInput)
      }
    }

    // Doubled Tone Mark Preservation: if raw input contains consecutive doubled tone marks, keep it raw
    let doubledTones = ["ss", "ff", "rr", "xx", "jj"]
    if doubledTones.contains(where: { rawToken.contains($0) }) {
      return .keepRaw
    }

    // Đã huỷ dấu bằng phím lặp (aa/oo/ee/ww/ddd) ⇒ màn hình đang đúng chữ
    // người gõ muốn. Mọi nhánh khôi phục/gợi ý bên dưới chỉ còn việc gõ lại phím
    // huỷ ("photonicat" → "photoonicat") hoặc đổi sang từ khác. Trừ khi phím thô
    // là từ tiếng Anh đã biết: đó là người gõ thẳng "cocoon", engine tự hiểu chữ
    // 'o' thứ hai là phím huỷ.
    if Self.isTelexCancelResidue(rawInput: rawInput, transformed: transformed),
       !lexiconManager.isEnglishWord(rawInput),
       !(Defaults[.useEnVnReference] && EnVnReference.shared.lookupEnglish(rawInput) != nil) {
      return .keepRaw
    }

    if lexiconManager.shouldApplyLegacyRestore(transformed: transformed, rawInput: rawInput),
      Defaults[.englishAutoRestoreEnabled]
    {
      return .restoreRawEnglish(rawInput)
    }

    if lexiconManager.shouldKeepVietnamese(transformed) {
      return .keepVietnamese
    }

    let isVietnameseWord = lexiconManager.isVietnameseWord(transformed)
    var rawIsEnglish = lexiconManager.isEnglishWord(rawInput)

    // 1.5.0: the `en_vn_mapping` widens our notion of "English" — if the raw
    // token is a key in the bilingual reference, treat it as English even if
    // it wasn't in the embedded EN list. This catches all the words shipped
    // by Phase 4 (and by future Wiktionary-derived data drops) without
    // bloating the `english[]` array specifically for restore.
    if !rawIsEnglish, Defaults[.useEnVnReference],
       EnVnReference.shared.lookupEnglish(rawInput) != nil {
      rawIsEnglish = true
    }

    if Defaults[.englishAutoRestoreEnabled] {
      // 1.7.1 (revised): chỉ keep VN khi transformed có dấu Việt AND
      // không phải từ VN AND không phải từ EN — coi như từ mới/đặc biệt
      // mà cả hai lexicon đều thiếu. Nếu raw là từ EN hợp lệ (vd "text"
      // → "tẽt") thì user gõ tiếng Anh, phải restore raw.
      if Self.hasVietnameseDiacritic(transformedToken),
         !isVietnameseWord, !rawIsEnglish {
        return .keepVietnamese
      }

      // 1. If transformed output is NOT a valid Vietnamese word
      if !isVietnameseWord {
        // v2.3.20: nếu transformed IS English word, GIỮ.
        let transformedIsEnglish = lexiconManager.isEnglishWord(transformed)
        if transformedIsEnglish {
          return .keepRaw  // Keep transformed display as-is.
        }
        // v2.3.21: detect Telex mu cancellation pattern.
        // User gõ 3 nguyên âm liên tiếp (vd "ooo", "aaa", "eee", "uuu") để
        // cancel Telex mu. Engine collapse thành 2 → "footer" / "google" /…
        // Nếu rawInput có triple vowel và transformed collapse thành double
        // tại đúng vị trí (rest unchanged), giữ transformed.
        // Catches "foooter→footer", "noooose→noose", v.v. không cần lexicon.
        if Self.isLikelyTelexCancellation(rawInput: rawInput, transformed: transformed) {
          return .keepRaw
        }
        if rawToken.isASCIIAlphabeticWord, rawToken != transformedToken {
          return .restoreRawEnglish(rawInput)
        }
        if needsRecovery && rawIsEnglish {
          return .restoreRawEnglish(rawInput)
        }
      }
      // 2. If transformed output IS a valid Vietnamese word (checking policies for ambiguous words)
      else {
        if rawIsEnglish {
          let policy = Defaults[.restorePolicy]
          switch policy {
          case .englishFirst:
            return .restoreRawEnglish(rawInput)
          case .balanced:
            // 1.7.11: nếu transformed có dấu Việt (ả/ư/đ/...) thì user
            // rõ ràng đã gõ telex để tạo dấu → keep VN bất kể raw có
            // match English. Trước đây chỉ check `extremelyCommonVietnameseWords`
            // (~45 từ cherry-picked) → "cả", "nứt", "thể" và nhiều từ phổ
            // biến khác bị restore raw EN sai. Sau khi check dấu Việt,
            // mới fallback về common list cho các từ phẳng không dấu.
            if Self.hasVietnameseDiacritic(transformedToken) {
              return .keepVietnamese
            }
            if extremelyCommonVietnameseWords.contains(transformedToken) {
              return .keepVietnamese
            } else {
              return .restoreRawEnglish(rawInput)
            }
          case .vietnameseFirst:
            return .keepVietnamese
          }
        }
      }
    }

    if needsRecovery {
      if isVietnameseWord {
        return .keepVietnamese
      }
      guard Defaults[.suggestionEnabled] else { return .keepRaw }
      let suggestions = suggestionService.suggest(word: transformed, locale: "vi_VN", limit: 5)
      return suggestions.isEmpty ? .keepRaw : .suggest(suggestions)
    }

    return .keepVietnamese
  }
}
