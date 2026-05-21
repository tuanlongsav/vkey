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
        
        // Hiệu ứng mờ dần (Fade-in)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        
        // Lên lịch ẩn tự động
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hideWithAnimation()
        }
    }
    
    // MARK: - Private Helper
    
    private func createPanel() {
        let hudView = ToggleHUDView(viewModel: viewModel)
        let controller = NSHostingController(rootView: hudView)
        
        let fittingSize = controller.view.fittingSize
        
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: fittingSize.width, height: fittingSize.height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
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
}

// MARK: - SwiftUI HUD View

private struct ToggleHUDView: View {
    @ObservedObject var viewModel: ToggleHUDViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon trạng thái với hiệu ứng chuyển đổi mượt mà
            ThemedSymbol(name: viewModel.isEnabled ? "character.bubble.fill" : "keyboard")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(
                    viewModel.isEnabled
                    ? AnyShapeStyle(Color.accentColor.gradient)
                    : AnyShapeStyle(Color.secondary.gradient)
                )
                .frame(width: 44, height: 44)
                .vkeySymbolReplacementTransition()
            
            // Nhãn hiển thị ngôn ngữ (bảo đảm không bị nén hoặc cắt ngắn)
            Text(viewModel.isEnabled ? "Tiếng Việt" : "English")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            // Ký hiệu viết tắt (VI / EN)
            Text(viewModel.isEnabled ? "VI" : "EN")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    viewModel.isEnabled
                    ? Color.accentColor.opacity(0.15)
                    : Color.secondary.opacity(0.15)
                )
                .foregroundStyle(viewModel.isEnabled ? Color.accentColor : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: 130) // Kích thước HUD đồng bộ đối xứng, sang trọng và không đổi khi switch
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 15, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    .white.opacity(colorScheme == .dark ? 0.15 : 0.4),
                    lineWidth: 1
                )
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.isEnabled)
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
