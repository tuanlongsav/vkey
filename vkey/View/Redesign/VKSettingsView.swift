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
    case .stats:   return VK.Color.ink200
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
  @State private var search: String = ""

  /// Token để ép subtree (detail + sidebar) render lại khi đổi theme/cấu hình.
  /// KHÔNG gồm clarity (để slider mượt) và KHÔNG đặt ở root (tránh teardown
  /// cửa sổ gây crash KVO).
  private var themeToken: String {
    let c = themeConfigs[uiTheme.rawValue] ?? .defaultFor(uiTheme)
    return "\(uiTheme.rawValue)-\(c.accent.rawValue)-\(c.radius.rawValue)-\(c.density.rawValue)-\(c.font.rawValue)"
  }

  private var selected: VKTab { VKTab(rawValue: selectedRaw) ?? .general }

  var body: some View {
    NavigationSplitView {
      VKSidebar(selectedRaw: $selectedRaw, search: $search)
        .id(themeToken)
        .navigationSplitViewColumnWidth(232)
    } detail: {
      VStack(spacing: 0) {
        // Header tự vẽ: tên tab CHÍNH GIỮA, 3 nút sáng/tối SÁT PHẢI.
        // KHÔNG dùng toolbar/navigationTitle native (Tahoe tự bọc pill + trùng).
        ZStack {
          Text(selected.title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(VK.Color.fg1)
            .frame(maxWidth: .infinity, alignment: .center)
          HStack {
            Spacer()
            VKAppearanceSegment()
          }
        }
        .padding(.horizontal, VK.Space.s6)
        .padding(.top, 6)
        .frame(height: 52)
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
      .id(themeToken) // ép detail render lại khi đổi theme/cấu hình
      .background(detailBackground)
      .ignoresSafeArea(.container, edges: .top)
      .navigationTitle("")
    }
    .frame(minWidth: 820, minHeight: 600)
    .background(WindowConfigurator())
    .tint(VK.Color.brand)
    // Đổi sáng/tối tức thì: ép NSApp.appearance thay vì .preferredColorScheme
    // (vốn không cập nhật ngay với chế độ "theo hệ thống" trên Settings scene).
    .onAppear { applyAppearance(appearanceMode) }
    .onChange(of: appearanceMode) { _, newValue in applyAppearance(newValue) }
  }

  /// Nền detail: Liquid Glass → gradient ấm để kính có gì khúc xạ; Tonal → đặc.
  /// KHÔNG đụng thuộc tính cửa sổ (isOpaque) — đó là nguyên nhân crash KVO.
  @ViewBuilder private var detailBackground: some View {
    if uiTheme == .glass {
      VKGlassDesktop().ignoresSafeArea()
    } else {
      VK.Color.bg
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

/// Titlebar trong suốt (header gọn 1 băng, tên tab ở giữa). CHỈ set 1 lần,
/// idempotent — KHÔNG đụng `isOpaque`/`backgroundColor` (toggle bool gây crash
/// KVO re-entrancy khi đổi theme). Liquid Glass render bằng nền trong app.
private struct WindowConfigurator: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let v = NSView()
    DispatchQueue.main.async { configure(v.window) }
    return v
  }
  func updateNSView(_ nsView: NSView, context: Context) {}
  private func configure(_ window: NSWindow?) {
    guard let window else { return }
    if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
    if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
    // Cho nội dung tràn lên dưới titlebar → thu hồi băng trống phía trên.
    if !window.styleMask.contains(.fullSizeContentView) {
      window.styleMask.insert(.fullSizeContentView)
    }
    window.isMovableByWindowBackground = true
  }
}

/// Nền "desktop kính" cho Liquid Glass: gradient ấm + lớp frost (ultraThin)
/// để nội dung đọc được. Là nền vẽ trong app (không cần cửa sổ trong suốt).
struct VKGlassDesktop: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    ZStack {
      if scheme == .dark {
        LinearGradient(colors: [Color(vkHex: "#3A211B"), Color(vkHex: "#241310"), Color(vkHex: "#0E0807")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
      } else {
        LinearGradient(colors: [Color(vkHex: "#EA6B45"), Color(vkHex: "#CE3A22"), Color(vkHex: "#8E2616"), Color(vkHex: "#4A1510")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      Rectangle().fill(.ultraThinMaterial)
    }
  }
}

// MARK: - Sidebar

private struct VKSidebar: View {
  @EnvironmentObject var appState: AppState
  @Binding var selectedRaw: String
  @Binding var search: String

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s3) {
      // Ô tìm kiếm
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 13))
          .foregroundStyle(VK.Color.fgMuted)
        TextField("Tìm cài đặt", text: $search)
          .textFieldStyle(.plain)
          .font(.vk(.body))
      }
      .padding(.horizontal, 8)
      .frame(height: 30)
      .background(
        RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
          .fill(VK.Color.bgElevated)
          .overlay(
            RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
              .strokeBorder(VK.Color.border1, lineWidth: 1)
          )
      )

      // Thẻ nhận diện
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
    .padding(.top, 30) // chừa traffic lights khi nội dung tràn full-size
    .frame(maxHeight: .infinity)
    .background(VK.Glass.isOn ? AnyView(VKGlassDesktop()) : AnyView(VK.Color.bgSunken))
    .ignoresSafeArea(.container, edges: .top)
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
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(VK.Color.fg1)
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
          .font(.system(size: 13.5, weight: .medium))
          .foregroundStyle(active ? .white : VK.Color.fg1)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(
        RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
          .fill(active ? VK.Color.brand : .clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// Tile icon nav: Tonal → vuông đặc; Liquid Glass → tròn tinted kính.
  @ViewBuilder
  private func navTile(_ tab: VKTab, active: Bool) -> some View {
    if VK.Glass.isOn && !active {
      Circle()
        .fill(tab.tileColor.opacity(0.22))
        .frame(width: 26, height: 26)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Image(systemName: tab.icon)
                  .font(.system(size: 12.5, weight: .semibold))
                  .foregroundStyle(tab.tileColor))
        .overlay(Circle().strokeBorder(tab.tileColor.opacity(0.30), lineWidth: 1))
    } else {
      RoundedRectangle(cornerRadius: VK.Glass.isOn ? 13 : 7, style: .continuous)
        .fill(active ? Color.white.opacity(0.22) : tab.tileColor)
        .frame(width: 26, height: 26)
        .overlay(Image(systemName: tab.icon)
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(.white))
    }
  }
}
