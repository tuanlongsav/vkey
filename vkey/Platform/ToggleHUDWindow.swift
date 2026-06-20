//
//  ToggleHUDWindow.swift
//  vkey
//
//  Created by Antigravity on 19/05/2026.
//
//  v2.4.0 FIX "khoanh vuông mờ":
//  - Panel size = content + HUDMetrics.shadowMargin mỗi phía → shadow/glow
//    không còn bị cắt phẳng theo khung chữ nhật của cửa sổ.
//  - Hosting view layer-backed + clear background.
//  - Blur nền dùng HUDBackdrop (mask đúng hình) thay .ultraThinMaterial.
//  - Bỏ .blendMode(.screen) (rò sáng ra nền trong suốt).
//  - Thêm pop-in scale nhẹ (0.94→1, spring) cho cảm giác chau chuốt hơn.
//

import AppKit
import SwiftUI
import Defaults

/// HUD overlay shown when the input mode toggles between VI and EN.
@MainActor
final class ToggleHUDWindow {

    // MARK: - Singleton
    static let shared = ToggleHUDWindow()

    // MARK: - Properties
    private var panel: NSPanel?
    private var hideTimer: Timer?
    private var hostingController: NSHostingController<AnyView>?
    private let viewModel = ToggleHUDViewModel()

    // MARK: - Initialization
    private init() {}

    // MARK: - Public API

