//
//  TiengVietState.swift
//  vkey
//
//  Trạng thái bất biến của âm tiết tiếng Việt (Immutable state)
//

import Foundation
import Defaults

/// TiengVietState - Container trạng thái bất biến
///
/// Mọi thay đổi trạng thái đều trả về instance mới, đảm bảo tính nhất quán
/// và dễ debug (có thể so sánh state trước/sau).
///
/// Sử dụng:
/// ```swift
/// let state = TiengVietState.empty
///   .push("t").push("o").push("i")  // "toi"
///   .withTone(.sac)                  // "tói"
///   .withMu(.muUp)                   // "tôi" → "tối"
/// ```
struct TiengVietState {
  /// Chuỗi ký tự gốc chưa có dấu (đầu vào từ bàn phím)
  let chuKhongDau: [Character]
  /// Dấu thanh hiện tại (sắc, huyền, hỏi, ngã, nặng)
  let dauThanh: DauThanh
  /// Dấu mũ hiện tại (mũ, móc, trăng)
  let dauMu: DauMu
  /// Có gạch ngang chữ D không (d → đ)
  let gachD: Bool
  /// Người dùng đã tự gõ phím dấu thanh cho âm tiết này chưa (kể cả gõ đúp để
  /// HUỶ dấu về .bang). Dùng để biết `dauThanh == .bang` là "chưa ai đặt dấu"
  /// hay "vừa bị huỷ có chủ ý" — xem `transformed`.
  let daGoPhimDauThanh: Bool
  /// `chuKhongDau.count` tại thời điểm bấm phím dấu thanh gần nhất (-1 = chưa
  /// bấm). Cho biết một ký tự nào đó được gõ TRƯỚC hay SAU phím thanh: ký tự ở
  /// vị trí `i` là gõ sau phím thanh khi `i >= viTriGoDauThanh`.
  ///
  /// Cần để phân biệt hai lối gõ nhìn giống hệt nhau ở `Telex.push` — xem nhánh
  /// "aa/ee/oo" ở đó: `quasa` (lặp lại chữ có TRƯỚC phím thanh = kéo dài kiểu
  /// chat) và `tifeen` (cặp `ee` gõ HẲN SAU phím thanh = lệnh đặt mũ của "tiền").
  let viTriGoDauThanh: Int
  /// Nguyên âm cuối chuỗi là chữ 'u' do ENGINE tự sinh từ phím `w` (Telex cổ
  /// điển khi `allowedZWJF` tắt: "w" → ư), không phải người dùng gõ. Cần nhớ để
  /// phím `w` kế tiếp được hiểu là gõ đúp huỷ chứ không phải lệnh đặt móc —
  /// xem `Telex.push`.
  let nguyenAmTuSinhTuW: Bool
  /// Cached parsed syllable components (computed once per state)
  private let _cachedThanhPhan: ThanhPhanTieng?

  /// State rỗng - điểm khởi đầu
  static let empty = TiengVietState(
    chuKhongDau: [],
    dauThanh: .bang,
    dauMu: .khongMu,
    gachD: false,
    daGoPhimDauThanh: false,
    viTriGoDauThanh: -1,
    nguyenAmTuSinhTuW: false,
    cachedThanhPhan: ThanhPhanTieng(phuAmDau: [], nguyenAm: [], phuAmCuoi: [], conLai: [])
  )

  /// Internal initializer with cached thanhPhan
  private init(
    chuKhongDau: [Character],
    dauThanh: DauThanh,
    dauMu: DauMu,
    gachD: Bool,
    daGoPhimDauThanh: Bool,
    viTriGoDauThanh: Int,
    nguyenAmTuSinhTuW: Bool,
    cachedThanhPhan: ThanhPhanTieng?
  ) {
    self.chuKhongDau = chuKhongDau
    self.dauThanh = dauThanh
    self.dauMu = dauMu
    self.gachD = gachD
    self.daGoPhimDauThanh = daGoPhimDauThanh
    self.viTriGoDauThanh = viTriGoDauThanh
    self.nguyenAmTuSinhTuW = nguyenAmTuSinhTuW
    self._cachedThanhPhan = cachedThanhPhan
  }

