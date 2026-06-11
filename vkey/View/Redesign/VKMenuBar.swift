//
//  VKMenuBar.swift
//  vkey — Menu bar dropdown redesign (dark-glass panel theo design Tonal).
//  Thay menu native (.menu) bằng panel custom (.window style) khớp pixel:
//  280pt, kính tối, hàng hover brand, separators, check trắng, cờ VN|US.
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

// MARK: - Style hàng (hover → brand)

private struct VKMenuItemStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    VKMenuItemBody(configuration: configuration)
  }
  struct VKMenuItemBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var hover = false
    var body: some View {
      configuration.label
        .padding(.horizontal, 10)
        .frame(height: 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            // Neural: hover gradient trí tuệ; theme khác: màu accent phẳng.
            .fill(hover ? AnyShapeStyle(VK.Color.brandGradient) : AnyShapeStyle(Color.clear)))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .opacity(configuration.isPressed ? 0.8 : 1)
    }
  }
}

// MARK: - Mảnh dựng hàng

private struct VKMenuLabel: View {
  let icon: String
  let title: String
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 13, weight: .regular))
        .frame(width: 16, height: 16)
        .foregroundStyle(.white.opacity(0.88))
      Text(title)
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.95))
      Spacer(minLength: 8)
    }
  }
}

private struct VKMenuSep: View {
  var body: some View {
    Rectangle()
      .fill(Color.white.opacity(0.10))
      .frame(height: 1)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
  }
}

private struct VKMenuCheck: View {
  var on: Bool
  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.white.opacity(on ? 0.9 : 0))
      .frame(width: 14)
  }
}

// MARK: - Panel chính

struct VKMenuPanel: View {
  @ObservedObject var appDelegate: AppDelegate
  // Observe TRỰC TIẾP AppState — trước đây chỉ observe appDelegate nên khi
  // enabled/typingMethod đổi, panel không re-render (cờ VN luôn sáng, ✓ Telex
  // không nhảy).
  @ObservedObject private var appState: AppState
  @Environment(\.openSettings) private var openSettings