    /// Hiển thị HUD thông báo trạng thái bật/tắt Tiếng Việt
    func show(isEnabled: Bool, duration: TimeInterval = 1.0) {
        guard Defaults[.hudEnabled] else { return }

        hideTimer?.invalidate()

        // Cập nhật dữ liệu ViewModel
        viewModel.isEnabled = isEnabled
        viewModel.backgroundStrength = Self.clampedBackgroundStrength(Defaults[.hudOpacityPercent])

        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        let contentSize = Self.contentSize(
            theme: Defaults[.uiTheme],
            typingMethod: Defaults[.typingMethod],
            newStyleTonePlacement: Defaults[.newStyleTonePlacement],
            modifierHotkey: Defaults[.modifierOnlyToggleHotkey]
        )
        applyPanelGeometry(contentSize: contentSize, panel: panel)

        // Đưa panel lên trước mà không cướp focus
        panel.alphaValue = 0
        viewModel.appeared = false
        panel.orderFrontRegardless()

        // Fade-in (window alpha) + pop-in (SwiftUI scale spring)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        DispatchQueue.main.async { [viewModel] in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                viewModel.appeared = true
            }
        }

        // Lên lịch ẩn tự động
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.hideWithAnimation() }
        }
    }

    /// Ẩn ngay (marketing export — bỏ animation).
    func hideImmediately() {
        hideTimer?.invalidate()
        panel?.orderOut(nil)
    }

    // MARK: - Private Helper

    nonisolated private static func clampedBackgroundStrength(_ value: Int) -> Double {
        Double(max(30, min(100, value))) / 100.0
    }

    /// Đo kích thước thủ công — không phụ thuộc SwiftUI `fittingSize` (bất
    /// đồng bộ khi `@Published` đổi). Luôn dùng max(VI, EN) để toggle không lệch.
    nonisolated static func contentSize(
        theme: UITheme,
        typingMethod: TypingMethods,
        newStyleTonePlacement: Bool,
        modifierHotkey: Int
    ) -> CGSize {
        let hotkeyGlyphs = hotkeyGlyphs(from: modifierHotkey)
        let keycapRowWidth = keycapRowWidth(glyphCount: hotkeyGlyphs.count)

        switch theme {
        case .glass, .neural:
            let titleFont = hudDisplayFont(size: 18)
            let titleWidth = max(
                measureText("Tiếng Việt", font: titleFont).width,
                measureText("English", font: titleFont).width
            )
            let badgeFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
            let badgeWidth = max(
                measureText("VI", font: badgeFont).width,
                measureText("EN", font: badgeFont).width
            ) + 22 // .padding(.horizontal, 11) × 2
            let flagWidth: CGFloat = 40
            let spacing: CGFloat = 14
            let innerWidth = flagWidth + spacing + titleWidth
                + (keycapRowWidth > 0 ? spacing + keycapRowWidth : 0)
                + spacing + badgeWidth
            let innerHeight = max(40, measureText("Tiếng Việt", font: titleFont).height, 28)
            return CGSize(
                width: ceil(innerWidth + 11 + 16),
                height: ceil(innerHeight + 22)
            )

        case .tonal:
            let titleFont = hudDisplayFont(size: 17)
            let subtitleFont = NSFont.systemFont(ofSize: 12, weight: .regular)
            let viSubtitle = "\(typingMethod.rawValue) · \(newStyleTonePlacement ? "Kiểu mới" : "Kiểu cũ")"
            let enSubtitle = "vkey tạm tắt"
            let textColumnWidth = max(
                measureText("Tiếng Việt", font: titleFont).width,
                measureText("English", font: titleFont).width,
                measureText(viSubtitle, font: subtitleFont).width,
                measureText(enSubtitle, font: subtitleFont).width
            )
            let flagWidth: CGFloat = 48
            let spacing: CGFloat = 14
            let innerWidth = flagWidth + spacing + textColumnWidth
                + (keycapRowWidth > 0 ? spacing + keycapRowWidth : 0)
            let titleHeight = measureText("Tiếng Việt", font: titleFont).height
            let subtitleHeight = measureText(viSubtitle, font: subtitleFont).height
            let innerHeight = max(36, titleHeight + 4 + subtitleHeight)
            return CGSize(
                width: ceil(innerWidth + 48),
                height: ceil(innerHeight + 36)
            )
        }
    }

    private func applyPanelGeometry(contentSize: CGSize, panel: NSPanel) {
        let margin = HUDMetrics.shadowMargin
        let windowSize = CGSize(
            width: contentSize.width + margin * 2,
            height: contentSize.height + margin * 2
        )
        panel.setContentSize(windowSize)
        hostingController?.view.setFrameSize(windowSize)

        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY - windowSize.height / 2 - 120
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    nonisolated private static func hotkeyGlyphs(from raw: Int) -> [String] {
        guard raw != 0 else { return [] }
        return formatModifierMask(raw).map { String($0) }
    }

    nonisolated private static func keycapRowWidth(glyphCount: Int) -> CGFloat {
        guard glyphCount > 0 else { return 0 }
        let keycapUnit: CGFloat = 44 // minWidth 28 + horizontal padding 16
        let spacing: CGFloat = 6
        return CGFloat(glyphCount) * keycapUnit + CGFloat(glyphCount - 1) * spacing
    }

    nonisolated private static func hudDisplayFont(size: CGFloat) -> NSFont {
        if let font = NSFont(name: "NotoSansDisplay-Bold", size: size)
            ?? NSFont(name: "NotoSansDisplay", size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: .bold)
    }

    nonisolated private static func measureText(_ text: String, font: NSFont) -> CGSize {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }

    private func createPanel() {
        // v2.4.0: đệm trong suốt quanh HUD để shadow không bị cắt vuông.
        let hudView = AnyView(
            ToggleHUDView(viewModel: viewModel)
                .padding(HUDMetrics.shadowMargin)
        )
        let controller = NSHostingController(rootView: hudView)
        if #available(macOS 13.0, *) {
            // Chặn SwiftUI tự propose window resize trong borderless panel.
            controller.sizingOptions = []
        }

        // Hosting view phải layer-backed + clear — tránh vẽ backing rect.
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let contentSize = Self.contentSize(
            theme: Defaults[.uiTheme],
            typingMethod: Defaults[.typingMethod],
            newStyleTonePlacement: Defaults[.newStyleTonePlacement],
            modifierHotkey: Defaults[.modifierOnlyToggleHotkey]
        )
        let margin = HUDMetrics.shadowMargin
        let windowSize = CGSize(
            width: contentSize.width + margin * 2,
            height: contentSize.height + margin * 2
        )
        controller.view.setFrameSize(windowSize)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.contentViewController = controller
        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false // Shadow do SwiftUI vẽ (đã có đệm chứa nó)
        newPanel.ignoresMouseEvents = true
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        hostingController = controller
        panel = newPanel
    }

    private func hideWithAnimation() {
        guard let panel = panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in self?.panel?.orderOut(nil) }
        })
    }
}

// MARK: - ViewModel

private class ToggleHUDViewModel: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var backgroundStrength: Double = 0.75
    /// v2.4.0: drive pop-in scale (không đổi layout — scaleEffect thuần render).
    @Published var appeared: Bool = true
}

// MARK: - SwiftUI HUD View

