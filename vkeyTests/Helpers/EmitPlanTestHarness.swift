import Foundation
@testable import vkey

/// Một bước phát, so sánh được. `scalars` CÓ MẶT CÓ LÝ DO: Swift so sánh `String`
/// theo TƯƠNG ĐƯƠNG CHUẨN TẮC, nên "ếng" dạng NFC `==` "ếng" dạng NFD — mà chính
/// hai dạng đó mới là thứ đi ra dây. Thiếu số scalar thì test mù đúng chỗ cần nhìn.
struct T3EmitStep: Equatable, CustomStringConvertible {
  let bs: Int
  let text: String
  let scalars: Int
  init(_ bs: Int, _ chars: [Character]) {
    self.bs = bs
    let s = String(chars)
    self.text = s
    self.scalars = s.unicodeScalars.count
  }

  /// Init cho BẢNG VÀNG đo trên HEAD (`HeadParityGoldenTests`). `text` viết ở dạng
  /// NFC trong source cho dễ đọc, còn `scalars` ghi RỜI — đó là chỗ duy nhất phân
  /// biệt hai trục, vì `==` của `String` so theo tương đương chuẩn tắc nên không
  /// nhìn ra dạng. Đừng "dọn" nó thành `T3EmitStep(bs, Array(text))`: làm thế là
  /// tự tính lại `scalars` từ literal NFC ⇒ mọi dòng vàng NFD hoá thành NFC và
  /// bảng hết khoá được gì.
  init(golden bs: Int, _ text: String, scalars: Int) {
    self.bs = bs
    self.text = text
    self.scalars = scalars
  }

  var description: String { "(bs=\(bs), \"\(text)\", \(scalars) scalar)" }
}

// ⚠️ CÁCH ĐỌC MỘT DÒNG VÀNG. `scalars` có mặt vì Swift so sánh `String` theo TƯƠNG
// ĐƯƠNG CHUẨN TẮC: "ếng" dạng NFC `==` "ếng" dạng NFD, mà chính hai dạng đó mới là
// thứ đi ra dây. Chuỗi trong bảng viết ở dạng NFC cho dễ đọc; cột `scalars` là chỗ
// duy nhất phân biệt hai trục.
struct GoldenSeq {
  let word: String
  let result: String
  /// (backspaceCount, diff dạng NFC để đọc, SỐ SCALAR thật sự phát ra)
  let steps: [(Int, String, Int)]
}