  // MARK: - Computed Properties

  /// Các thành phần âm tiết đã phân tích - cached để tránh parse lại nhiều lần.
  ///
  /// `TiengVietState` là điểm đọc Defaults duy nhất; Parser nhận cờ qua tham số
  /// để giữ thuần (testable mà không cần stub Defaults).
  var thanhPhanTieng: ThanhPhanTieng {
    _cachedThanhPhan ?? TiengVietParser.parse(
      chuKhongDau,
      autoTypoCorrection: Defaults[.autoTypoCorrection]
    )
  }

  /// Chuỗi đã biến đổi với dấu tiếng Việt
  var transformed: String {
    if isBlank { return "" }
    
    // Auto-correct missing 'ê' for "uyen", "uyet"
    var finalDauMu = dauMu
    let nguyenAmLower = String(thanhPhanTieng.nguyenAm).lowercased()
    if dauMu == .khongMu, nguyenAmLower == "uye", !thanhPhanTieng.phuAmCuoi.isEmpty {
      finalDauMu = .muUp
    }
    
    // Auto-correct missing 'ă' for "ak" final consonant (ethnic minority names support like đắk, lắk).
    // CHỈ áp cho mẫu địa danh có phụ âm đầu d/đ/l (Đắk, Lắk) — KHÔNG áp cho mọi
    // âm tiết "a…k", nếu không "Dak/Zak/Mak/Nak/flak/tak/AK" bị đổi nhầm thành có dấu ă.
    let phuAmDauLower = String(thanhPhanTieng.phuAmDau).lowercased()
    if dauMu == .khongMu, nguyenAmLower == "a",
       String(thanhPhanTieng.phuAmCuoi).lowercased() == "k",
       phuAmDauLower == "d" || phuAmDauLower == "l" {
      finalDauMu = .muNgua
    }
    
    // `uuTienDauThanh` là dấu do Parser (Rule 5) TỰ SUY RA từ phím dấu đặt sai
    // chỗ ("thfi" → thì). Chỉ áp khi người dùng CHƯA tự gõ phím dấu cho âm tiết
    // này: trước đây áp vô điều kiện mỗi khi `dauThanh == .bang` nên thao tác gõ
    // đúp để huỷ dấu không bao giờ gỡ được dấu tự-suy-ra và phím dấu bị nuốt im
    // lặng ("thfiff" vẫn ra "thì", "mfass" ra "màs" thay vì "mas").
    let finalDauThanh = (dauThanh == .bang && !daGoPhimDauThanh)
      ? (thanhPhanTieng.uuTienDauThanh ?? dauThanh)
      : dauThanh

    return TiengVietTransformer.transform(
      thanhPhanTieng: thanhPhanTieng,
      dauThanh: finalDauThanh,
      dauMu: finalDauMu,
      gachD: gachD,
      kieuMoi: Defaults[.newStyleTonePlacement]
    )
  }

  /// Kiểm tra state có rỗng không
  var isBlank: Bool { chuKhongDau.isEmpty }

