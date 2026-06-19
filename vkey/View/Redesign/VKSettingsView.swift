//
//  VKSettingsView.swift
//  vkey — Cửa sổ Cài đặt redesign (Tonal), NavigationSplitView.
//  Thay TabView cũ. Sidebar 232pt + detail pane.
//

import Defaults
import SwiftUI

// MARK: - Nav model

enum VKTab: String, CaseIterable, Identifiable {
  case general, smart, macro, spell, stats, theme
  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: return "Chung"
    case .smart:   return "Smart Switch"
    case .macro:   return "Macro"
    case .spell:   return "Chính tả"
    case .stats:   return "Thống kê & Sao lưu"
    case .theme:   return "Quản lý giao diện"
    }
  }
  var icon: String {
    switch self {
    case .general: return "gearshape.fill"
    case .smart:   return "shuffle"
    case .macro:   return "square.and.pencil"
    case .spell:   return "checkmark.seal.fill"
    case .stats:   return "chart.bar.fill"
    case .theme:   return "paintbrush.fill"
    }
  }
  var tileColor: Color {
    switch self {
    case .general: return VK.Color.brand
    case .smart:   return VK.Color.info
    case .macro:   return VK.Color.gold
    case .spell:   return VK.Color.success
    case .stats:   return VK.Color.gold
    case .theme:   return VK.Color.danger
    }
  }
}

// MARK: - Root

struct VKSettingsView: View {
  @EnvironmentObject var appState: AppState
  @AppStorage("vk-settings-tab") private var selectedRaw: String = VKTab.general.rawValue
  @Default(.appearanceMode) private var appearanceMode
  @Default(.uiTheme) private var uiTheme
  @Default(.themeConfigs) private var themeConfigs

  /// Token để ép subtree (detail + sidebar) render lại khi đổi theme/cấu hình.
  /// KHÔNG gồm clarity (để slider mượt) và KHÔNG đặt ở root (tránh teardown
  /// cửa sổ gây crash KVO).
  private var themeToken: String {
    let c = themeConfigs[uiTheme.rawValue] ?? .defaultFor(uiTheme)
    return "\(uiTheme.rawValue)-\(c.accent.rawValue)-\(c.radius.rawValue)-\(c.density.rawValue)-\(c.font.rawValue)"
  }

  private var selected: VKTab { VKTab(rawValue: selectedRaw) ?? .general }

