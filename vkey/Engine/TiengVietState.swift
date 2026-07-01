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
  /// Cached parsed syllable components (computed once per state)
  private let _cachedThanhPhan: ThanhPhanTieng?

  /// State rỗng - điểm khởi đầu
  static let empty = TiengVietState(
    chuKhongDau: [],
    dauThanh: .bang,
    dauMu: .khongMu,
    gachD: false,
    cachedThanhPhan: ThanhPhanTieng(phuAmDau: [], nguyenAm: [], phuAmCuoi: [], conLai: [])
  )

  /// Internal initializer with cached thanhPhan
  private init(
    chuKhongDau: [Character],
    dauThanh: DauThanh,
    dauMu: DauMu,
    gachD: Bool,
    cachedThanhPhan: ThanhPhanTieng?
  ) {
    self.chuKhongDau = chuKhongDau
    self.dauThanh = dauThanh
    self.dauMu = dauMu
    self.gachD = gachD
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
    
    let finalDauThanh = (dauThanh == .bang) ? (thanhPhanTieng.uuTienDauThanh ?? dauThanh) : dauThanh

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
  /// 2.0 (A6): nếu user bật Free Mark Mode (`freeMarkModeEnabled`), bỏ
  /// qua validator — cho phép đặt dấu ở vị trí bất kỳ, không kiểm tra
  /// cấu trúc âm tiết. Hữu ích cho linguist, tên riêng, tiếng dân tộc.
  ///
  /// v4.6 FIX: NGOẠI LỆ cho input camelCase/hoa-thường lẫn lộn (vd "DaoTao",
  /// "BaoCao") — đó là văn bản NHIỀU âm tiết, KHÔNG phải một âm tiết để đặt dấu.
  /// Nếu Free Mark Mode nuốt recovery ở đây, engine sẽ bịa dấu (Telex 'a' làm mũ:
  /// "DaoTa"→"DaôT") rồi phát replacement (xoá+gõ lại) — với dấu đa-scalar + gửi
  /// bất đồng bộ, hiển thị bị hỏng thành "DaoTaao". Có ranh giới hoa/thường giữa
  /// chừng ⇒ vẫn recover như chế độ thường (giữ nguyên chữ gõ).
  var needsRecovery: Bool {
    let structural = TiengVietValidator.needsRecovery(thanhPhanTieng, dauMu: dauMu)
    if Defaults[.freeMarkModeEnabled] {
      return hasInternalCaseBoundary ? structural : false
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
  func push(_ letter: Character) -> TiengVietState {
    let newChuKhongDau = chuKhongDau + [letter]
    return TiengVietState(
      chuKhongDau: newChuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: gachD,
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

    if newThanhPhan.nguyenAm.isEmpty {
      newDauMu = .khongMu
      newDauThanh = .bang
    }

    return TiengVietState(
      chuKhongDau: newChuKhongDau,
      dauThanh: newDauThanh,
      dauMu: newDauMu,
      gachD: gachD,
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
      cachedThanhPhan: _cachedThanhPhan
    )
  }

  /// Trả về state mới với danh sách phím được cập nhật
  func withChuKhongDau(_ keys: [Character]) -> TiengVietState {
    TiengVietState(
      chuKhongDau: keys,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: gachD,
      cachedThanhPhan: TiengVietParser.parse(
        keys,
        autoTypoCorrection: Defaults[.autoTypoCorrection]
      )
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
}
