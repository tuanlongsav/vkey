//
//  VKeyDesign.swift
//  vkey
//
//  Tàn dư của hệ design "Tonal" (v2.1.0). Hệ đang dùng là `VK`
//  (View/Redesign/VKDesign.swift) — 350+ call-site so với 10 ở đây.
//
//  File này chỉ còn những thứ `VK` CHƯA có tương đương:
//  - `display(_:weight:)`: font Noto Sans Display cho HUD. `VK.Font.sans`
//    đọc phông theo lựa chọn của user nên KHÔNG thay thế được 1-1.
//  - `lgGlass1Color` / `lgRefractiveStrength`: hằng Liquid Glass cho HUD.
//
//  Bốn màu còn lại (red300/red500/ink500/lgBlueTint) trùng giá trị tuyệt đối
//  với `VK.Palette.red300/.red500/.ink500` và `VK.Palette.info`. Giữ ở đây để
//  HUD không phải kéo theo cả `VK` (vốn đọc Defaults theo theme); khi nào gộp
//  hai hệ thì xoá cả file.
//
//  52 token còn lại của bảng gốc đã bị xoá vì không call-site nào dùng.
//

import AppKit
import SwiftUI

enum VKeyDesign {

    /// Brand red nhạt — HUD prediction "đã hết hạn" + icon hàng Tonal ở dark.
    static let red300 = Color(hex: 0xF18A74)
    /// Primary brand red — icon hàng Tonal ở light.
    static let red500 = Color(hex: 0xE04434)
    /// Nền tối nhất — scrim của HUD prediction.
    static let ink500 = Color(hex: 0x131519)

    /// Liquid Glass primary panel scrim (`rgba(20,22,28,0.55)`).
    static let lgGlass1Color = Color(hex: 0x14161C)
    /// Refractive corner tint accent (vkey blue) cho soft-light glow.
    static let lgBlueTint = Color(hex: 0x2D89E5)
    /// Refractive corner tint strength — design spec: 24% red bottom-left.
    static let lgRefractiveStrength: Double = 0.24

    /// Display heading cho HUD. Ưu tiên Noto Sans Display (bundled qua
    /// `vkey/Resources/`); fallback system rounded nếu font không load được
    /// (Info.plist auto-register fail + runtime `FontRegistration` cũng fail).
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        // NSFont(name:size:) trả nil nếu font name không có ở system — dùng để
        // phân biệt font đã register với system fallback.
        if NSFont(name: "NotoSansDisplay", size: size) != nil {
            return Font.custom("NotoSansDisplay", size: size).weight(weight)
        }
        return Font.system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Color hex initializer

extension Color {
    /// Build a `Color` from an `0xRRGGBB` hex literal.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b, opacity: opacity)
    }
}