  var body: some View {
    // 2 cột TỰ DỰNG (bỏ NavigationSplitView — nó tự cài NSToolbar cao gây dải
    // trống + nút sidebar thừa). Titlebar = strip mỏng ~28pt trong suốt, nền
    // các cột tràn lên dưới nó (ignoresSafeArea) nên liền mạch.
    HStack(spacing: 0) {
      VKSidebar(selectedRaw: $selectedRaw)
        .frame(width: 232)
        .id("side-\(themeToken)")

      Rectangle()
        .fill(VK.Color.border1)
        .frame(width: 1)
        .ignoresSafeArea(.container, edges: .top)

      VStack(spacing: 0) {
        // Header mỏng 42pt: tên tab CHÍNH GIỮA (gradient khi Neural) · 3 nút
        // sáng/tối SÁT PHẢI. Không nút ẩn sidebar, không ô tìm kiếm.
        ZStack {
          Text(selected.title)
            .font(VK.Font.sans(16, .bold))
            .foregroundStyle(VK.isNeural
                             ? AnyShapeStyle(VK.Color.brandGradient)
                             : AnyShapeStyle(VK.Color.fg1))
            .frame(maxWidth: .infinity, alignment: .center)
          HStack {
            Spacer()
            VKAppearanceSegment()
          }
        }
        .padding(.horizontal, VK.Space.s4)
        .frame(height: 38)
        .overlay(alignment: .bottom) {
          Rectangle().fill(VK.Color.border1).frame(height: 1)
        }

        ScrollView {
          Group {
            switch selected {
            case .general: VKGeneralTab()
            case .smart:   VKSmartTab()
            case .macro:   VKMacroTab()
            case .spell:   VKSpellTab()
            case .stats:   VKStatsTab()
            case .theme:   VKThemeTab()
            }
          }
          .frame(maxWidth: 620)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, VK.Space.s6)
          .padding(.vertical, 20)
        }
      }
      .id("detail-\(themeToken)")
      .background(detailBackground)
    }
    .frame(minWidth: 820, minHeight: 600)
    .background(rootBackground)
    .background(WindowConfigurator(theme: uiTheme))
    .tint(VK.Color.brand)
    // Đổi sáng/tối tức thì: ép NSApp.appearance thay vì .preferredColorScheme
    // (vốn không cập nhật ngay với chế độ "theo hệ thống" trên Settings scene).
    .onAppear { applyAppearance(appearanceMode) }
    .onChange(of: appearanceMode) { _, newValue in applyAppearance(newValue) }
  }

  /// Nền detail: Glass/Neural → trong suốt (lộ backdrop của cửa sổ); Tonal → đặc.
  @ViewBuilder private var detailBackground: some View {
    if uiTheme == .tonal {
      VK.Color.bg.ignoresSafeArea(.container, edges: .top)
    } else {
      Color.clear
    }
  }

  /// Nền cả cửa sổ: Glass = blur nền sau + tint; Neural = aurora; Tonal = đặc.
  @ViewBuilder private var rootBackground: some View {
    switch uiTheme {
    case .glass:  VKGlassBackdrop().ignoresSafeArea()
    case .neural: VKNeuralBackdrop().ignoresSafeArea()
    case .tonal:  VK.Color.bg.ignoresSafeArea()
    }
  }

  private func applyAppearance(_ mode: AppearanceMode) {
    let appearance: NSAppearance?
    switch mode {
    case .auto:  appearance = nil // theo hệ thống
    case .light: appearance = NSAppearance(named: .aqua)
    case .dark:  appearance = NSAppearance(named: .darkAqua)
    }
    NSApp.appearance = appearance
  }
}

// MARK: - Window chrome

/// Cấu hình cửa sổ:
/// - Ẩn NSToolbar mà NavigationSplitView tự cài (thủ phạm dải trống cao ~80pt
///   trên Tahoe) → titlebar chỉ còn strip mỏng chứa traffic lights.
/// - Liquid Glass: cửa sổ trong suốt (isOpaque=false + bg clear) để
///   VisualEffect .behindWindow blur được desktop phía sau — kính THẬT.
/// - An toàn crash: mọi set đều idempotent (chỉ ghi khi giá trị đổi) và chạy
///   async ngoài chu kỳ update. KHÔNG đụng `isMovableByWindowBackground` —
///   SwiftUI (LazyPreventsWindowDragFeature) observe KVO bool này, chính nó
///   gây SIGSEGV khi đổi theme trước đây.
private struct WindowConfigurator: NSViewRepresentable {
  var theme: UITheme

  func makeNSView(context: Context) -> VKWindowHook {
    let v = VKWindowHook()
    v.theme = theme
    return v
  }
  func updateNSView(_ nsView: VKWindowHook, context: Context) {
    nsView.theme = theme
  }
}

