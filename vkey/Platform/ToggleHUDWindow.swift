//
//  ToggleHUDWindow.swift
//  vkey
//
//  Created by Antigravity on 19/05/2026.
//

import AppKit
import SwiftUI
import Defaults

/// HUD overlay shown when the input mode toggles between VI and EN.
///
/// **Thread-safety (1.5.0)**: this class is `@MainActor`-isolated. All AppKit
/// state (`panel`, `hostingController`, `hideTimer`) is mutated only on the
/// main thread. Call `ToggleHUDWindow.shared.show(isEnabled:)` from a non-main
/// thread via `DispatchQueue.main.async { … }`, or from an `async` context
/// using `await`. Previously the singleton was free-threaded which let the
/// event tap race with the main thread while constructing the panel.
@MainActor
final class ToggleHUDWindow {

    // MARK: - Singleton
    static let shared = ToggleHUDWindow()

    // MARK: - Properties
    private var panel: NSPanel?
    private var hideTimer: Timer?
    private var hostingController: NSHostingController<ToggleHUDView>?
    private let viewModel = ToggleHUDViewModel()

    // MARK: - Initialization
    private init() {}

    // MARK: - Public API

    /// Hiển thị HUD thông báo trạng thái bật/tắt Tiếng Việt
    /// - Parameters:
    ///   - isEnabled: Trạng thái bật (true = Tiếng Việt, false = Tiếng Anh)
    ///   - duration: Thời gian hiển thị trước khi tự động đóng (giây)
    func show(isEnabled: Bool, duration: TimeInterval = 1.0) {
        // Nếu người dùng tắt HUD trong Cài đặt, không làm gì cả
        guard Defaults[.hudEnabled] else { return }
        
        // Hủy timer cũ nếu đang chạy
        hideTimer?.invalidate()
        
        // Cập nhật dữ liệu ViewModel
        viewModel.isEnabled = isEnabled
        viewModel.backgroundStrength = Self.clampedBackgroundStrength(Defaults[.hudOpacityPercent])
        
        // Tạo panel nếu chưa tồn tại
        if panel == nil {
            createPanel()
        }
        
        guard let panel = panel else { return }
        
        // Cập nhật kích thước panel để khớp hoàn hảo với nội dung SwiftUI
        if let hostingController = hostingController {
            let fittingSize = hostingController.view.fittingSize
            panel.setContentSize(fittingSize)
        }
        
        // Định vị HUD ở chính giữa màn hình đang hoạt động (lùi xuống dưới một chút cho tinh tế)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2 - 120 // Thấp hơn tâm màn hình một chút
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Đưa panel lên trước mà không cướp focus (orderFrontRegardless)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // 1.9.6: panel alpha chỉ dùng cho fade animation. Độ đậm HUD giờ
        // điều khiển lớp nền trong SwiftUI, không làm mờ chữ/icon.
        let targetAlpha: CGFloat = 1

        // Hiệu ứng mờ dần (Fade-in)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = targetAlpha
        }
        
        // Lên lịch ẩn tự động
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hideWithAnimation()
        }
    }
    
    // MARK: - Private Helper

    nonisolated private static func clampedBackgroundStrength(_ value: Int) -> Double {
        Double(max(30, min(100, value))) / 100.0
    }
    
    private func createPanel() {
        let hudView = ToggleHUDView(viewModel: viewModel)
        let controller = NSHostingController(rootView: hudView)

        let fittingSize = controller.view.fittingSize

        // 1.9.2: thêm `.borderless` style mask để loại bỏ default window
        // chrome rendering — fix bug bo góc bên trái có hình vuông đè
        // (default panel chrome vẽ chevron/title area mà SwiftUI clipShape
        // không che được).
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: fittingSize.width, height: fittingSize.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.contentViewController = controller
        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu // Hiển thị trên cả các ứng dụng Fullscreen/Menus
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false // Shadow sẽ do SwiftUI vẽ để đẹp hơn
        newPanel.ignoresMouseEvents = true // Không chặn click chuột của người dùng
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
            self?.panel?.orderOut(nil)
        })
    }
}

// MARK: - ViewModel

private class ToggleHUDViewModel: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var backgroundStrength: Double = 0.75
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
            if uiTheme == .glass { glassBody } else { tonalBody }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.isEnabled)
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
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.5).blendMode(.screen))
        .shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 12)
    }

    // MARK: - Sub-title + keycap helpers (v2.3.0)

    /// Sub-title text below the main "Tiếng Việt" / "English" label.
    /// Reads current typing method + tone-placement style for VI state;
    /// indicates idle/inactive state for EN.
    private var subTitle: String {
        if viewModel.isEnabled {
            let style = newStyleTonePlacement ? "Kiểu mới" : "Kiểu cũ"
            return "\(typingMethod.rawValue) · \(style)"
        } else {
            return "vkey tạm tắt"
        }
    }

    /// Modifier glyphs in canonical macOS order (⌃⌥⇧⌘) for current toggle hotkey.
    /// Empty array if hotkey unset → keycap row hidden.
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
