//
//  DefaultMacros.swift
//  vkey
//
//  Bộ macro seed sẵn cho user mới + danh sách migration cho user cũ.
//  Version 2 (1.5.5+): 14 office VN + 8 emoji + 12 ký hiệu = 34 entries.
//
//  Migration logic ở `AppDelegate.seedDefaultMacrosIfNeeded()` chạy 1
//  lần khi `Defaults[.defaultMacrosVersion] < 2`:
//  - First-launch ever (1.5.0+): seed sạch `allDefaults`.
//  - User 1.5.3/1.5.4 đã seed 19 entries cũ: dọn entries bỏ
//    (`obsoleteSeedsV1`) + rename (`renamedSeedsV1ToV2`) + add entries
//    mới còn thiếu.
//  - Sau khi xong, set `defaultMacrosVersion = 2`. Re-launch không
//    re-run.
//
//  User sửa `to` của 1 default seed: migration KHÔNG đụng (tôn trọng).
//

import Foundation

enum DefaultMacros {

  // MARK: - V2 seed sets (1.5.5+)

  /// 14 macro văn phòng theo file user gửi.
  /// Đổi từ 19 cũ (1.5.3/1.5.4): bỏ tv/dn/kg/kn/xc, đổi gd→gdoc, nv→nvien.
  static let officeVN: [Macro] = [
    Macro(from: "vn",    to: "Việt Nam"),
    Macro(from: "hn",    to: "Hà Nội"),
    Macro(from: "sg",    to: "Sài Gòn"),
    Macro(from: "tphcm", to: "Thành phố Hồ Chí Minh"),
    Macro(from: "bcao",  to: "Báo cáo"),
    Macro(from: "cvan",  to: "Công văn"),
    Macro(from: "qdinh", to: "Quyết định"),
    Macro(from: "tbao",  to: "Thông báo"),
    Macro(from: "sdt",   to: "Số điện thoại"),
    Macro(from: "dchi",  to: "Địa chỉ"),
    Macro(from: "ttin",  to: "Thông tin"),
    Macro(from: "cty",   to: "Công ty"),
    Macro(from: "gdoc",  to: "Giám đốc"),
    Macro(from: "nvien", to: "Nhân viên"),
  ]

  /// 8 emoji thường dùng. `from` chọn 4-5 ký tự chữ đôi để không trùng
  /// âm tiết Telex hợp lệ (vd "ok" → "ốc"; "okok" thì an toàn).
  static let emoji: [Macro] = [
    Macro(from: "okok",  to: "👌"),
    Macro(from: "vuiv",  to: "😀"),
    Macro(from: "yeuu",  to: "❤️"),
    Macro(from: "likee", to: "👍"),
    Macro(from: "dlike", to: "👎"),
    Macro(from: "hihi",  to: "😂"),
    Macro(from: "party", to: "🎉"),
    Macro(from: "prayy", to: "🙏"),
  ]

  /// 12 ký hiệu khoa học / toán. `from` chọn 3-4 ký tự không phải âm
  /// tiết Telex (vd `gte`, `xx2`, `inff`).
  static let symbols: [Macro] = [
    Macro(from: "gte",   to: "≥"),
    Macro(from: "lte",   to: "≤"),
    Macro(from: "neq",   to: "≠"),
    Macro(from: "deg",   to: "°"),
    Macro(from: "pm",    to: "±"),
    Macro(from: "inff",  to: "∞"),
    Macro(from: "pii",   to: "π"),
    Macro(from: "xx2",   to: "x²"),
    Macro(from: "xx3",   to: "x³"),
    Macro(from: "arr",   to: "→"),
    Macro(from: "ckok",  to: "✓"),
    Macro(from: "crs",   to: "✗"),
  ]

  /// Toàn bộ default seed v2 — dùng cho user mới chưa từng seed.
  static var allDefaults: [Macro] {
    officeVN + emoji + symbols
  }

  // MARK: - Migration metadata (v1 → v2)

  /// Seeds được đưa vào ở phiên bản 1.5.3/1.5.4 nay loại bỏ. Migration
  /// XOÁ CHỈ KHI user chưa sửa cả `from` và `to` của entry này — nếu user
  /// đã custom thì tôn trọng để nguyên.
  static let obsoleteSeedsV1: [(from: String, to: String)] = [
    ("tv", "Tiếng Việt"),
    ("dn", "Đà Nẵng"),
    ("kg", "Kính gửi"),
    ("kn", "Kính nhờ"),
    ("xc", "Xin chào"),
  ]

  /// Seeds đổi tên ở 1.5.5. Migration đổi CHỈ KHI tuple (oldFrom, oldTo)
  /// vẫn nguyên bản — nếu user đã sửa `from` hoặc `to` thì để nguyên.
  static let renamedSeedsV1ToV2: [(
    oldFrom: String, oldTo: String,
    newFrom: String, newTo: String
  )] = [
    ("gd", "Giám đốc",   "gdoc",  "Giám đốc"),
    ("nv", "Nhân viên",  "nvien", "Nhân viên"),
  ]
}
