//
//  HUDComponents.swift
//  vkey
//
//  v2.3.0: shared HUD primitives — extracted to avoid duplication between
//  ToggleHUDWindow + PredictionHUDWindow under both Liquid Glass and Tonal
//  themes.
//
//  Three primitives:
//    • Keycap            — mini glass pill rendering a shortcut key label
//                          (⌃ / ⇧ / Tab / etc). Two sizes md (28×28) / sm (22×20).
//    • HUDFlag           — 48×36 flag image (vn-flag / us-flag) with inner
//                          stroke + top-gloss + drop-shadow.
//    • refractiveGlassBackground(radius:scrimOpacity:) — View modifier that
//                          applies the 5-layer Liquid Glass recipe.
//    • tonalScrimBackground(radius:scrimOpacity:) — simpler Tonal variant
//                          (deep-ink scrim + thin stroke + soft shadow).
//

import SwiftUI

// MARK: - Keycap

/// Mini glass pill rendering a single keyboard symbol/word.
///
/// Used in:
/// - Toggle HUD keycap row (`⌃` `⇧` or whatever the active modifier-only
///   toggle hotkey is, e.g. `⇧⌥` for v2.0.2 default).
/// - Prediction HUD `Tab` chip (sm size).
///
/// Visual: rounded-rect with multi-layer glass background (top-bottom white
/// gradient + bottom inset shadow + 0.6pt inner stroke). Sits on a dark scrim
/// — same component renders correctly under both LG and Tonal HUD backgrounds.
struct Keycap: View {
    enum Size {
        case md  // 28×28, 12pt 600
        case sm  // 22×20, 10pt 600

        var height: CGFloat {
            switch self {
            case .md: return 28
            case .sm: return 20
            }
        }

        var minWidth: CGFloat {
            switch self {
            case .md: return 28
            case .sm: return 22
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .md: return 8
            case .sm: return 5
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .md: return 12
            case .sm: return 10
            }
        }

        var radius: CGFloat {
            switch self {
            case .md: return 8
            case .sm: return 6
            }
        }
    }

    let label: String
    let size: Size

    init(_ label: String, size: Size = .md) {
        self.label = label
        self.size = size
    }

    var body: some View {
        Text(label)
            .font(.system(size: size.fontSize, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.92))
            .frame(minWidth: size.minWidth, minHeight: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                // Top-bottom white glass gradient
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.04),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .blendMode(.plusLighter),
                in: RoundedRectangle(cornerRadius: size.radius, style: .continuous)
            )
            .background(
                // Base tint so keycap stays visible on lighter HUD scrims
                Color.black.opacity(0.18),
                in: RoundedRectangle(cornerRadius: size.radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
            )
            // Subtle bottom-inset shadow for "pressed-in" feel
            .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 1)
    }
}

// MARK: - HUDFlag

/// 48×36 flag image used as the leading icon of the toggle HUD.
///
/// Replaces the v2.0.x SF Symbol approach (`character.bubble.fill` / `keyboard`)
/// with the actual VN/US flag PNGs from `Assets.xcassets/{vn,us}-flag.imageset`.
/// Adds inner stroke + top-gloss overlay + drop-shadow per design handoff
/// `.hud-flag` spec.
struct HUDFlag: View {
    let isVietnamese: Bool

    init(_ isVietnamese: Bool) {
        self.isVietnamese = isVietnamese
    }

    var body: some View {
        Image(isVietnamese ? "vn-flag" : "us-flag")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: 48, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                // Top-gloss highlight
                LinearGradient(
                    colors: [Color.white.opacity(0.40), Color.white.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 18)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .allowsHitTesting(false)
            )
            .overlay(
                // Thin inner border
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Background modifiers

extension View {
    /// Apply the Liquid Glass refractive 5-layer background recipe.
    ///
    /// Layers (bottom-to-top in render order):
    /// 1. `.ultraThinMaterial` — system blur baseline
    /// 2. Scrim `lgGlass1Color` × `scrimOpacity` (dark anchor)
    /// 3. Linear gradient white(0.16)→white(0.02)→black(0.18) + radial spec
    ///    white(0.28) from top
    /// 4. Refractive corner tints: red500 at 24% bottom-left + blueTint at
    ///    10% top-right, `.softLight` blend
    /// 5. Triple-stop edge stroke white(0.55)→(0.18)→(0.06), 1.2pt
    ///
    /// Outer: two-layer drop shadow (black 0.55 r 30 y 12) + (black 0.35 r 10 y 4).
    func refractiveGlassBackground(radius: CGFloat, scrimOpacity: Double) -> some View {
        self.modifier(RefractiveGlassBackground(radius: radius, scrimOpacity: scrimOpacity))
    }

    /// Apply the Tonal deep-ink scrim background (simpler, no refractive
    /// tints, no edge gradient — just dark glass + thin border).
    func tonalScrimBackground(radius: CGFloat, scrimOpacity: Double) -> some View {
        self.modifier(TonalScrimBackground(radius: radius, scrimOpacity: scrimOpacity))
    }
}

private struct RefractiveGlassBackground: ViewModifier {
    let radius: CGFloat
    let scrimOpacity: Double

    func body(content: Content) -> some View {
        content
            // Layer 4: refractive corner tints (rendered ABOVE the scrim via
            // overlay below; here we layer beneath the content using
            // background stacking).
            .background(
                ZStack {
                    RadialGradient(
                        colors: [
                            VKeyDesign.red500.opacity(VKeyDesign.lgRefractiveStrength),
                            .clear,
                        ],
                        center: .bottomLeading, startRadius: 0, endRadius: 160
                    )
                    RadialGradient(
                        colors: [
                            VKeyDesign.lgBlueTint.opacity(0.10),
                            .clear,
                        ],
                        center: .topTrailing, startRadius: 0, endRadius: 160
                    )
                }
                .blendMode(.softLight)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            // Layer 3: linear + radial highlights
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.02),
                            Color.black.opacity(0.18),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    RadialGradient(
                        colors: [Color.white.opacity(0.28), .clear],
                        center: .top, startRadius: 0, endRadius: 200
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            // Layer 2: scrim
            .background(
                VKeyDesign.lgGlass1Color.opacity(scrimOpacity),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            // Layer 1: material blur baseline
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            // Layer 5: triple-stop edge stroke
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.06),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
            )
            // Outer two-layer drop shadow
            .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
    }
}

private struct TonalScrimBackground: ViewModifier {
    let radius: CGFloat
    let scrimOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                VKeyDesign.ink500.opacity(scrimOpacity),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
    }
}
