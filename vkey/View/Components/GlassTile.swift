//
//  GlassTile.swift
//  vkey
//
//  v2.3.3: Liquid Glass tile — multi-stop gradient + diagonal gloss +
//  top-arc specular highlight + white rim + drop shadow. Match design
//  `.tile` từ glass.css. Drop-in wrapper cho mọi icon ở LG theme.
//
//  Bản port từ thiết kế gốc `SwiftSnippets.jsx` (handoff Liquid Glass).
//  7 màu preset map theo category: red/gold/blue/green/purple/gray/ink.
//
//  Usage:
//    GlassTile(color: .blue, size: 24) {
//      Image(systemName: "switch.2").font(.system(size: 13))
//    }
//

import SwiftUI

/// v2.3.3: TileColor extracted thành top-level enum (out of generic struct)
/// để gọi từ ThemedSymbol mà không cần specify `GlassTile<SomeView>.TileColor`.
/// 7 màu preset map theo category trong design system.
enum GlassTileColor: String, CaseIterable {
    case red, gold, blue, green, purple, gray, ink

    /// Multi-stop gradient stops — top-light → mid-color → bottom-shadow.
    /// Match `.tile--red/gold/...` từ glass.css.
    fileprivate var stops: (top: Color, mid: Color, bot: Color) {
        switch self {
        case .red:    return (Color(hex: 0xFF7468), Color(hex: 0xE04434), Color(hex: 0x8A1F12))
        case .gold:   return (Color(hex: 0xFFE079), Color(hex: 0xF0A23C), Color(hex: 0x6E4A0B))
        case .blue:   return (Color(hex: 0x6FB5FF), Color(hex: 0x2D89E5), Color(hex: 0x143F74))
        case .green:  return (Color(hex: 0x7CDCAF), Color(hex: 0x2BB673), Color(hex: 0x114D31))
        case .purple: return (Color(hex: 0xC79BFF), Color(hex: 0x8B5CF6), Color(hex: 0x3B1C7A))
        case .gray:   return (Color(hex: 0xC2C5CF), Color(hex: 0x6A6D78), Color(hex: 0x1D1F25))
        case .ink:    return (Color(hex: 0x4B4F58), Color(hex: 0x24272E), Color(hex: 0x08090B))
        }
    }

    /// Linear-160deg gradient mô phỏng spherical lighting.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [stops.top, stops.mid, stops.bot],
            startPoint: UnitPoint(x: 0.25, y: 0),
            endPoint: UnitPoint(x: 0.75, y: 1)
        )
    }
}

struct GlassTile<Content: View>: View {
    typealias TileColor = GlassTileColor

    let color: TileColor
    let size: CGFloat
    let radius: CGFloat
    let content: Content

    /// Default size 24pt — match design system menu item tile.
    /// Radius scales 7/24 ratio để giữ "squircle" proportion ở mọi size.
    init(color: TileColor,
         size: CGFloat = 24,
         radius: CGFloat? = nil,
         @ViewBuilder content: () -> Content)
    {
        self.color = color
        self.size = size
        self.radius = radius ?? max(5, size * 7 / 24)
        self.content = content()
    }

    var body: some View {
        ZStack {
            // ─── Base body (multi-stop gradient) ────────────────────
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color.gradient)

            // ─── Diagonal gloss highlight (top-left → bottom-right) ──
            // Match `.tile::before` `linear-gradient(160deg)`.
            LinearGradient(
                colors: [
                    Color.white.opacity(0.40),
                    Color.white.opacity(0.08),
                    Color.black.opacity(0.15),
                ],
                startPoint: UnitPoint(x: 0.2, y: 0),
                endPoint: UnitPoint(x: 0.8, y: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

            // ─── Top arc specular highlight (ellipse) ───────────────
            // Match `.tile::after` — half-ellipse "wet" gloss hugging top.
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: size * 0.75, height: size * 0.42)
                .offset(y: -size * 0.22)
                .opacity(0.7)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

            // ─── Icon content (white tint + tiny double shadow) ─────
            // Match design — icon glyph màu trắng + white sub-pixel glow
            // dưới (specular từ tile body) + black drop shadow nhẹ.
            content
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.4), radius: 0.5, y: 0.5)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
        }
        .frame(width: size, height: size)
        // ─── White rim border ───────────────────────────────────
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        // ─── Outer drop shadow (subtle floating) ────────────────
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1.5)
    }
}

// MARK: - Environment opt-in flag

/// v2.3.3: opt-in env flag — chỉ những context EXPLICITLY enable
/// `\.useGlassTile = true` thì ThemedSymbol mới wrap trong GlassTile khi
/// LG active. Default false → MenuBar status icon, HUD, Tonal/Classic
/// không bị ảnh hưởng. Set true ở MenuContentView root + Settings root.
private struct UseGlassTileKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var useGlassTile: Bool {
        get { self[UseGlassTileKey.self] }
        set { self[UseGlassTileKey.self] = newValue }
    }
}