/// NSView hook configure cửa sổ. Phòng thủ 3 lớp cho strip titlebar:
/// 1. Apply khi view gắn vào window (`viewDidMoveToWindow`) + retry 0/0.25/1s
///    (SwiftUI Settings scene có thể set lại style SAU khi attach).
/// 2. Re-assert mỗi lần cửa sổ thành key (đóng-mở lại Settings).
/// 3. `window.backgroundColor` đặt theo MÀU THEME — kể cả khi fullSize bị
///    reset, strip vẫn ăn màu theme thay vì trắng windowBackground.
private final class VKWindowHook: NSView {
  var theme: UITheme = .tonal { didSet { scheduleApply() } }
  private var keyObserver: NSObjectProtocol?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let o = keyObserver { NotificationCenter.default.removeObserver(o); keyObserver = nil }
    guard let w = window else { return }
    keyObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification, object: w, queue: .main
    ) { [weak self] _ in self?.scheduleApply() }
    scheduleApply()
  }

  deinit {
    if let o = keyObserver { NotificationCenter.default.removeObserver(o) }
  }

  private func scheduleApply() {
    guard window != nil else { return }
    let t = theme
    for delay in [0.0, 0.25, 1.0] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        Self.configure(self?.window, theme: t)
      }
    }
  }

  private static func configure(_ window: NSWindow?, theme: UITheme) {
    guard let window else { return }
    if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
    if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
    if let toolbar = window.toolbar, toolbar.isVisible { toolbar.isVisible = false }
    // Nền theme tràn lên strip titlebar (titlebar giữ chiều cao tối thiểu
    // macOS ~28pt; phần tương tác nằm dưới safe area nên không mất click).
    if !window.styleMask.contains(.fullSizeContentView) {
      window.styleMask.insert(.fullSizeContentView)
    }
    switch theme {
    case .glass:
      if window.isOpaque { window.isOpaque = false }
      window.backgroundColor = .clear
    case .neural:
      if !window.isOpaque { window.isOpaque = true }
      window.backgroundColor = NSColor(name: nil) { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
          ? NSColor(srgbRed: 0x0B / 255, green: 0x0B / 255, blue: 0x14 / 255, alpha: 1)
          : NSColor(srgbRed: 0xF4 / 255, green: 0xF3 / 255, blue: 0xFB / 255, alpha: 1)
      }
    case .tonal:
      if !window.isOpaque { window.isOpaque = true }
      window.backgroundColor = NSColor(name: nil) { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
          ? NSColor(srgbRed: 0x13 / 255, green: 0x15 / 255, blue: 0x19 / 255, alpha: 1)
          : NSColor(srgbRed: 0xFA / 255, green: 0xF8 / 255, blue: 0xF4 / 255, alpha: 1)
      }
    }
  }
}

/// Kính thật cho Liquid Glass: blur những gì NẰM SAU cửa sổ (.behindWindow)
/// + lớp tint sáng/tối mờ — alpha theo slider "Độ trong suốt" (VK.Glass.panel).
private struct VKGlassBackdrop: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    ZStack {
      VKVisualEffect(material: .hudWindow, blending: .behindWindow)
      Rectangle().fill(VK.Glass.panel(dark: scheme == .dark))
    }
  }
}

