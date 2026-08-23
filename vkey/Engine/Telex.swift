//
//  Telex.swift
//  vkey
//
//  Created by KhanhIceTea on 17/02/2024.
//

import Defaults

/// Telex - Kiểu gõ tiếng Việt phổ biến nhất
///
/// Bảng phím Telex:
/// ┌─────────────────────────────────────────────────────────┐
/// │ Phím dấu thanh (Tone marks):                            │
/// │   s = sắc (´)  - má                                     │
/// │   f = huyền (`) - mà                                    │
/// │   r = hỏi (ˀ)  - mả                                     │
/// │   x = ngã (~)  - mã                                     │
/// │   j = nặng (.) - mạ                                     │
/// ├─────────────────────────────────────────────────────────┤
/// │ Phím dấu mũ (Diacritical marks):                        │
/// │   aa = â (mũ)         - cân                             │
/// │   ee = ê (mũ)         - bên                             │
/// │   oo = ô (mũ)         - tôi                             │
/// │   aw = ă (trăng)      - ăn                              │
/// │   ow = ơ (móc)        - ơi                              │
/// │   uw = ư (móc)        - ưa                              │
/// │   w  = ơ/ư tùy ngữ cảnh - tươi = tuowi                  │
/// ├─────────────────────────────────────────────────────────┤
/// │ Phím đặc biệt:                                          │
/// │   dd = đ (gạch ngang) - đi                              │
/// └─────────────────────────────────────────────────────────┘
///
/// Quy tắc hủy dấu (gõ đúp):
/// - Gõ đúp phím dấu thanh (ss, ff, rr, xx, jj) → hủy dấu, in ký tự gốc
/// - Gõ đúp nguyên âm sau khi đã có (aaa, ooo, eee) → in nguyên âm thường
/// - Gõ ww → hủy dấu móc/trăng

import Foundation

class Telex: TypingMethod {

  /// Mọi vần nguyên âm hợp lệ, chuẩn hoá về CHỮ THƯỜNG để tra một lần.
  /// `TiengViet.NguyenAm` liệt kê đủ mọi biến thể hoa/thường (8 dòng cho mỗi vần
  /// ba chữ) nên tra thẳng vào đó sẽ phải sinh lại chuỗi theo đúng kiểu chữ đang
  /// gõ; ở đây chỉ cần biết "cụm này có phải vần tiếng Việt không".
  private static let vanNguyenAmHopLe: Set<String> =
    Set(TiengViet.NguyenAm.map { $0.lowercased() })

  // MARK: - TypingMethod Protocol

  /// Kiểm tra có nên dừng xử lý Telex không
  public func shouldStopProcessing(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()

    // 1. Check simple suffixes (double tap tone marks or w)
    if lowerKeyStr.hasSuffix("ss") || lowerKeyStr.hasSuffix("ff") ||
       lowerKeyStr.hasSuffix("rr") || lowerKeyStr.hasSuffix("xx") ||
       lowerKeyStr.hasSuffix("jj") || lowerKeyStr.hasSuffix("ww") {
      return true
    }

    // 2. Check digit suffix
    if let lastChar = lowerKeyStr.last, lastChar.isNumber {
      return true
    }
      
    // 3. Check complex cases (double tap vowel/d when it already exists)
    // "aa", "oo", "ee", "dd" -> Cancel mark if the character exists before
    
    // Check "aa" suffix: requires 'a' to exist previously
    if lowerKeyStr.hasSuffix("aa") {
      // Check content before suffix for 'a'
      return lowerKeyStr.dropLast(2).contains("a")
    }
    
    // Check "oo" suffix: requires 'o' to exist previously
    if lowerKeyStr.hasSuffix("oo") {
      return lowerKeyStr.dropLast(2).contains("o")
    }
    
    // Check "ee" suffix: requires 'e' to exist previously
    if lowerKeyStr.hasSuffix("ee") {
      return lowerKeyStr.dropLast(2).contains("e")
    }
    
    // Check "dd" suffix: requires 'd' to exist previously at the start of the word
    if lowerKeyStr.hasSuffix("dd") {
      return lowerKeyStr.dropLast(2).hasPrefix("d")
    }

    return false
  }

  /// Xử lý ký tự nhập vào theo kiểu gõ Telex
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - state: Trạng thái TiengVietState hiện tại
  /// - Returns: Tuple (state mới, có áp dụng dấu không)
  public func push(char: Character, state: TiengVietState) -> (state: TiengVietState, appliedMark: Bool) {
    let thanhPhan = state.thanhPhanTieng

    // Bỏ qua nếu từ có phần không hợp lệ (conLai)
    if !thanhPhan.conLai.isEmpty {
      return (state.push(char), false)
    }

    // Xử lý dd → đ (phím d gõ 2 lần)
    if state.chuKhongDau.count == 1,
      let chuCaiDau = state.chuKhongDau.first,
      (char == "d" || char == "D") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      return (state.withGachD(), true)
    }

