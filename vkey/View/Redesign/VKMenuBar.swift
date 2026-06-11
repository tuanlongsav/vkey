//
//  VKMenuBar.swift
//  vkey — Menu bar dropdown redesign (dark-glass panel theo design Tonal).
//
//  v2.4.0 — đồng bộ theme + chau chuốt:
//  • Header trạng thái: cờ + "Tiếng Việt"/"English" + sub (kiểu gõ) +
//    segmented VI|EN — thay hàng "Chuyển đổi ngôn ngữ" chữ thuần.
//  • VKMenuRow hợp nhất: hover animate easeOut, pressed scale 0.98,
//    icon hierarchical, icon nhuộm brand khi tính năng đang BẬT.
//  • Shortcut badge dạng keycap (⌘, / ⌘Q) thay chữ mono trần.
//  • Checkmark spring pop (scale 0.5→1) khi toggle.
//  • Popover giao diện: swatch màu theo từng theme (ink / kính / gradient)
//    thay icon drop.halffull chung chung.
//  • Footer 1 hàng icon (Ủng hộ · Thông tin · Cập nhật) + số phiên bản.
//  • VKMenuBarLabel: cờ bo góc + hairline cho status item (thay Image trần
//    trong vkeyApp.swift).
//

import Defaults
import SwiftUI

// MARK: - Đóng panel (window-style MenuBarExtra không tự đóng khi click item)

@MainActor func vkCloseMenuBarPanel() {
  for w in NSApp.windows {
    let n = String(describing: type(of: w))
    if n.contains("MenuBarExtra") { w.close(); return }
  }
  if let k = NSApp.keyWindow, k is NSPanel { k.close() }
}

// MARK: - Nền kính tối

private struct VKMenuBlur: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.material = .menu
    v.blendingMode = .behindWindow
    v.state = .active
    v.appearance = NSAppearance(named: .vibrantDark)
    return v
  }
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Press style (scale + dim nhẹ khi nhấn)

private struct VKMenuPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
  }
}

// MARK: - Hàng menu hợp nhất (hover animate + icon tint trạng thái)

private struct VKMenuRow<Trailing: View>: View {
  let icon: String
  let title: String
  /// Nhuộm icon khi tính năng đang bật (nil → trắng mặc định).
  var iconTint: Color? = nil
  var action: () -> Void
  @ViewBuilder var trailing: () -> Trailing

  @State private var hover = false

  init(_ icon: String, _ title: String,
       iconTint: Color? = nil,
       action: @escaping () -> Void,
       @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() })
  {
    self.icon = icon
    self.title = title
    self.iconTint = iconTint
    self.action = action
    self.trailing = trailing
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .medium))
          .symbolRenderingMode(.hierarchical)
          .frame(width: 18, height: 18)
          .foregroundStyle(hover ? Color.white : (iconTint ?? Color.white.opacity(0.85)))
        Text(title)
          .font(.system(size: 13))
          .foregroundStyle(Color.white.opacity(hover ? 1 : 0.95))
        Spacer(minLength: 8)
        trailing()
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          // Neural: hover gradient trí tuệ; theme khác: màu accent phẳng.
          .fill(hover ? AnyShapeStyle(VK.Color.brandGradient) : AnyShapeStyle(Color.clear))
      )
      .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    .buttonStyle(VKMenuPressStyle())
    .onHover { h in
      withAnimation(.easeOut(duration: 0.12)) { hover = h }
    }
  }
}

// MARK: - Mảnh phụ

private struct VKMenuSep: View {
  var body: some View {
    Rectangle()
      .fill(Color.white.opacity(0.08))
      .frame(height: 1)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
  }
}

/// Checkmark có pop spring khi bật/tắt.
private struct VKMenuCheck: View {
  var on: Bool
  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Color.white.opacity(0.92))
      .frame(width: 14)
      .scaleEffect(on ? 1 : 0.5)
      .opacity(on ? 1 : 0)
      .animation(.spring(response: 0.25, dampingFraction: 0.6), value: on)
  }
}