/// Nền Neural AI (ai.css .desktop): không gian tối/lavender + 4 đốm aurora
/// (tím / cyan / hồng / indigo) blur mạnh, độ rực theo slider glow.
private struct VKNeuralBackdrop: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    let k = VK.glowK
    let dark = scheme == .dark
    ZStack {
      if dark {
        LinearGradient(colors: [Color(vkHex: "#0B0B14"), Color(vkHex: "#08080F"), Color(vkHex: "#060609")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
      } else {
        LinearGradient(colors: [Color(vkHex: "#F4F3FB"), Color(vkHex: "#ECECF6"), Color(vkHex: "#E6E8F4")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      GeometryReader { geo in
        let w = geo.size.width, h = geo.size.height
        ZStack {
          Circle().fill(Color(vkHex: "#8B5CF6").opacity(0.42 * k))
            .frame(width: w * 0.55).blur(radius: 70)
            .position(x: w * 0.22, y: h * 0.24)
          Circle().fill(Color(vkHex: "#22D3EE").opacity(0.32 * k))
            .frame(width: w * 0.45).blur(radius: 70)
            .position(x: w * 0.80, y: h * 0.28)
          Circle().fill(Color(vkHex: "#EC4899").opacity(0.24 * k))
            .frame(width: w * 0.50).blur(radius: 80)
            .position(x: w * 0.62, y: h * 0.84)
          Circle().fill(Color(vkHex: "#6366F1").opacity(0.34 * k))
            .frame(width: w * 0.50).blur(radius: 80)
            .position(x: w * 0.16, y: h * 0.78)
        }
        .opacity(dark ? 0.78 : 0.9)
      }
    }
  }
}

// MARK: - Sidebar

private struct VKSidebar: View {
  @EnvironmentObject var appState: AppState
  @Binding var selectedRaw: String

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s3) {
      // Thẻ nhận diện (đã bỏ ô tìm kiếm theo yêu cầu)
      identityCard

      // Nhãn nhóm
      Text("CÀI ĐẶT")
        .font(.vk(.eyebrow))
        .tracking(0.8)
        .foregroundStyle(VK.Color.fgMuted)
        .padding(.horizontal, 4)
        .padding(.top, 4)

      // Nav list
      VStack(spacing: 2) {
        ForEach(VKTab.allCases) { tab in
          navItem(tab)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .frame(maxHeight: .infinity)
    .background {
      Group {
        if VK.Glass.isOn || VK.isNeural {
          Color.white.opacity(0.03)
        } else {
          VK.Color.bgSunken
        }
      }
      .ignoresSafeArea(.container, edges: .top) // nền tràn lên strip titlebar
    }
  }

  private var identityCard: some View {
    HStack(spacing: 11) {
      // App icon thật (bo góc + viền nhẹ + bóng đổ).
      Group {
        if let icon = NSApp.applicationIconImage {
          Image(nsImage: icon).resizable()
        } else {
          RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VK.Color.brand)
        }
      }
      .frame(width: 44, height: 44)
      .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
      )
      .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1.5)

      VStack(alignment: .leading, spacing: 4) {
        Text("vkey")
          .font(VK.Font.sans(15, .bold))
          .foregroundStyle(VK.isNeural
                           ? AnyShapeStyle(VK.Color.brandGradient)
                           : AnyShapeStyle(VK.Color.fg1))
        HStack(spacing: 5) {
          Circle()
            .fill(appState.enabled ? VK.Color.success : VK.Color.fgMuted)
            .frame(width: 7, height: 7)
            .shadow(color: appState.enabled ? VK.Color.success.opacity(0.7) : .clear, radius: 3)
          Text(appState.enabled ? "Đang gõ tiếng Việt" : "Đang tắt")
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(appState.enabled ? VK.Color.success : VK.Color.fgMuted)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(11)
    .background(
      RoundedRectangle(cornerRadius: VK.Radius.md, style: .continuous)
        .fill(VK.Color.bgElevated)
        .overlay(
          RoundedRectangle(cornerRadius: VK.Radius.md, style: .continuous)
            .strokeBorder(VK.Color.border1, lineWidth: 1)
        )
    )
  }

  private func navItem(_ tab: VKTab) -> some View {
    let active = selectedRaw == tab.rawValue
    return Button {
      selectedRaw = tab.rawValue
    } label: {
      HStack(spacing: 9) {
        navTile(tab, active: active)
        Text(tab.title)
          .font(VK.Font.sans(13.5, .medium))
          .foregroundStyle(active ? .white : VK.Color.fg1)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(
        RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
          .fill(active ? AnyShapeStyle(VK.Color.brandGradient) : AnyShapeStyle(Color.clear))
      )
      // Halo violet quanh nav active (Neural — ai.css 0.7*k)
      .shadow(color: (active && VK.isNeural) ? VK.Color.glow.opacity(0.55 * VK.glowK) : .clear,
              radius: 11, x: 0, y: 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// Tile icon nav: Tonal → vuông đặc; Liquid Glass / Neural → tinted mờ.
  @ViewBuilder
  private func navTile(_ tab: VKTab, active: Bool) -> some View {
    let accent = VK.Color.tileAccent(tab.tileColor)
    if (VK.Glass.isOn || VK.isNeural) && !active {
      Circle()
        .fill(accent.opacity(0.22))
        .frame(width: 26, height: 26)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Image(systemName: tab.icon)
                  .font(.system(size: 12.5, weight: .semibold))
                  .foregroundStyle(accent))
        .overlay(Circle().strokeBorder(accent.opacity(0.30), lineWidth: 1))
    } else {
      RoundedRectangle(cornerRadius: VK.Glass.isOn ? 13 : 7, style: .continuous)
        .fill(active ? Color.white.opacity(0.22) : accent)
        .frame(width: 26, height: 26)
        .overlay(Image(systemName: tab.icon)
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(.white))
    }
  }
}
