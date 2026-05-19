//
//  DefaultMacros.swift
//  vkey
//
//  Bộ macro seed sẵn cho user mới (1.5.3+). Mục tiêu: user lần đầu mở
//  app có sẵn vài macro văn phòng VN để gõ thử + biết tính năng tồn tại.
//
//  Seed CHỈ chạy 1 lần trong `AppDelegate.applicationDidFinishLaunching`:
//  - Khi `Defaults[.macrosSeeded] == false` AND `Defaults[.macros].isEmpty`.
//  - Sau khi seed: `macrosSeeded = true`. Lần sau dù user xoá hết
//    macro vẫn không re-seed (tôn trọng ý user).
//
//  Đã loại trừ các viết tắt có khả năng conflict với cấu trúc gõ Telex/VNI
//  thường dùng (vd `tt` có thể là phần đầu của "tốt", đã bỏ).
//

import Foundation

enum DefaultMacros {
  static let officeVN: [Macro] = [
    Macro(from: "vn",    to: "Việt Nam"),
    Macro(from: "tv",    to: "Tiếng Việt"),
    Macro(from: "hn",    to: "Hà Nội"),
    Macro(from: "sg",    to: "Sài Gòn"),
    Macro(from: "dn",    to: "Đà Nẵng"),
    Macro(from: "tphcm", to: "Thành phố Hồ Chí Minh"),
    Macro(from: "kg",    to: "Kính gửi"),
    Macro(from: "kn",    to: "Kính nhờ"),
    Macro(from: "bcao",  to: "Báo cáo"),
    Macro(from: "cvan",  to: "Công văn"),
    Macro(from: "qdinh", to: "Quyết định"),
    Macro(from: "tbao",  to: "Thông báo"),
    Macro(from: "sdt",   to: "Số điện thoại"),
    Macro(from: "dchi",  to: "Địa chỉ"),
    Macro(from: "ttin",  to: "Thông tin"),
    Macro(from: "cty",   to: "Công ty"),
    Macro(from: "gd",    to: "Giám đốc"),
    Macro(from: "nv",    to: "Nhân viên"),
    Macro(from: "xc",    to: "Xin chào"),
  ]
}