/// Badge phím tắt dạng keycap nhỏ (⌘, / ⌘Q).
private struct VKShortcutBadge: View {
  let label: String
  init(_ label: String) { self.label = label }
  var body: some View {
    Text(label)
      .font(.system(size: 11, weight: .medium, design: .monospaced))
      .foregroundStyle(Color.white.opacity(0.6))
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(Color.white.opacity(0.07))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
      )
  }
}

// MARK: - Panel chính

struct VKMenuPanel: View {
  @ObservedObject var appDelegate: AppDelegate
  @ObservedObject private var appState: AppState
  @Environment(\.openSettings) private var openSettings

  @Default(.smartSwitchEnabled) private var smartSwitchEnabled
  @Default(.spellCheckEnabled) private var spellCheckEnabled
  @Default(.macroEnabled) private var macroEnabled
  @Default(.newStyleTonePlacement) private var newStyleTonePlacement
  @Default(.uiTheme) private var uiTheme
  @State private var showThemes = false

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
    self.appState = appDelegate.appState
  }

  var body: some View {
    Group {
      if appDelegate.isTrusted { trustedBody } else { guideBody }
    }
    .padding(6)
    .frame(width: 280)
    .background(
      ZStack {
        VKMenuBlur()
        // Nền panel theo theme đang mở.
        if VK.isNeural {
          Color(vkHex: "#0F0F18").opacity(0.62)
        } else if VK.Glass.isOn {
          Color.black.opacity(max(0.08, 0.42 - VK.theme.clarity * 0.34))
        } else {
          Color.black.opacity(0.34)
        }
        // Top highlight "lit from above" — đồng bộ ngôn ngữ HUD.
        LinearGradient(
          colors: [Color.white.opacity(0.07), Color.white.opacity(0)],
          startPoint: .top, endPoint: .center)
      }
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.white.opacity(VK.Glass.isOn ? 0.25 : 0.12),
                      lineWidth: VK.Glass.isOn ? 1 : 0.5))
    // Neural: nhẫn gradient trí tuệ quanh panel (ai.css .win::after)
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(VK.Color.brandGradient, lineWidth: 1)
        .opacity(VK.isNeural ? 0.45 : 0))
    .id(uiTheme.rawValue) // re-render khi đổi theme (màu brand đọc per-theme)
  }

  // MARK: Trusted

  private var trustedBody: some View {
    VStack(alignment: .leading, spacing: 0) {

      statusHeader

      VKMenuSep()

      // Kiểu gõ
      VKMenuRow("keyboard", "Kiểu Telex",
                iconTint: appState.typingMethod == .Telex ? VK.Color.brand : nil,
                action: { appState.typingMethod = .Telex }) {
        VKMenuCheck(on: appState.typingMethod == .Telex)
      }
      VKMenuRow("keyboard.badge.ellipsis", "Kiểu VNI",
                iconTint: appState.typingMethod == .VNI ? VK.Color.brand : nil,
                action: { appState.typingMethod = .VNI }) {
        VKMenuCheck(on: appState.typingMethod == .VNI)
      }

      VKMenuSep()

      // Cài đặt
      VKMenuRow("gearshape", "Cài đặt", action: {
        NSApp.setActivationPolicy(.regular)
        try? openSettings()
        NSApp.activate(ignoringOtherApps: true)
        vkCloseMenuBarPanel()
      }) {
        VKShortcutBadge("⌘,")
      }

      // Toggles tính năng — icon nhuộm brand khi đang bật.
      VKMenuRow("arrow.left.arrow.right.circle", "Smart Switch",
                iconTint: smartSwitchEnabled ? VK.Color.brand : nil,
                action: { smartSwitchEnabled.toggle() }) {
        VKMenuCheck(on: smartSwitchEnabled)
      }
      VKMenuRow("textformat.abc.dottedunderline", "Sửa lỗi chính tả",
                iconTint: spellCheckEnabled ? VK.Color.brand : nil,
                action: { spellCheckEnabled.toggle() }) {
        VKMenuCheck(on: spellCheckEnabled)
      }
      VKMenuRow("text.append", "Macro",
                iconTint: macroEnabled ? VK.Color.brand : nil,
                action: { macroEnabled.toggle() }) {
        VKMenuCheck(on: macroEnabled)
      }

      // Chuyển giao diện nhanh
      themeSwitchMenu

      VKMenuSep()

      // Footer utility — 1 hàng icon, tiết kiệm 2 hàng dọc.
      footerRow

      VKMenuSep()

      // Thoát
      VKMenuRow("power", "Thoát", action: { NSApp.terminate(nil) }) {
        VKShortcutBadge("⌘Q")
      }
    }
  }

  // MARK: Header trạng thái — cờ + tên ngôn ngữ + kiểu gõ + segmented VI|EN

  private var statusHeader: some View {
    StatusHeaderRow(
      isVietnamese: appState.enabled,
      subtitle: appState.enabled
        ? "\(appState.typingMethod.rawValue) · \(newStyleTonePlacement ? "Kiểu mới" : "Kiểu cũ")"
        : "Bộ gõ tạm tắt",
      action: { appState.enabled.toggle() }
    )
  }

  private struct StatusHeaderRow: View {
    let isVietnamese: Bool
    let subtitle: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
      Button(action: action) {
        HStack(spacing: 10) {
          Image(isVietnamese ? "vn-flag" : "us-flag")
            .resizable().interpolation(.high)
            .frame(width: 26, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)

          VStack(alignment: .leading, spacing: 1) {
            Text(isVietnamese ? "Tiếng Việt" : "English")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white)
            Text(subtitle)
              .font(.system(size: 11))
              .foregroundStyle(Color.white.opacity(0.55))
          }

          Spacer(minLength: 8)

          // Segmented VI | EN
          HStack(spacing: 0) {
            segment("VI", active: isVietnamese)
            segment("EN", active: !isVietnamese)
          }
          .background(Capsule().fill(Color.white.opacity(0.07)))
          .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(hover ? 0.08 : 0.04))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
      .buttonStyle(VKMenuPressStyle())
      .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
    }

    private func segment(_ label: String, active: Bool) -> some View {
      Text(label)
        .font(.system(size: 10.5, weight: .bold))
        .foregroundStyle(active ? Color.white : Color.white.opacity(0.45))
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
          Capsule().fill(active ? AnyShapeStyle(VK.Color.brandGradient)
                                : AnyShapeStyle(Color.clear))
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: active)
    }
  }

  // MARK: Footer — Ủng hộ · Thông tin · Cập nhật + phiên bản

  private var footerRow: some View {
    HStack(spacing: 6) {
      footerIcon("cup.and.saucer.fill", help: "Ủng hộ tác giả") {
        appDelegate.openDonate(); vkCloseMenuBarPanel()
      }
      footerIcon("info.circle", help: "Thông tin dự án") {
        if let url = URL(string: "https://github.com/tuanlongsav/vkey") {
          NSWorkspace.shared.open(url)
        }
        vkCloseMenuBarPanel()
      }
      footerIcon("arrow.triangle.2.circlepath", help: "Kiểm tra cập nhật") {
        Updater.checkForUpdates(manual: true); vkCloseMenuBarPanel()
      }
      Spacer(minLength: 8)
      Text("vkey \(appVersion)")
        .font(.system(size: 10.5))
        .foregroundStyle(Color.white.opacity(0.35))
        .padding(.trailing, 6)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  }

  private struct FooterIconButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
      Button(action: action) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .medium))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(Color.white.opacity(hover ? 1 : 0.65))
          .frame(width: 30, height: 26)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(Color.white.opacity(hover ? 0.10 : 0))
          )
          .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
      .buttonStyle(VKMenuPressStyle())
      .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
      .help(help)
    }
  }

  private func footerIcon(_ icon: String, help: String, _ action: @escaping () -> Void) -> some View {
    FooterIconButton(icon: icon, help: help, action: action)
  }

  // MARK: Chuyển giao diện — swatch màu per-theme + popover xổ sang phải

  private var themeSwitchMenu: some View {
    VKMenuRow("paintbrush.pointed", "Chuyển giao diện",
              action: { showThemes.toggle() }) {
      HStack(spacing: 6) {
        themeSwatch(uiTheme, size: 12)
        Text(uiTheme.displayName)
          .font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.55))
        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Color.white.opacity(0.5))
      }
    }
    .popover(isPresented: $showThemes, arrowEdge: .trailing) {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(UITheme.allCases, id: \.self) { t in
          Button {
            uiTheme = t
            showThemes = false
          } label: {
            HStack(spacing: 10) {
              themeSwatch(t, size: 16)
                .overlay(
                  Circle().strokeBorder(
                    t == uiTheme ? VK.Color.brand : Color.primary.opacity(0.15),
                    lineWidth: t == uiTheme ? 1.5 : 1)
                )
              VStack(alignment: .leading, spacing: 1) {
                Text(t.displayName).font(.system(size: 13, weight: .medium))
                Text(t.caption).font(.system(size: 10.5)).foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Spacer(minLength: 12)
              Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VK.Color.brand)
                .opacity(t == uiTheme ? 1 : 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(width: 240, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(6)
    }
  }

  /// Swatch tròn đại diện theme: Tonal → mực+đỏ, Glass → kính trắng mờ,
  /// Neural → gradient trí tuệ.
  @ViewBuilder
  private func themeSwatch(_ t: UITheme, size: CGFloat) -> some View {
    switch t {
    case .neural:
      Circle()
        .fill(LinearGradient(
          colors: [Color(vkHex: "#8B5CF6"), Color(vkHex: "#22D3EE")],
          startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(width: size, height: size)
    case .glass:
      Circle()
        .fill(Color.white.opacity(0.22))
        .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
        .frame(width: size, height: size)
    case .tonal:
      Circle()
        .fill(LinearGradient(
          colors: [VK.Palette.ink400, VK.Palette.red500],
          startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(width: size, height: size)
    }
  }

  // MARK: Guide (chưa cấp quyền)

  private var guideBody: some View {
    VStack(alignment: .leading, spacing: 0) {
      VKMenuRow("questionmark.circle", "Hướng dẫn cấp quyền", action: {
        appDelegate.openGuide(); vkCloseMenuBarPanel()
      })
      VKMenuSep()
      VKMenuRow("power", "Thoát", action: { NSApp.terminate(nil) }) {
        VKShortcutBadge("⌘Q")
      }
    }
  }
}

// MARK: - Status item label (thay MenuBarLabel trong vkeyApp.swift)

/// Cờ bo góc + hairline cho status item — sắc nét hơn Image trần.
/// Dùng trong vkeyApp.swift:
///   label: { VKMenuBarLabel(appDelegate: appDelegate, appState: appDelegate.appState) }
struct VKMenuBarLabel: View {
  @ObservedObject var appDelegate: AppDelegate
  @ObservedObject var appState: AppState

  var body: some View {
    if !appDelegate.isTrusted {
      Image(systemName: "gear.badge.questionmark")
        .symbolRenderingMode(.hierarchical)
    } else if appState.secureInputActive {
      Image(systemName: "lock.square")
        .symbolRenderingMode(.hierarchical)
    } else {
      Image(appState.enabled ? "vn-flag" : "us-flag")
        .resizable()
        .interpolation(.high)
        .frame(width: 22, height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 3, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5))
    }
  }
}
