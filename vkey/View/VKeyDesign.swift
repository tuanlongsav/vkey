//
//  VKeyDesign.swift
//  vkey
//
//  Design tokens for the "Tonal" theme (v2.1.0).
//  Single source of truth for brand colors, radii, spacing, fonts.
//  Mirrors `colors_and_type.css` from the vkey Design System.
//

import SwiftUI

// MARK: - Brand palette

enum VKeyDesign {

    // -- Brand red ----------------------------------------------------------
    static let red50  = Color(hex: 0xFEF1EE)
    static let red100 = Color(hex: 0xFCDED7)
    static let red200 = Color(hex: 0xF8B6A6)
    static let red300 = Color(hex: 0xF18A74)
    static let red400 = Color(hex: 0xEB6249)
    /// Primary brand red — anchor color used for toggles, accents, focus rings.
    static let red500 = Color(hex: 0xE04434)
    static let red600 = Color(hex: 0xC8341F)
    static let red700 = Color(hex: 0xA52817)
    static let red800 = Color(hex: 0x7E1F12)
    static let red900 = Color(hex: 0x561811)

    /// Convenience alias for `red500`.
    static var brand: Color { red500 }

    // -- Saigon gold (sparingly: VN flag star, "new" badges, highlights) ----
    static let gold300 = Color(hex: 0xFAD37A)
    static let gold400 = Color(hex: 0xF5C645)
    static let gold500 = Color(hex: 0xE5AE1C)
    static let gold600 = Color(hex: 0xB5860D)

    // -- Warm paper neutrals (light surfaces) -------------------------------
    static let paper0   = Color.white
    static let paper50  = Color(hex: 0xFAF8F4)
    static let paper100 = Color(hex: 0xF2EFE8)
    static let paper200 = Color(hex: 0xE6E1D6)
    static let paper300 = Color(hex: 0xD2CCBC)
    static let paper400 = Color(hex: 0xA8A293)
    static let paper500 = Color(hex: 0x7C7768)

    // -- Deep ink (dark surfaces) ------------------------------------------
    static let ink50  = Color(hex: 0x6A6E78)
    static let ink100 = Color(hex: 0x4B4F58)
    static let ink200 = Color(hex: 0x353841)
    static let ink300 = Color(hex: 0x24272E)
    static let ink400 = Color(hex: 0x1A1C22)
    static let ink500 = Color(hex: 0x131519) // dark bg
    static let ink600 = Color(hex: 0x0E0F12) // deeper dark
    static let ink700 = Color(hex: 0x08090B)

    // -- Semantic colors ----------------------------------------------------
    static let success    = Color(hex: 0x2BB673)
    static let warning    = Color(hex: 0xE5AE1C)
    static let danger     = Color(hex: 0xD9344A)
    static let info       = Color(hex: 0x2D89E5)

    // MARK: - Radii (matches CSS --r-*)

    static let radiusXS:  CGFloat = 4
    static let radiusSM:  CGFloat = 6
    static let radiusMD:  CGFloat = 10
    static let radiusLG:  CGFloat = 14
    static let radiusXL:  CGFloat = 20
    static let radius2XL: CGFloat = 28

    // MARK: - Spacing (4px base, matches CSS --s-*)

    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40

    // MARK: - Fonts

    /// UI body font — falls back to system Vietnamese-safe sans-serif if
    /// "Be Vietnam Pro" is not embedded yet.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    /// Display heading — used for hero / settings header.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }

    /// Mono — used for HUD prediction text, shortcuts.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
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