  /// Kiểm tra âm tiết có cần recovery không (không hợp lệ tiếng Việt)
  /// Khi true, nên dùng chuỗi gốc thay vì chuỗi đã biến đổi
  ///
  /// 2.0 (A6): nếu user bật Free Mark Mode (`freeMarkModeEnabled`), gần như toàn
  /// bộ validator được bỏ qua — đặt dấu ở vị trí nào cũng được, không soi cấu
  /// trúc âm tiết. Hữu ích cho linguist, tên riêng, tiếng dân tộc.
  ///
  /// "Gần như", KHÔNG phải "toàn bộ": kể từ v4.24 luật thanh nhập vẫn chạy (xem
  /// bên dưới). Docstring cũ viết "bỏ qua validator, không kiểm tra cấu trúc âm
  /// tiết" nên đọc xong sẽ tưởng Free Mark = tắt sạch — nay hành vi và tài liệu
  /// khớp lại.
  ///
  /// v4.6/v4.7 FIX: Free Mark Mode CHỈ được nuốt recovery cho MỘT âm tiết tiếng
  /// Việt sạch (đặt dấu tự do đúng mục đích). Với input KHÔNG phải một âm tiết
  /// đơn thì vẫn recover như chế độ thường, nếu không engine sẽ bịa dấu (Telex
  /// 'a'/'aa'/'oo' làm mũ) rồi phát replacement (xoá+gõ lại, dấu đa-scalar, gửi
  /// bất đồng bộ) làm hỏng hiển thị ở mọi app. Hai tín hiệu "không phải âm tiết đơn":
  ///   • `conLai` không rỗng — còn ký tự dư ⇒ nhiều âm tiết/loanword (vd "banana"
  ///     → "bânna", "cooperate" → "côperate"). (v4.7)
  ///   • có ranh giới hoa/thường giữa từ (camelCase "DaoTao", "BaoCao"). (v4.6)
  /// Cả hai đều recover về chữ gõ thô; đặt dấu tự do cho tên riêng/âm tiết đơn
  /// (conLai rỗng, không camelCase) vẫn hoạt động như trước.
  var needsRecovery: Bool {
    let structural = TiengVietValidator.needsRecovery(
      thanhPhanTieng, dauMu: dauMu, dauThanh: dauThanh)
    if Defaults[.freeMarkModeEnabled] {
      let notSingleSyllable = hasInternalCaseBoundary || !thanhPhanTieng.conLai.isEmpty
      if notSingleSyllable { return structural }
      // v4.24: Free Mark nới VỊ TRÍ đặt dấu (tên riêng, tiếng dân tộc), KHÔNG
      // được đẻ ra tổ hợp thanh × phụ-âm-tắc không tồn tại. Trước đây âm tiết
      // đơn chữ thường được miễn TOÀN BỘ validator nên bật Free Mark là "art"
      // ra "ảt", "soft" ra "sòt", "hurt" ra "hủt".
      //
      // Đánh đổi, đã đo đợt v4.24-fix: cái mất đi ĐÚNG BẰNG nhóm âm tiết kết
      // bằng c/ch/p/t/k mang huyền/hỏi/ngã — `hocr`, `latf`, `machx`, `hopf`,
      // `bakr` nay ra chuỗi phím thô thay vì "hỏc/làt/mãch/hòp/bảk". Chấp nhận:
      //   • Không mất chữ nào của tiếng Việt: chạy cả corpus 7.184 âm tiết với
      //     freeMark ON cho đúng con số như freeMark OFF (telex 58, vni 7 fail).
      //   • Chữ viết của các dân tộc dùng hệ Quốc ngữ (Ê Đê, Ba Na, Jrai, Hmông)
      //     cũng theo luật thanh nhập, nên nhóm mất đi không có từ thật.
      //   • Hỏng ra chuỗi phím THÔ, người gõ nhìn thấy ngay đúng phím mình bấm —
      //     không phải kiểu mất chữ âm thầm.
      // Việc "khoá thô nốt phần còn lại của từ" là hành vi chung của WordBuffer
      // cho MỌI needsRecovery, không riêng Free Mark; sửa ở đây sẽ lệch với chế
      // độ thường nên để nguyên.
      return TiengVietValidator.viPhamThanhNhap(thanhPhanTieng, dauThanh: dauThanh)
    }
    return structural
  }

  /// True nếu có chữ HOA đứng sau một chữ thường trong chuỗi gõ (ranh giới
  /// camelCase giữa từ, vd "DaoTao") — tín hiệu input là nhiều âm tiết/không phải
  /// một âm tiết tiếng Việt đơn.
  private var hasInternalCaseBoundary: Bool {
    var sawLower = false
    for ch in chuKhongDau {
      if ch.isLowercase { sawLower = true }
      else if ch.isUppercase && sawLower { return true }
    }
    return false
  }

