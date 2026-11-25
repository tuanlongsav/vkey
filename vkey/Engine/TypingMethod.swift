//
//  TypingMethod.swift
//  vkey
//
//  Created by KhanhIceTea on 27/02/2024.
//

import Foundation

/// TypingMethods - Các kiểu gõ tiếng Việt được hỗ trợ.
/// (`Defaults.Serializable` conformance nằm ở `App/Setting.swift` để `Engine/` thuần Foundation.)
enum TypingMethods: String, CaseIterable {
  case Telex = "Telex"
  case VNI = "VNI"
}

/// TypingMethod - Protocol cho các phương thức gõ tiếng Việt
protocol TypingMethod {
  /// Kiểm tra có nên dừng xử lý không (ví dụ: gõ đúp để hủy dấu)
  func shouldStopProcessing(keyStr: String) -> Bool

  /// Xử lý ký tự nhập vào - trả về state mới thay vì mutate
  func push(
    char: Character,
    state: TiengVietState,
    options: EngineOptions
  ) -> (state: TiengVietState, appliedMark: Bool)

  /// Xóa ký tự cuối cùng - trả về state mới
  func pop(state: TiengVietState, options: EngineOptions) -> TiengVietState
}

extension TypingMethod {
  func push(char: Character, state: TiengVietState) -> (state: TiengVietState, appliedMark: Bool) {
    push(char: char, state: state, options: .default)
  }

  func pop(state: TiengVietState, options: EngineOptions) -> TiengVietState {
    state.pop(options: options)
  }

  func pop(state: TiengVietState) -> TiengVietState {
    pop(state: state, options: .default)
  }

  /// Tiền xử lý dùng chung cho Telex và VNI:
  /// 1. Bỏ qua áp dấu khi `conLai` không rỗng.
  /// 2. Gạch D trực tiếp (`dd` / `d9`) ngay sau phụ âm đầu `d`/`D`.
  /// 3. Late D toggle ở cuối từ (`dinhjd` / `dinh9`).
  func tryCommonPushPrefix(
    char: Character,
    state: TiengVietState,
    dTriggerChars: Set<Character>,
    options: EngineOptions
  ) -> (state: TiengVietState, appliedMark: Bool)? {
    let thanhPhan = state.thanhPhanTieng

    if !thanhPhan.conLai.isEmpty {
      return (state.push(char, options: options), false)
    }

    if state.chuKhongDau.count == 1,
       let chuCaiDau = state.chuKhongDau.first,
       (chuCaiDau == "d" || chuCaiDau == "D"),
       dTriggerChars.contains(char)
    {
      return (state.withGachD(), true)
    }

    if let toggled = state.tryLateDToggle(char: char, triggerChars: dTriggerChars, options: options) {
      return (toggled, true)
    }

    return nil
  }
}
