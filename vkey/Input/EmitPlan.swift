//
//  EmitPlan.swift
//  vkey
//
//  Kế hoạch phát trọn vẹn cho một lần thay thế văn bản — ép bất biến v4.15
//  ("trục đếm backspace == trục phát") ở mức kiểu.
//

import Foundation

// MARK: - EmitPlan

/// TRỌN kế hoạch phát của MỘT lần thay thế: trục chuẩn hoá + đường gửi, dựng từ
/// MỘT phép đo field.
///
/// ⚠️ REFACTOR THUẦN KIỂU + một ngoại lệ F1: `WordBuffer.nfdEmitPlan` chốt NHÁNH
/// NFD sau lần gửi đầu tiên có `backspaceCount > 0` trong từ (xem
/// `InputProcessor.emitPlan()`). Ô ổn định vẫn phát giống hệt bản đo-mỗi-phím.
///
/// Bất biến v4.15 do KIỂU giữ: chỉ `EmitPlan` mới dựng được `EmitPlan.Replacement`,
/// mọi đường dựng đều đếm bằng CHÍNH trục của plan đó, và transport nhận
/// `normalizeToNFC` từ `replacement.plan` chứ không phải một tham số rời.
struct EmitPlan {
  /// Trục chuẩn hoá: `true` = đếm & phát theo NFC (grapheme), `false` = NFD (scalar).
  let usesNFC: Bool

  /// Ô đang focus là browser-chrome (omnibox Chromium) ⇒ phải gửi bằng `.axDirect`.
  /// Nằm cùng `usesNFC` trong một giá trị để hai vế luôn nhất quán từ một phép đo field.
  let fieldIsBrowserChrome: Bool

  /// Một lần thay thế ĐÃ ĐẾM XONG, mang theo chính kế hoạch đã đếm ra nó.
  struct Replacement {
    let plan: EmitPlan
    let backspaceCount: Int
    let diffChars: [Character]

    /// `fileprivate`: chỉ các factory của `EmitPlan` mới dựng được — đó là thứ
    /// biến bất biến v4.15 thành ràng buộc kiểu.
    fileprivate init(plan: EmitPlan, backspaceCount: Int, diffChars: [Character]) {
      self.plan = plan
      self.backspaceCount = backspaceCount
      self.diffChars = diffChars
    }

    /// Không có gì để gửi (transport cũng sẽ no-op).
    var isEmpty: Bool { backspaceCount == 0 && diffChars.isEmpty }
  }

  /// Đếm bằng ĐÚNG trục sẽ dùng để phát. Đây là đường dựng chính.
  func replacement(from: String, to: String) -> Replacement {
    let (backspaceCount, diffChars) = TextDiff.calcKeyStrokes(
      from: from, to: to, usesNFC: usesNFC)
    return Replacement(plan: self, backspaceCount: backspaceCount, diffChars: diffChars)
  }

  /// Chèn thuần, không xoá gì (lưới an toàn của auto-capitalize).
  func insertion(of chars: [Character]) -> Replacement {
    Replacement(plan: self, backspaceCount: 0, diffChars: chars)
  }

  /// Cầu nối DUY NHẤT cho số đếm được tính ở nơi khác — chỉ `WordBuffer.pop`,
  /// vốn phải replay state TRƯỚC khi đếm nên không đếm hộ được từ đây.
  /// `fileprivate` để cây gọi còn đúng một chỗ: `InputProcessor.pop(plan:)`,
  /// nơi truyền `plan.usesNFC` vào chính lần đếm đó.
  fileprivate func replacement(counted: (Int, [Character])) -> Replacement {
    Replacement(plan: self, backspaceCount: counted.0, diffChars: counted.1)
  }
}

// MARK: - InputProcessor Bridge

extension InputProcessor {
  /// Pop THEO KẾ HOẠCH — trục dùng để replay/đếm bên trong `WordBuffer.pop`
  /// là chính trục sẽ phát ra. Đây là cầu nối duy nhất giữa `WordBuffer` và `EmitPlan`.
  func pop(plan: EmitPlan) -> EmitPlan.Replacement {
    plan.replacement(counted: wordBuffer.pop(engine: engine, usesNFC: plan.usesNFC))
  }
}