  /// Chuỗi gốc (dùng khi cần recovery)
  var originalInput: String {
    String(chuKhongDau)
  }
}

// MARK: - State Mutations (trả về state mới)

extension TiengVietState {

  /// Thêm ký tự vào chuỗi đầu vào
  ///
  /// - Parameter tuSinhTuW: ký tự này do engine tự sinh từ phím `w` chứ không
  ///   phải người dùng gõ (Telex cổ điển "w" → ư). Mặc định false nên mọi lời
  ///   gọi cũ giữ nguyên nghĩa; xem `nguyenAmTuSinhTuW`.
  func push(_ letter: Character, tuSinhTuW: Bool = false) -> TiengVietState {
    let newChuKhongDau = chuKhongDau + [letter]
    return TiengVietState(
      chuKhongDau: newChuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: gachD,
      daGoPhimDauThanh: daGoPhimDauThanh,
      viTriGoDauThanh: viTriGoDauThanh,
      nguyenAmTuSinhTuW: tuSinhTuW,
      cachedThanhPhan: TiengVietParser.parse(
        newChuKhongDau,
        autoTypoCorrection: Defaults[.autoTypoCorrection]
      )
    )
  }

  /// Xóa ký tự cuối cùng
  func pop() -> TiengVietState {
    guard !chuKhongDau.isEmpty else { return self }

    let newChuKhongDau = Array(chuKhongDau.dropLast())
    let newThanhPhan = TiengVietParser.parse(
      newChuKhongDau,
      autoTypoCorrection: Defaults[.autoTypoCorrection]
    )

    // Reset dấu nếu không còn nguyên âm
    var newDauMu = dauMu
    var newDauThanh = dauThanh
    var newDaGoPhimDauThanh = daGoPhimDauThanh
    // Xoá bớt ký tự thì mốc "phím thanh bấm ở đâu" phải lùi theo, nếu không nó
    // vượt quá độ dài chuỗi và mọi ký tự còn lại bị coi là gõ TRƯỚC phím thanh.
    var newViTriGoDauThanh = min(viTriGoDauThanh, newChuKhongDau.count)

    if newThanhPhan.nguyenAm.isEmpty {
      newDauMu = .khongMu
      newDauThanh = .bang
      // Xoá hết nguyên âm ⇒ mọi dấu đã gõ cũng mất hiệu lực; quên luôn việc
      // người dùng từng gõ phím dấu, nếu không âm tiết gõ lại sẽ mất
      // `uuTienDauThanh`.
      newDaGoPhimDauThanh = false
      newViTriGoDauThanh = -1
    }

    return TiengVietState(
      chuKhongDau: newChuKhongDau,
      dauThanh: newDauThanh,
      dauMu: newDauMu,
      gachD: gachD,
      daGoPhimDauThanh: newDaGoPhimDauThanh,
      viTriGoDauThanh: newViTriGoDauThanh,
      nguyenAmTuSinhTuW: false,
      cachedThanhPhan: newThanhPhan
    )
  }

