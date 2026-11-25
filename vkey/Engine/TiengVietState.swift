//
//  TiengVietState.swift
//  vkey
//
//  Trạng thái bất biến của âm tiết tiếng Việt (Immutable state, pure Foundation)
//

import Foundation

/// TiengVietState - Container trạng thái bất biến
struct TiengVietState {
  let chuKhongDau: [Character]
  let dauThanh: DauThanh
  let dauMu: DauMu
  let gachD: Bool
  let daGoPhimDauThanh: Bool
  let viTriGoDauThanh: Int
  let nguyenAmTuSinhTuW: Bool
  private let _cachedThanhPhan: ThanhPhanTieng?

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

  var thanhPhanTieng: ThanhPhanTieng {
    _cachedThanhPhan ?? TiengVietParser.parse(chuKhongDau)
  }

  /// Chuỗi đã biến đổi với dấu tiếng Việt (mặc định dùng `EngineOptions.default`).
  var transformed: String {
    transformed(options: .default)
  }

  func transformed(options: EngineOptions) -> String {
    if isBlank { return "" }

    // Auto-correct missing 'ê' for "uyen", "uyet"
    var finalDauMu = dauMu
    let nguyenAmLower = String(thanhPhanTieng.nguyenAm).lowercased()
    if dauMu == .khongMu, nguyenAmLower == "uye", !thanhPhanTieng.phuAmCuoi.isEmpty {
      finalDauMu = .muUp
    }

    // Auto-correct missing 'ă' for "ak" final consonant (chỉ áp địa danh d/đ/l: Đắk, Lắk).
    let phuAmDauLower = String(thanhPhanTieng.phuAmDau).lowercased()
    if dauMu == .khongMu, nguyenAmLower == "a",
       String(thanhPhanTieng.phuAmCuoi).lowercased() == "k",
       phuAmDauLower == "d" || phuAmDauLower == "l" {
      finalDauMu = .muNgua
    }

    let finalDauThanh = (dauThanh == .bang && !daGoPhimDauThanh)
      ? (thanhPhanTieng.uuTienDauThanh ?? dauThanh)
      : dauThanh

    return TiengVietTransformer.transform(
      thanhPhanTieng: thanhPhanTieng,
      dauThanh: finalDauThanh,
      dauMu: finalDauMu,
      gachD: gachD,
      kieuMoi: options.newStyleTonePlacement
    )
  }

  var isBlank: Bool { chuKhongDau.isEmpty }

  var needsRecovery: Bool {
    needsRecovery(options: .default)
  }

  func needsRecovery(options: EngineOptions) -> Bool {
    let structural = TiengVietValidator.needsRecovery(
      thanhPhanTieng, dauMu: dauMu, dauThanh: dauThanh, options: options)
    if options.freeMarkModeEnabled {
      let notSingleSyllable = hasInternalCaseBoundary || !thanhPhanTieng.conLai.isEmpty
      if notSingleSyllable { return structural }
      return TiengVietValidator.viPhamThanhNhap(thanhPhanTieng, dauThanh: dauThanh)
    }
    return structural
  }

  private var hasInternalCaseBoundary: Bool {
    var sawLower = false
    for ch in chuKhongDau {
      if ch.isLowercase { sawLower = true }
      else if ch.isUppercase && sawLower { return true }
    }
    return false
  }

  var originalInput: String {
    String(chuKhongDau)
  }
}

// MARK: - State Mutations (trả về state mới)

extension TiengVietState {

  func push(
    _ letter: Character,
    tuSinhTuW: Bool = false,
    options: EngineOptions = .default
  ) -> TiengVietState {
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
        autoTypoCorrection: options.autoTypoCorrection,
        allowedZWJF: options.allowedZWJF
      )
    )
  }

  func pop(options: EngineOptions = .default) -> TiengVietState {
    guard !chuKhongDau.isEmpty else { return self }

    let newChuKhongDau = Array(chuKhongDau.dropLast())
    let newThanhPhan = TiengVietParser.parse(
      newChuKhongDau,
      autoTypoCorrection: options.autoTypoCorrection,
      allowedZWJF: options.allowedZWJF
    )

    var newDauMu = dauMu
    var newDauThanh = dauThanh
    var newDaGoPhimDauThanh = daGoPhimDauThanh
    var newViTriGoDauThanh = min(viTriGoDauThanh, newChuKhongDau.count)

    if newThanhPhan.nguyenAm.isEmpty {
      newDauMu = .khongMu
      newDauThanh = .bang
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

  func withTone(_ tone: DauThanh) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh == tone ? .bang : tone,
      dauMu: dauMu,
      gachD: gachD,
      daGoPhimDauThanh: true,
      viTriGoDauThanh: chuKhongDau.count,
      nguyenAmTuSinhTuW: nguyenAmTuSinhTuW,
      cachedThanhPhan: _cachedThanhPhan
    )
  }

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

  /// Late D toggle: cho phép gõ phím gạch-d ("d" Telex / "9" VNI) ở cuối từ (`dinjhd` → `định`).
  func tryLateDToggle(
    char: Character,
    triggerChars: Set<Character>,
    options: EngineOptions = .default
  ) -> TiengVietState? {
    guard options.autoTypoCorrection,
      chuKhongDau.count >= 2,
      let chuCaiDau = chuKhongDau.first,
      chuCaiDau == "d" || chuCaiDau == "D",
      !gachD,
      triggerChars.contains(char),
      thanhPhanTieng.conLai.isEmpty,
      !thanhPhanTieng.nguyenAm.isEmpty
    else { return nil }
    return withGachD()
  }

  /// Phím dấu móc gõ lần thứ hai trên cụm nguyên âm "uo" (Telex `dduwow`, VNI `d9u7o7ng2`).
  func giuMuMocTrenUO() -> TiengVietState? {
    guard dauMu == .muMoc, thanhPhanTieng.chuaNguyenAmUO else { return nil }
    return self
  }
}