    // Xử lý phím d gõ cuối từ để gạch D (Late D toggle, ví dụ: dinjhd -> định)
    if let toggled = state.tryLateDToggle(char: char, triggerChars: ["d", "D"]) {
      return (toggled, true)
    }

    // Xử lý các phím dấu (chỉ khi đã có nguyên âm)
    if !thanhPhan.nguyenAm.isEmpty {
      switch char {
      // Phím dấu thanh: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng
      case "s", "S":
        return (state.withTone(.sac), true)
      case "f", "F":
        return (state.withTone(.huyen), true)
      case "r", "R":
        return (state.withTone(.hoi), true)
      case "x", "X":
        return (state.withTone(.nga), true)
      case "j", "J":
        return (state.withTone(.nang), true)

      // Phím dấu mũ: aa=â, ee=ê, oo=ô (gõ đúp nguyên âm)
      case "a", "o", "e", "A", "O", "E":
        // Dấu mũ Telex là gõ LẶP nguyên âm (aa/ee/oo). Điều kiện cũ chỉ hỏi
        // "nguyên âm có CHỨA ký tự này ở bất kỳ đâu", nên nguyên âm ba oeo/oao bị
        // hiểu nhầm là lệnh mũ: "khoeo" → "khôe", "ngoaos" → "ngốa".
        //
        // Chặn đúng ca đó: ký tự LIỀN TRƯỚC là một nguyên âm KHÁC **và** cụm
        // nguyên âm nối thêm ký tự này là một vần CÓ THẬT ⇒ người dùng đang dựng
        // nguyên âm ba (oeo/oao đã có sẵn trong TiengViet.NguyenAmGhep) chứ không
        // gõ lặp — thả ký tự xuống push thô là transformer đặt dấu đúng.
        //
        // Vế "vần có thật" là bắt buộc, KHÔNG được rút gọn thành "liền trước là
        // nguyên âm khác": Telex của vkey cho gõ mũ TRỄ, cả sau phụ âm cuối
        // ("theme" → "thêm") lẫn sau nguyên âm ("toio" → "tôi", "taio" → "tôi").
        // Rút gọn thì "oi"+o = "oio" — vần không tồn tại, chắc chắn là lệnh mũ —
        // cũng bị chặn nốt và "toio" rơi xuống recovery thành chuỗi phím thô.
        //
        let chuThuong = Character(char.lowercased())
        let chuHoa = Character(char.uppercased())
        let dangDungNguyenAmBa = state.chuKhongDau.last.map { lienTruoc in
          lienTruoc != chuThuong && lienTruoc != chuHoa
            && TiengViet.NguyenAmDon.contains(String(lienTruoc))
            && Self.vanNguyenAmHopLe.contains(
              String(thanhPhan.nguyenAm + [chuThuong]).lowercased())
        } ?? false

        // Bất đối xứng hoa/thường ở đây là CỐ Ý, không phải sót:
        //   • phím THƯỜNG khớp cả nguyên âm hoa lẫn thường ⇒ "Aa" → "Â". Shift ở
        //     phím ĐẦU của cặp = viết hoa cả từ, phím sau vẫn là gõ lặp.
        //   • phím HOA chỉ khớp nguyên âm HOA ⇒ "aA" giữ nguyên "aA". Shift ở
        //     phím SAU nghĩa là người dùng vừa CHỦ ĐỘNG mở một chữ hoa mới, không
        //     ai bấm Shift để gõ ra chữ â THƯỜNG.
        // Từng thử nới cho đối xứng cả hai chiều: đo lại thì không cứu được ca
        // nào (corpus 7.184 âm tiết, selftest 127 ca, 5.622 ca gõ thanh sớm,
        // 227.624 từ /usr/share/dict/words đều y nguyên) mà làm hỏng 803/9.844
        // tên riêng camelCase — và hỏng theo kiểu MẤT CHỮ: "dataAccess" →
        // "datccess", "photoObject" → "photObject", "LeEm" → "Lêm".
        let khopHoaThuong: [Character] = char.isUppercase ? [chuHoa] : [chuThuong, chuHoa]
        if !dangDungNguyenAmBa,
          thanhPhan.nguyenAmChua1KyTu(mangKyTu: khopHoaThuong)
        {
          // Âm tiết ĐÃ mang dấu MŨ/MÓC thì gõ lặp nguyên âm gần như chắc chắn là
          // kéo dài kiểu chat ("chưaaa"), không phải lệnh đặt mũ — cho ký tự rơi
          // xuống push thô. Quan trọng với vkey vì mỗi từ chỉ giữ MỘT dauMu: áp
          // mũ ở đây không chỉ sai mà còn XOÁ dấu móc đã đúng ("chưa" + a →
          // "chuâ", mất luôn chữ ư).
          //
          // Ngoại lệ .muUp: đó chính là đường huỷ mũ aaa/ooo/eee (toggle về
          // .khongMu), phải giữ nguyên.
          let daCoMuHoacMoc = state.dauMu != .khongMu && state.dauMu != .muUp

          // Âm tiết đã mang dấu THANH: KHÔNG chặn cả nhánh nữa. Chặn hết thì mất
          // nguyên lối gõ "phím thanh trước, phím mũ sau" — `tifeen`→tiền,
          // `vijeec`→việc, `biseet`→biết, `xusaat`→xuất, `cujooc`→cuộc,
          // `khusyeen`→khuyến… Đo trên 5.622 âm tiết có dấu của corpus: chặn hết
          // làm hỏng thêm 557 âm tiết, gần trọn nhóm nhân iê/uô/yê/uyê.
          //
          // Mở đúng lối đó, không mở hơn: chỉ nhận là lệnh đặt mũ khi phím này
          // gõ ĐÔI LIỀN KỀ với một chữ CŨNG gõ SAU phím thanh.
          //   • `tifeen` — "ti" + f + e + e: cặp "ee" nằm hẳn sau phím thanh,
          //     không đọc thành kéo dài kiểu chat được ⇒ đặt mũ.
          //   • `quasa` — "qua" + s + a: chữ 'a' mới ghép với chữ 'a' có TRƯỚC
          //     phím thanh. Đây là kéo dài kiểu chat; áp mũ sẽ phá dấu sắc thành
          //     "quấ" ⇒ vẫn chặn (có test khoá).
          //   • `define` — "de" + f + i + n + e: 'e' cuối không kề chữ 'e' nào,
          //     là gõ mũ TRỄ. Với âm tiết đã có thanh thì lối trễ này gần như chỉ
          //     gặp ở từ tiếng Anh nên vẫn chặn; nới cả nó ra làm hỏng thêm 129
          //     từ trong /usr/share/dict/words, còn siết như đây chỉ hỏng 4
          //     (fusee, puree, tureen, usee).
          // Chữ được ghép đôi là ký tự cuối chuỗi, ở vị trí chuKhongDau.count-1;
          // nó gõ sau phím thanh khi count-1 >= viTriGoDauThanh.
          let goDoiLienKe = state.chuKhongDau.last == chuThuong
            || state.chuKhongDau.last == chuHoa
          let chuGhepDoiGoSauPhimThanh =
            state.chuKhongDau.count > state.viTriGoDauThanh
          let daCoThanhChanMu = state.dauThanh != .bang
            && !(goDoiLienKe && chuGhepDoiGoSauPhimThanh)

          if !daCoMuHoacMoc, !daCoThanhChanMu {
            return (state.withMu(.muUp), true)
          }
        }

      // Phím w: dấu móc (ơ, ư) hoặc dấu trăng (ă) tùy nguyên âm
      case "w", "W":
        // Chữ 'u' hiện tại do chính phím `w` trước đó TỰ SINH (Telex cổ điển,
        // allowedZWJF tắt) ⇒ phím `w` này là gõ đúp để HUỶ, không phải lệnh móc.
        // Thả xuống push thô để chuỗi hiện đúng phím đã gõ ("ww"→"ww",
        // "tww"→"tww", "www"→"www" khi gõ URL); trước đây nhánh dưới chỉ toggle
        // tắt móc nên chữ 'u' giả ở lại → "uw"/"tuw"/"uww".
        if state.nguyenAmTuSinhTuW {
          break
        }
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["u", "U"]) {
          // Phím `w` thứ hai của cụm "uo" là của chữ 'o' → giữ móc, không toggle
          // tắt (dduwow → được). Luật nay nằm ở TiengVietState để VNI dùng chung.
          if let giuNguyen = state.giuMuMocTrenUO() {
            return (giuNguyen, true) // Keep horn, mark as applied
          }
          // uw → ư (móc)
          return (state.withMu(.muMoc), true)
        } else if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          // aw → ă (trăng)
          return (state.withMu(.muNgua), true)
        } else if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["o", "O"]) {
          // ow → ơ (móc)
          return (state.withMu(.muMoc), true)
        }

      default:
        break
      }
    }

    // v2.13: Telex cổ điển khi allowedZWJF TẮT — w không còn là phụ âm đầu
    // loanword nên "w" đứng không (chưa có nguyên âm) = ư: "w"→ư, "tw"→tư,
    // "nhw"→như. Khi allowedZWJF BẬT giữ nguyên w để gõ loanword ("web").
    // Implement bằng push("u") + muMoc — cùng đường với "uw"→ư nên mọi
    // transform/validate phía sau hoạt động y hệt.
    if (char == "w" || char == "W"),
      thanhPhan.nguyenAm.isEmpty,
      !Defaults[.allowedZWJF]
    {
      let base: Character = (char == "W") ? "U" : "u"
      return (state.push(base, tuSinhTuW: true).withMu(.muMoc), true)
    }

    // Không áp dụng dấu, thêm ký tự như bình thường
    return (state.push(char), false)
  }

  /// Xóa ký tự cuối cùng
  public func pop(state: TiengVietState) -> TiengVietState {
    state.pop()
  }
}