  /// Đặt/xóa dấu thanh (toggle: gõ cùng dấu 2 lần sẽ xóa)
  func withTone(_ tone: DauThanh) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh == tone ? .bang : tone,
      dauMu: dauMu,
      gachD: gachD,
      // Kể cả nhánh toggle về .bang: người dùng vừa CHỦ ĐỘNG huỷ dấu, phải ghi
      // nhận để `transformed` không dựng lại dấu tự-suy-ra của Parser.
      daGoPhimDauThanh: true,
      viTriGoDauThanh: chuKhongDau.count,
      nguyenAmTuSinhTuW: nguyenAmTuSinhTuW,
      cachedThanhPhan: _cachedThanhPhan
    )
  }

  /// Đặt/xóa dấu mũ (toggle: gõ cùng dấu 2 lần sẽ xóa)
  func withMu(_ mu: DauMu) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu == mu ? .khongMu : mu,
      gachD: gachD,
      daGoPhimDauThanh: daGoPhimDauThanh,
      viTriGoDauThanh: viTriGoDauThanh,
      nguyenAmTuSinhTuW: nguyenAmTuSinhTuW,
      cachedThanhPhan: _cachedThanhPhan
    )
  }

  /// Toggle gạch ngang D (d ↔ đ)
  func withGachD() -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: !gachD,
      daGoPhimDauThanh: daGoPhimDauThanh,
      viTriGoDauThanh: viTriGoDauThanh,
      nguyenAmTuSinhTuW: nguyenAmTuSinhTuW,
      cachedThanhPhan: _cachedThanhPhan
    )
  }

  /// Late D toggle: cho phép gõ phím gạch-d ("d" với Telex hoặc "9" với VNI)
  /// ở cuối từ để chuyển d → đ trên phụ âm đầu, ví dụ `dinjhd` → `định`.
  ///
  /// Trước Phase 1.6 logic này được lặp y hệt trong Telex/VNI; nay tập trung
  /// ở đây để hai engine cùng gọi và dễ test.
  ///
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - triggerChars: Tập ký tự kích hoạt (Telex: ["d","D"]; VNI: ["9"])
  /// - Returns: State mới sau khi áp gachD, hoặc nil nếu điều kiện không đủ
  func tryLateDToggle(char: Character, triggerChars: Set<Character>) -> TiengVietState? {
    guard Defaults[.autoTypoCorrection],
      chuKhongDau.count >= 2,
      let chuCaiDau = chuKhongDau.first,
      chuCaiDau == "d" || chuCaiDau == "D",
      !gachD,
      triggerChars.contains(char),
      // 1.7.7: gate "late D" toggle chặt hơn — chỉ trigger khi syllable
      // structure đã hoàn chỉnh (có vowel + không còn conLai/leftover).
      // Ngăn gạch D toggle sai trong giữa từ chưa hoàn chỉnh.
      // Vd "dungf" (telex của "dùng"): sau khi gõ "dung", thanhPhanTieng
      // có phuAmDau=d, vowel=u, phuAmCuoi=ng, conLai=[] — đáng lẽ KHÔNG
      // được trigger gạch D khi user gõ "f" sau. Trước fix, mọi char trong
      // triggerChars sẽ toggle dù không phải "d" cuối từ.
      thanhPhanTieng.conLai.isEmpty,
      !thanhPhanTieng.nguyenAm.isEmpty
    else { return nil }
    return withGachD()
  }

  /// Phím dấu móc gõ lần THỨ HAI trên cụm nguyên âm "uo" (Telex `dduwow`, VNI
  /// `d9u7o7ng2`): cụm "ươ" có hai nguyên âm mang móc nên lối gõ đầy đủ có hai
  /// phím móc, mà `dauMu` chỉ có MỘT ô — phím thứ hai rơi vào `withMu` sẽ
  /// TOGGLE TẮT móc vừa đặt ("nu7o7c1" → "nuóc" thay vì "nước").
  ///
  /// Trước đây guard này chỉ nằm trong `Telex.push` nên VNI dính trọn 235/7.184
  /// âm tiết "ươ" (được, người, trường, nước…). Tập trung ở đây theo đúng tiền
  /// lệ `tryLateDToggle` để hai engine dùng chung một luật.
  ///
  /// Không chặn mất đường huỷ móc: huỷ là hai phím móc KỀ NHAU ("ww" / "77"),
  /// do `shouldStopProcessing` lo, không đi qua đây.
  ///
  /// - Returns: chính state hiện tại (giữ nguyên móc), hoặc nil nếu không phải ca này.
  func giuMuMocTrenUO() -> TiengVietState? {
    guard dauMu == .muMoc, thanhPhanTieng.chuaNguyenAmUO else { return nil }
    return self
  }
}