private struct ToggleHUDView: View {
    @ObservedObject var viewModel: ToggleHUDViewModel
    @Default(.typingMethod) private var typingMethod
    @Default(.newStyleTonePlacement) private var newStyleTonePlacement
    @Default(.modifierOnlyToggleHotkey) private var modifierOnlyToggleHotkey
    @Default(.uiTheme) private var uiTheme

    var body: some View {
        Group {
            switch uiTheme {
            case .glass:  glassBody
            case .neural: neuralBody
            case .tonal:  tonalBody
            }
        }
        .scaleEffect(viewModel.appeared ? 1 : 0.94)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.isEnabled)
    }

    // MARK: - Neural AI HUD — viên obsidian + viền gradient trí tuệ + halo violet

    private var neuralBody: some View {
        HStack(spacing: 14) {
            HUDFlag(viewModel.isEnabled)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(VK.Color.brandGradient, lineWidth: 1.5))
                .shadow(color: VK.Color.glow.opacity(0.5 * VK.glowK), radius: 8, x: 0, y: 3)
                .vkeySymbolReplacementTransition()

            Text(viewModel.isEnabled ? "Tiếng Việt" : "English")
                .font(VKeyDesign.display(18, weight: .bold))
                .foregroundStyle(Color(vkHex: "#ECECF7"))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if !hotkeyGlyphs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(hotkeyGlyphs, id: \.self) { glyph in Keycap(glyph, size: .md) }
                }
            }

            Text(viewModel.isEnabled ? "VI" : "EN")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(VK.Color.brandGradient))
                .overlay(Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 0.5))
        }
        .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 16))
        .background(Capsule().fill(Color(vkHex: "#0F0F18").opacity(0.88)))
        .background(HUDBackdrop()) // v2.4.0: blur mask đúng capsule
        .overlay(Capsule().strokeBorder(VK.Color.brandGradient, lineWidth: 1).opacity(0.65))
        .compositingGroup()
        .shadow(color: VK.Color.glow.opacity(0.45 * VK.glowK), radius: 26, x: 0, y: 10)
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 14)
    }

    // MARK: - Liquid Glass HUD — viên kính nổi (per design `.hud-glass`)

    private var glassBody: some View {
        HStack(spacing: 14) {
            HUDFlag(viewModel.isEnabled)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
                .vkeySymbolReplacementTransition()

            Text(viewModel.isEnabled ? "Tiếng Việt" : "English")
                .font(VKeyDesign.display(18, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if !hotkeyGlyphs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(hotkeyGlyphs, id: \.self) { glyph in Keycap(glyph, size: .md) }
                }
            }

            Text(viewModel.isEnabled ? "VI" : "EN")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(VK.Color.brand))
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
        }
        .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 16))
        .background(HUDBackdrop()) // v2.4.0: blur mask đúng capsule
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        // v2.4.0: bỏ .blendMode(.screen) — thay bằng stroke trắng đậm hơn
        .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
        .compositingGroup()
        .shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 12)
    }

    // MARK: - Sub-title + keycap helpers (v2.3.0)

    private var subTitle: String {
        if viewModel.isEnabled {
            let style = newStyleTonePlacement ? "Kiểu mới" : "Kiểu cũ"
            return "\(typingMethod.rawValue) · \(style)"
        } else {
            return "vkey tạm tắt"
        }
    }

    private var hotkeyGlyphs: [String] {
        let raw = modifierOnlyToggleHotkey
        guard raw != 0 else { return [] }
        let formatted = formatModifierMask(raw)
        return formatted.map { String($0) }
    }

    // MARK: - Tonal HUD — horizontal layout, deep-ink scrim

    private var tonalBody: some View {
        HStack(alignment: .center, spacing: 14) {
            HUDFlag(viewModel.isEnabled)
                .vkeySymbolReplacementTransition()

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isEnabled ? "Tiếng Việt" : "English")
                    .font(VKeyDesign.display(17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Text(subTitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if !hotkeyGlyphs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(hotkeyGlyphs, id: \.self) { glyph in
                        Keycap(glyph, size: .md)
                    }
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .tonalScrimBackground(radius: 20, scrimOpacity: tonalScrimOpacity)
    }

    private var tonalScrimOpacity: Double {
        0.32 + 0.30 * viewModel.backgroundStrength
    }
}

private extension View {
    @ViewBuilder
    func vkeySymbolReplacementTransition() -> some View {
        if #available(macOS 14.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}
