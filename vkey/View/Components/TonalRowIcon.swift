//
//  TonalRowIcon.swift
//  vkey
//
//  v2.3.4: Tonal theme — flat colored row-icon tile per design CSS
//  `.row__icon` (`vkey-design-system/components.css`):
//
//      .row__icon {
//        width: 32px; height: 32px;
//        border-radius: 8px;
//        background: var(--bg-sunken);  /* ink-600 in dark mode */
//        color: var(--fg-accent);       /* red-500 brand */
//      }
//
//  KHÁC với GlassTile (LG theme — 3D glass với gradient + gloss + specular):
//  - TonalRowIcon FLAT, không gradient
//  - Sunken background (darker than row bg) → subtle "inset" appearance
//  - Red brand accent cho icon — đồng nhất theo Tonal palette
//  - Subtle shadow inset (1pt) cho cảm giác recessed
//
//  Usage:
//    TonalRowIcon(size: 28) {
//      Image(systemName: "gear").font(.system(size: 14))
//    }
//

import SwiftUI

struct TonalRowIcon<Content: View>: View {
    let size: CGFloat
    let radius: CGFloat
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    /// Default size 28pt với radius 7pt (8/32 ratio per design — squircle).
    init(size: CGFloat = 28,
         radius: CGFloat? = nil,
         @ViewBuilder content: () -> Content)
    {
        self.size = size
        self.radius = radius ?? max(5, size * 8 / 32)
        self.content = content()
    }

    /// Background sunken color — darker than parent row bg cho effect "inset".
    /// Dark mode: ink-600 (#0E0F12) opacity 0.85.
    /// Light mode: paper-100 (#F2EFE8) opacity 1.0.
    private var sunkenBackground: Color {
        colorScheme == .dark
            ? Color(hex: 0x0E0F12).opacity(0.85)
            : Color(hex: 0xF2EFE8)
    }

    /// Icon foreground accent — red-500 brand cả 2 mode.
    /// Dark mode dùng red-300 (lighter) cho contrast tốt hơn trên dark bg.
    private var iconAccent: Color {
        colorScheme == .dark
            ? VKeyDesign.red300
            : VKeyDesign.red500
    }

    /// Border subtle — same as design `--border-1`.
    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06)
    }

    var body: some View {
        ZStack {
            // ─── Sunken tile background ─────────────────────────────
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(sunkenBackground)

            // ─── Icon content with red accent ───────────────────────
            content
                .foregroundColor(iconAccent)
        }
        .frame(width: size, height: size)
        // ─── Border subtle ──────────────────────────────────────
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
        // ─── Inner inset shadow (subtle, để feel "sunken") ──────
        // SwiftUI không có native inset shadow, dùng overlay với
        // gradient mỏng để mô phỏng — top edge darker, bottom edge lighter.
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.black.opacity(0.25), Color.white.opacity(0.04)]
                            : [Color.black.opacity(0.08), Color.white.opacity(0.20)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
                .blendMode(.overlay)
                .allowsHitTesting(false)
        )
    }
}
