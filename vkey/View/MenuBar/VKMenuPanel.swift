//
//  VKMenuPanel.swift
//  vkey — Menu bar dropdown panel (dark-glass theo theme đang chọn).
//

import Defaults
import SwiftUI

struct VKMenuPanel: View {
  @ObservedObject var appDelegate: AppDelegate
  @ObservedObject private var appState: AppState
  @Environment(\.openSettings) private var openSettings

  @Default(.smartSwitchEnabled) private var smartSwitchEnabled
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
        VKVisualEffect.menuDark
        if VK.isNeural {
          Color(vkHex: "#0F0F18").opacity(0.62)
        } else if VK.Glass.isOn {
          Color.black.opacity(max(0.08, 0.42 - VK.theme.clarity * 0.34))
        } else {
          Color.black.opacity(0.34)
        }
        LinearGradient(
          colors: [Color.white.opacity(0.07), Color.white.opacity(0)],
          startPoint: .top, endPoint: .center)
      }
    )
    .clipShape(RoundedRectangle(cornerRadius: VK.Radius.scaled(12), style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: VK.Radius.scaled(12), style: .continuous)
        .strokeBorder(
          Color.white.opacity(VK.Glass.isOn ? 0.25 : 0.12),
          lineWidth: VK.Glass.isOn ? 1 : 0.5))
    .overlay(
      RoundedRectangle(cornerRadius: VK.Radius.scaled(12), style: .continuous)
        .strokeBorder(VK.Color.brandGradient, lineWidth: 1)
        .opacity(VK.isNeural ? 0.45 : 0))
    .id(uiTheme.rawValue)
  }

  // MARK: Trusted

  private var trustedBody: some View {
    VStack(alignment: .leading, spacing: 0) {
      statusHeader

      if let holder = appState.secureInputHolderName {
        secureInputNotice(holder)
      }

      VKMenuSep()

      VKMenuRow(
        "keyboard", "Kiểu Telex",
        iconTint: appState.typingMethod == .Telex ? VK.Color.brand : nil,
        action: { appState.typingMethod = .Telex }
      ) {
        VKMenuCheck(on: appState.typingMethod == .Telex)
      }
      VKMenuRow(
        "keyboard.badge.ellipsis", "Kiểu VNI",
        iconTint: appState.typingMethod == .VNI ? VK.Color.brand : nil,
        action: { appState.typingMethod = .VNI }
      ) {
        VKMenuCheck(on: appState.typingMethod == .VNI)
      }

      VKMenuSep()

      VKMenuRow("gearshape", "Cài đặt", action: {
        NSApp.setActivationPolicy(.regular)
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
        vkCloseMenuBarPanel()
      }) {
        VKShortcutBadge("⌘,")
      }

      VKMenuRow(
        "arrow.left.arrow.right.circle", "Smart Switch",
        iconTint: smartSwitchEnabled ? VK.Color.brand : nil,
        action: { smartSwitchEnabled.toggle() }
      ) {
        VKMenuCheck(on: smartSwitchEnabled)
      }
      VKMenuRow(
        "text.append", "Macro",
        iconTint: macroEnabled ? VK.Color.brand : nil,
        action: { macroEnabled.toggle() }
      ) {
        VKMenuCheck(on: macroEnabled)
      }
      themeSwitchMenu

      VKMenuSep()

      footerRow

      VKMenuSep()

      VKMenuRow("power", "Thoát", action: { NSApp.terminate(nil) }) {
        VKShortcutBadge("⌘Q")
      }
    }
  }

  private var statusHeader: some View {
    VKStatusHeaderRow(
      isVietnamese: appState.enabled,
      subtitle: appState.remoteDesktopStandAside
        ? "Đứng ngoài · máy kia lo việc gõ"
        : appState.enabled
          ? "\(appState.typingMethod.rawValue) · \(newStyleTonePlacement ? "Kiểu mới" : "Kiểu cũ")"
          : "Bộ gõ tạm tắt",
      action: { appState.setEnabledByUser(!appState.enabled) }
    )
  }

  private func secureInputNotice(_ holder: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: VKMenuBarLabel.secureInputWarningSymbol + ".fill")
        .font(.system(size: 12))
        .foregroundStyle(.yellow)
      Text("\(holder) đang giữ Secure Input dù bạn không ở ô mật khẩu, nên macOS có thể không chuyển phím cho vkey (gõ không ra dấu). Mở \(holder) và bấm ra ngoài ô mật khẩu, hoặc thoát nó. Nếu không được, khoá màn hình rồi mở khoá lại.")
        .font(VK.Font.sans(11))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
  }

  private var footerRow: some View {
    HStack(spacing: 6) {
      VKFooterIconButton(icon: "cup.and.saucer.fill", help: "Ủng hộ tác giả") {
        appDelegate.openDonate(); vkCloseMenuBarPanel()
      }
      VKFooterIconButton(icon: "info.circle", help: "Thông tin dự án") {
        if let url = URL(string: "https://github.com/tuanlongsav/vkey") {
          NSWorkspace.shared.open(url)
        }
        vkCloseMenuBarPanel()
      }
      VKFooterIconButton(icon: "arrow.triangle.2.circlepath", help: "Kiểm tra cập nhật") {
        Updater.checkForUpdates(manual: true); vkCloseMenuBarPanel()
      }
      Spacer(minLength: 8)
      Text("vkey \(appVersion)")
        .font(VK.Font.sans(10.5))
        .foregroundStyle(Color.white.opacity(0.35))
        .padding(.trailing, 6)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  }

  private var themeSwitchMenu: some View {
    VKMenuRow("paintbrush.pointed", "Chuyển giao diện", action: { showThemes.toggle() }) {
      HStack(spacing: 6) {
        VKThemeSwatch(theme: uiTheme, size: 12)
        Text(uiTheme.displayName)
          .font(VK.Font.sans(11.5)).foregroundStyle(Color.white.opacity(0.55))
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
              VKThemeSwatch(theme: t, size: 16)
                .overlay(
                  Circle().strokeBorder(
                    t == uiTheme ? VK.Color.brand : Color.primary.opacity(0.15),
                    lineWidth: t == uiTheme ? 1.5 : 1)
                )
              VStack(alignment: .leading, spacing: 1) {
                Text(t.displayName).font(VK.Font.sans(13, .medium))
                Text(t.caption).font(VK.Font.sans(10.5)).foregroundStyle(.secondary)
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
      VKMenuRow("questionmark.circle", "Hướng dẫn cấp quyền", action: {
        appDelegate.openOnboarding(); vkCloseMenuBarPanel()
      })
      VKMenuSep()
      VKMenuRow("power", "Thoát", action: { NSApp.terminate(nil) }) {
        VKShortcutBadge("⌘Q")
      }
    }
  }
}
