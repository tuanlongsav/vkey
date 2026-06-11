//
//  HUDComponents.swift
//  vkey
//
//  v2.4.0: shared HUD primitives — extracted to avoid duplication between
//  ToggleHUDWindow + PredictionHUDWindow under all themes.
//
//  v2.4.0 FIX "khoanh vuông mờ quanh HUD" — 3 nguyên nhân, 3 lớp vá:
//
//    (1) Shadow bị cắt theo khung chữ nhật của NSPanel.
//        Panel size = fittingSize của content, nhưng các .shadow(radius
//        24–30, y 12) vẽ RA NGOÀI bounds → bị cắt phẳng ở mép cửa sổ
//        → quầng tối kết thúc đột ngột thành hình vuông mờ.
//        → Vá: HUDMetrics.shadowMargin — đệm trong suốt quanh content,
//          window to hơn content đúng phần đệm này.
//
//    (2) `.ultraThinMaterial` trong borderless panel trong suốt.
//        SwiftUI material = NSVisualEffectView within-window; phần TINT
//        được mask theo Capsule nhưng lớp backdrop-sample hình chữ nhật
//        có thể vẫn render (rõ nhất khi animate window alphaValue).
//        → Vá: HUDBackdrop — NSVisualEffectView blendingMode .behindWindow
//          + maskImage bo tròn: mask đúng CẢ lớp blur.
//
//    (3) Blend mode rò ra nền cửa sổ trong suốt.
//        .plusLighter / .screen composite với pixel trong suốt phía sau
//        → khung chữ nhật của layer sáng lên lờ mờ.
//        → Vá: bỏ blend mode trong HUD context (bù bằng opacity),
//          + .compositingGroup() trước .shadow.
//
//  Primitives:
//    • HUDMetrics          — hằng số đệm shadow dùng chung 2 HUD window.
//    • HUDBackdrop         — nền blur mask đúng hình (capsule/rounded).
//    • Keycap              — mini glass pill render shortcut key label.
//    • HUDFlag             — 48×36 flag image với inner stroke + gloss.
//    • refractiveGlassBackground / tonalScrimBackground — background recipes.
//

import AppKit
import SwiftUI

// MARK: - HUD metrics (v2.4.0)

enum HUDMetrics {
    /// Đệm trong suốt quanh content của Toggle HUD — đủ chứa shadow lớn
    /// nhất (radius 30 + y 12 ≈ 57pt về phía dưới).
    static let shadowMargin: CGFloat = 64

    /// Đệm cho Prediction HUD (shadow nhỏ hơn: radius ≤ 14 + y 6).
    static let predictionShadowMargin: CGFloat = 40
}

// MARK: - HUDBackdrop (v2.4.0)

/// Nền blur cho HUD trong borderless NSPanel trong suốt.
///
/// Dùng THAY cho `.background(.ultraThinMaterial, in: Capsule())` ở mọi
/// HUD: NSVisualEffectView `.behindWindow` + `maskImage` bo tròn nên lớp
/// blur được mask đúng hình — không còn ô vuông backdrop lộ ra sau lưng
/// capsule khi window alpha animate.
///
/// `cornerRadius == nil` → capsule (radius = height/2, tự cập nhật theo
/// layout — dùng cho HUD dạng pill).
struct HUDBackdrop: NSViewRepresentable {
    var cornerRadius: CGFloat? = nil

    func makeNSView(context: Context) -> HUDBackdropEffectView {
        let v = HUDBackdropEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.fixedCornerRadius = cornerRadius
        return v
    }

    func updateNSView(_ v: HUDBackdropEffectView, context: Context) {
        v.fixedCornerRadius = cornerRadius
        v.needsLayout = true
    }
}

final class HUDBackdropEffectView: NSVisualEffectView {
    var fixedCornerRadius: CGFloat?

    override func layout() {
        super.layout()
        let maxR = min(bounds.width, bounds.height) / 2
        let r = max(1, min(fixedCornerRadius ?? maxR, maxR))
        maskImage = .vkRoundedMask(cornerRadius: r)
    }
}

extension NSImage {
    /// Mask image bo góc, capInsets stretch — chuẩn AppKit để mask
    /// NSVisualEffectView trong cửa sổ trong suốt.
    static func vkRoundedMask(cornerRadius r: CGFloat) -> NSImage {
        let edge = r * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
        image.resizingMode = .stretch
        return image
    }
}

// MARK: - Keycap

/// Mini glass pill rendering a single keyboard symbol/word.
///
/// v2.4.0: bỏ `.blendMode(.plusLighter)` — blend mode trong cửa sổ trong
/// suốt composite với pixel transparent phía sau làm khung layer sáng mờ.
/// Bù bằng cách nâng opacity gradient (0.22→0.28 / 0.04→0.07).
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
                // Top-bottom white glass gradient — normal blend (v2.4.0)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.28),
                        Color.white.opacity(0.07),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
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
            .compositingGroup()
            // Subtle bottom-inset shadow for "pressed-in" feel
            .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 1)
    }
}

// MARK: - HUDFlag

/// 48×36 flag image used as the leading icon of the toggle HUD.
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
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.30), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Background modifiers

extension View {
    /// Apply the Liquid Glass refractive background recipe.
    /// v2.4.0: material → HUDBackdrop (mask đúng blur), compositingGroup
    /// trước shadow.
    func refractiveGlassBackground(radius: CGFloat, scrimOpacity: Double) -> some View {
        self.modifier(RefractiveGlassBackground(radius: radius, scrimOpacity: scrimOpacity))
    }

    /// Apply the Tonal deep-ink scrim background.
    func tonalScrimBackground(radius: CGFloat, scrimOpacity: Double) -> some View {
        self.modifier(TonalScrimBackground(radius: radius, scrimOpacity: scrimOpacity))
    }
}

private struct RefractiveGlassBackground: ViewModifier {
    let radius: CGFloat
    let scrimOpacity: Double

    func body(content: Content) -> some View {
        content
            // Layer 4: refractive corner tints.
            // v2.4.0: bỏ .softLight (blend rò ra nền trong suốt) — giảm
            // opacity tint để giữ cùng cường độ thị giác với normal blend.
            .background(
                ZStack {
                    RadialGradient(
                        colors: [
                            VKeyDesign.red500.opacity(VKeyDesign.lgRefractiveStrength * 0.6),
                            .clear,
                        ],
                        center: .bottomLeading, startRadius: 0, endRadius: 160
                    )
                    RadialGradient(
                        colors: [
                            VKeyDesign.lgBlueTint.opacity(0.06),
                            .clear,
                        ],
                        center: .topTrailing, startRadius: 0, endRadius: 160
                    )
                }
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
            // Layer 1: blur baseline — v2.4.0: HUDBackdrop thay material
            .background(HUDBackdrop(cornerRadius: radius))
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
            .compositingGroup()
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
            // Layer 4: subtle top highlight (white 6% gradient top → clear)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.0),
                    ],
                    startPoint: .top, endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            // Layer 3: warm ink tint overlay — match `--glass-dark` warmth
            .background(
                Color(hex: 0x131519).opacity(scrimOpacity),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            // Layer 2: blur baseline — v2.4.0: HUDBackdrop thay material
            .background(HUDBackdrop(cornerRadius: radius))
            // Layer 1: inset border
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .compositingGroup()
            // Outer drop shadow
            .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
    }
}
