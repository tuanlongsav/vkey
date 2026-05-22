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
    @Environment(\.colorScheme) var colorScheme
    @Default(.uiTheme) private var uiTheme

    var body: some View {
        Group {
            switch uiTheme {
            case .tonal:        tonalBody
            case .liquidGlass:  liquidGlassBody
            case .classic:      classicBody
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.isEnabled)
    }

    // MARK: - Liquid Glass (v2.2.2) — macOS Tahoe / visionOS refractive glass

    private var liquidGlassBody: some View {
        let radius: CGFloat = 22

        return VStack(spacing: 6) {
            ThemedSymbol(name: viewModel.isEnabled ? "character.bubble.fill" : "keyboard")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(
                    viewModel.isEnabled
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.white, VKeyDesign.red300, VKeyDesign.red500],
                        startPoint: .top, endPoint: .bottom
                    ))
                    : AnyShapeStyle(LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    ))
                )
                .shadow(color: viewModel.isEnabled
                    ? VKeyDesign.red500.opacity(0.45)
                    : Color.black.opacity(0.25),
                    radius: 6, x: 0, y: 2)
                .shadow(color: .white.opacity(0.30), radius: 0.5, x: 0, y: -0.5)
                .frame(width: 48, height: 48)
                .vkeySymbolReplacementTransition()

            Text(viewModel.isEnabled ? "Tiếng Việt" : "English")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0xF2EFE8))
                .shadow(color: .black.opacity(0.45), radius: 0.5, x: 0, y: 0.5)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            // Glass pill VI/EN — multi-layer gradient + inner highlight
            Text(viewModel.isEnabled ? "VI" : "EN")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(0.6)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    ZStack {
                        if viewModel.isEnabled {
                            // Glossy red pill
                            LinearGradient(
                                colors: [Color.white.opacity(0.30), Color.white.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                            VKeyDesign.red500.opacity(0.95)
                        } else {
                            // Glass-neutral pill
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom
                            )
                            Color.white.opacity(0.05)
                        }
                    }
                )
                .foregroundStyle(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.6)
                )
                .shadow(color: viewModel.isEnabled
                    ? VKeyDesign.red500.opacity(0.55)
                    : .clear,
                    radius: 6, x: 0, y: 2)
        }
        .frame(width: 138)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(
            // Refractive corner tints (red bottom-left + blue top-right)
            ZStack {
                RadialGradient(
                    colors: [VKeyDesign.red500.opacity(0.18), .clear],
                    center: .bottomLeading, startRadius: 0, endRadius: 120
                )
                RadialGradient(
                    colors: [VKeyDesign.lgBlueTint.opacity(0.10), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: 120
                )
            }
            .blendMode(.softLight)
            .clipShape(RoundedRectangle(cornerRadius: radius))
        )
        .background(
            // Top spec arc + base shading
            ZStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.02),
                        Color.black.opacity(0.18),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color.white.opacity(0.28), .clear],
                    center: .top, startRadius: 0, endRadius: 180
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
        )
        .background(
            VKeyDesign.lgGlass1Color.opacity(liquidGlassScrimOpacity),
            in: RoundedRectangle(cornerRadius: radius)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
        .overlay(
            // Triple inner edge: top white highlight, bottom black, rim white
            RoundedRectangle(cornerRadius: radius)
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
        .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    private var liquidGlassScrimOpacity: Double {
        // Multi-layer glass — primary scrim baseline 0.55, scale with opacity setting.
        0.30 + 0.32 * viewModel.backgroundStrength
    }

    // MARK: - Classic (v2.0.2 look)

    private var classicBody: some View {
        VStack(spacing: 6) {
            ThemedSymbol(name: viewModel.isEnabled ? "character.bubble.fill" : "keyboard")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(
                    viewModel.isEnabled
                    ? AnyShapeStyle(Color.accentColor.gradient)
                    : AnyShapeStyle(Color.secondary.gradient)
                )
                .frame(width: 48, height: 48)
                .vkeySymbolReplacementTransition()

            Text(viewModel.isEnabled ? "Tiếng Việt" : "English")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(viewModel.isEnabled ? "VI" : "EN")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    viewModel.isEnabled
                    ? Color.accentColor.opacity(0.18)
                    : Color.secondary.opacity(0.18)
                )
                .foregroundStyle(viewModel.isEnabled ? Color.accentColor : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .frame(width: 130)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            Color.black.opacity(classicScrimOpacity),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    .white.opacity(colorScheme == .dark ? 0.16 : 0.28),
                    lineWidth: 0.6
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.10), radius: 10, x: 0, y: 3)
    }

    private var classicScrimOpacity: Double {
        let base = colorScheme == .dark ? 0.10 : 0.03
        let range = colorScheme == .dark ? 0.16 : 0.07
        return base + range * viewModel.backgroundStrength
    }

    // MARK: - Tonal (v2.1.0+)

    private var tonalBody: some View {
        VStack(spacing: 6) {
            ThemedSymbol(name: viewModel.isEnabled ? "character.bubble.fill" : "keyboard")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(
                    viewModel.isEnabled
                    ? AnyShapeStyle(VKeyDesign.red400.gradient)
                    : AnyShapeStyle(VKeyDesign.paper200.gradient)
                )
                .frame(width: 48, height: 48)
                .vkeySymbolReplacementTransition()

            Text(viewModel.isEnabled ? "Tiếng Việt" : "English")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(viewModel.isEnabled ? "VI" : "EN")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    viewModel.isEnabled
                    ? VKeyDesign.red500.opacity(0.28)
                    : Color.white.opacity(0.14)
                )
                .foregroundStyle(viewModel.isEnabled ? VKeyDesign.red200 : Color.white.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .frame(width: 130)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            VKeyDesign.ink500.opacity(tonalScrimOpacity),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
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