  @Default(.smartSwitchEnabled) private var smartSwitchEnabled
  @Default(.spellCheckEnabled) private var spellCheckEnabled
  @Default(.macroEnabled) private var macroEnabled
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
        // Nền panel theo theme đang mở:
        // Neural → obsidian tím · Liquid Glass → trong hơn (theo độ trong
        // suốt) · Mặc định → đen mờ chuẩn.
        if VK.isNeural {
          Color(vkHex: "#0F0F18").opacity(0.62)
        } else if VK.Glass.isOn {
          Color.black.opacity(max(0.08, 0.42 - VK.theme.clarity * 0.34))
        } else {
          Color.black.opacity(0.34)
        }
      }
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.white.opacity(VK.Glass.isOn ? 0.25 : 0.12),
                      lineWidth: VK.Glass.isOn ? 1 : 0.5))
    // Neural: nhẫn gradient trí tuệ quanh panel (ai.css .win::after)
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(VK.Color.brandGradient, lineWidth: 1)
        .opacity(VK.isNeural ? 0.45 : 0))
    .id(uiTheme.rawValue) // re-render khi đổi theme (màu brand đọc per-theme)
  }

  // MARK: Trusted

  private var trustedBody: some View {
    VStack(alignment: .leading, spacing: 0) {

      // Chuyển đổi ngôn ngữ — kèm cờ VN | US
      Button {
        appState.enabled.toggle()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "arrow.left.arrow.right")
            .font(.system(size: 13)).frame(width: 16, height: 16)
            .foregroundStyle(.white.opacity(0.88))
          Text("Chuyển đổi ngôn ngữ").font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.95))
          Spacer(minLength: 8)
          HStack(spacing: 4) {
            flag("vn-flag", active: appState.enabled)
            Text("|").foregroundStyle(.white.opacity(0.3)).font(.system(size: 12))
            flag("us-flag", active: !appState.enabled)
          }
        }
      }.buttonStyle(VKMenuItemStyle())

      VKMenuSep()

      // Kiểu gõ
      toggleRow("keyboard", "Kiểu Telex", on: appState.typingMethod == .Telex) {
        appState.typingMethod = .Telex
      }
      toggleRow("keyboard.badge.ellipsis", "Kiểu VNI", on: appState.typingMethod == .VNI) {
        appState.typingMethod = .VNI
      }

      VKMenuSep()

      // Cài đặt
      Button {
        NSApp.setActivationPolicy(.regular)
        try? openSettings()
        NSApp.activate(ignoringOtherApps: true)
        vkCloseMenuBarPanel()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "gearshape").font(.system(size: 13))
            .frame(width: 16, height: 16).foregroundStyle(.white.opacity(0.88))
          Text("Cài đặt").font(.system(size: 13)).foregroundStyle(.white.opacity(0.95))
          Spacer(minLength: 8)
          Text("⌘,").font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
        }
      }.buttonStyle(VKMenuItemStyle())

      // Toggles tính năng
      toggleRow("arrow.left.arrow.right.circle", "Smart Switch", on: smartSwitchEnabled) {
        smartSwitchEnabled.toggle()
      }
      toggleRow("checkmark.circle", "Sửa lỗi chính tả", on: spellCheckEnabled) {
        spellCheckEnabled.toggle()
      }
      toggleRow("text.cursor", "Macro", on: macroEnabled) {
        macroEnabled.toggle()
      }

      // Chuyển giao diện nhanh (đồng bộ cài đặt tab Quản lý giao diện)
      themeSwitchMenu

      VKMenuSep()

      // Khác
      plainRow("cup.and.saucer", "Ủng hộ tác giả") {
        appDelegate.openDonate(); vkCloseMenuBarPanel()
      }
      plainRow("info.circle", "Thông tin dự án") {
        if let url = URL(string: "https://github.com/tuanlongsav/vkey") {
          NSWorkspace.shared.open(url)
        }
        vkCloseMenuBarPanel()
      }
      plainRow("arrow.triangle.2.circlepath", "Kiểm tra cập nhật") {
        Updater.checkForUpdates(manual: true); vkCloseMenuBarPanel()
      }

      VKMenuSep()

      // Thoát
      Button {
        NSApp.terminate(nil)
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "power").font(.system(size: 13))
            .frame(width: 16, height: 16).foregroundStyle(.white.opacity(0.88))
          Text("Thoát").font(.system(size: 13)).foregroundStyle(.white.opacity(0.95))
          Spacer(minLength: 8)
          Text("⌘Q").font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
        }
      }.buttonStyle(VKMenuItemStyle())
    }
  }

  // MARK: Chuyển giao diện — Button (icon trắng đồng bộ) + popover xổ sang phải

  private var themeSwitchMenu: some View {
    Button { showThemes.toggle() } label: {
      HStack(spacing: 10) {
        Image(systemName: "paintbrush")
          .font(.system(size: 13))
          .frame(width: 16, height: 16)
          .foregroundStyle(.white.opacity(0.88))
        Text("Chuyển giao diện").font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.95))
        Spacer(minLength: 8)
        Text(uiTheme.displayName)
          .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55))
        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.white.opacity(0.5))
      }
    }
    .buttonStyle(VKMenuItemStyle())
    .tint(.white) // tránh bị nhuộm accent như Menu trước
    .popover(isPresented: $showThemes, arrowEdge: .trailing) {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(UITheme.allCases, id: \.self) { t in
          Button {
            uiTheme = t
            showThemes = false
          } label: {
            HStack(spacing: 10) {
              Image(systemName: t == .glass ? "drop.halffull" : "circle.lefthalf.filled")
                .font(.system(size: 12)).frame(width: 16)
                .foregroundStyle(t == uiTheme ? VK.Color.brand : Color.primary.opacity(0.7))
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

  // MARK: Guide (chưa cấp quyền)

  private var guideBody: some View {
    VStack(alignment: .leading, spacing: 0) {
      plainRow("questionmark.circle", "Hướng dẫn cấp quyền") {
        appDelegate.openGuide(); vkCloseMenuBarPanel()
      }
      VKMenuSep()
      Button { NSApp.terminate(nil) } label: {
        VKMenuLabel(icon: "power", title: "Thoát")
      }.buttonStyle(VKMenuItemStyle())
    }
  }

  // MARK: Helpers

  private func flag(_ name: String, active: Bool) -> some View {
    Image(name).resizable().interpolation(.high)
      .frame(width: 18, height: 13)
      .clipShape(RoundedRectangle(cornerRadius: 2))
      .opacity(active ? 1 : 0.4)
  }

  private func toggleRow(_ icon: String, _ title: String, on: Bool, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon).font(.system(size: 13))
          .frame(width: 16, height: 16).foregroundStyle(.white.opacity(0.88))
        Text(title).font(.system(size: 13)).foregroundStyle(.white.opacity(0.95))
        Spacer(minLength: 8)
        VKMenuCheck(on: on)
      }
    }.buttonStyle(VKMenuItemStyle())
  }

  private func plainRow(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) { VKMenuLabel(icon: icon, title: title) }
      .buttonStyle(VKMenuItemStyle())
  }
}
