import Defaults
import SwiftUI

@main
struct vkeyApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  // v2.1.1: theme reactive container — drives `.tint()` overrides on
  // Settings + MenuBar so accent color tracks the user's theme choice.
  @StateObject private var themeManager = ThemeManager.shared

  var body: some Scene {
    MenuBarExtra {
      MenuContentView(appDelegate: appDelegate)
        .tint(themeManager.current.accentColor)
        // v2.3.3: LG theme — opt-in GlassTile wrap cho mỗi menu item icon.
        // ThemedSymbol đọc `\.useGlassTile` từ env; khi true + uiTheme=.liquidGlass
        // → wrap SF Symbol trong glass tile colored (per design MenuBar.jsx).
        // MenuBarLabel (label closure bên dưới) KHÔNG nhận env này → status
        // bar icon giữ flat SF Symbol (match macOS menu bar conventions).
        .environment(\.useGlassTile, themeManager.current == .liquidGlass)
    } label: {
      MenuBarLabel(appDelegate: appDelegate, appState: appDelegate.appState)
    }

    Settings {
      TabView {
        GeneralView()
          .environmentObject(appDelegate.appState)
          .tabItem {
            Label("Chung", themedSymbol: "gear")
              .font(.system(size: 10))
          }

        // 1.7.8: restore label gốc "Smart Switch" (1.7.7 đã rút gọn nhưng
        // mất ngữ nghĩa). Bù lại bằng .font(.system(size: 10)) để tab bar
        // vẫn compact.
        SmartSwitchView()
          .tabItem {
            Label("Smart Switch", themedSymbol: "arrow.left.arrow.right.circle")
              .font(.system(size: 10))
          }

        MacroView()
          .tabItem {
            Label("Macro", themedSymbol: "text.cursor")
              .font(.system(size: 10))
          }

        SpellCheckView()
          .tabItem {
            Label("Chính tả", themedSymbol: "text.badge.checkmark")
              .font(.system(size: 10))
          }

        // 2.0.1: tab Rules đã được embed vào SmartSwitchView dưới dạng
        // DisclosureGroup. Bỏ tab riêng để gọn UI + share code.

        // 1.5.0: Usage Statistics + personal-data backup/restore. Tab is the
        // single user-visible touchpoint for both features — keeping them
        // together emphasises that statistics never leave the machine.
        // 1.7.8: restore label gốc "Thống kê & Sao lưu".
        StatisticsView()
          .tabItem {
            Label("Thống kê & Sao lưu", themedSymbol: "chart.bar.doc.horizontal")
              .font(.system(size: 10))
          }
      }
      // v2.1.1: tint the whole Settings TabView with the active theme's
      // accent color so Toggles, Pickers, focus rings, and SwiftUI control
      // chrome all match. Classic → system blue; Tonal → brand red.
      .tint(themeManager.current.accentColor)
      // v2.3.3: LG theme — wrap tab item icons + setting row icons trong
      // GlassTile. Identical opt-in mechanism với MenuContentView ở trên.
      .environment(\.useGlassTile, themeManager.current == .liquidGlass)
    }
    // 1.7.6: cho phép user resize Settings window qua góc/cạnh. Default
    // .automatic enforces non-resizable + sized-to-content trong macOS 13+
    // → user không thay đổi được width. `.contentMinSize` cho phép drag
    // shrink xuống min của view content (.frame(minWidth:...)).
    .windowResizability(.contentMinSize)
    // 1.7.8: opening size compact (432×648). Height giảm 40% so với 1080
    // của 1.7.7 (user feedback "quá dài"). User vẫn drag resize được tự do.
    // 1.8.4: width 432→540 — fit nút "Chạy compute đề xuất ngay" (text VN
    // dài) trong tab Thống kê. Height giữ nguyên.
    .defaultSize(width: 540, height: 648)
    // v2.1.1: theme override for Settings — switches accent at the scene
    // root so all child Toggle/Picker/focus rings track the active theme
    // without per-view boilerplate.
    .environmentObject(themeManager)
  }
}

struct MenuContentView: View {
  @ObservedObject var appDelegate: AppDelegate

  var body: some View {
    if appDelegate.isTrusted {
      MainMenuView(appDelegate: appDelegate)
    } else {
      GuideMenuView(appDelegate: appDelegate)
    }
  }
}

struct MainMenuView: View {
  @ObservedObject var appDelegate: AppDelegate
  // SwiftUI's OpenSettingsAction (macOS 14+) is the *reliable* way to open
  // the Settings scene from a MenuBarExtra. Using
  // `NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)`
  // looks equivalent but races the .accessory→.regular activation policy
  // change — the responder chain often has no handler yet and the action
  // silently fails. That regression (introduced in 1.5.0) is what made the
  // "Cài đặt" menu item appear unresponsive.
  @Environment(\.openSettings) private var openSettings
  @Default(.smartSwitchEnabled) private var smartSwitchEnabled
  @Default(.spellCheckEnabled) private var spellCheckEnabled
  @Default(.macroEnabled) private var macroEnabled
  @Default(.appTheme) private var appTheme
  // v2.2.0: unified theme menu — đọc cả 2 axes.
  @Default(.uiTheme) private var uiTheme

  /// v2.2.0: helper hiển thị ✓ — check cả 2 axes đều khớp.
  private func isAppearance(_ ui: UITheme, _ icon: AppTheme) -> Bool {
    uiTheme == ui && appTheme == icon
  }

  /// v2.2.0: set cả 2 axes nguyên tử + apply icon switch ngay.
  private func setAppearance(ui: UITheme, icon: AppTheme) {
    appTheme = icon
    uiTheme = ui
    AppIconSwitcher.apply(theme: ui)
  }

  var body: some View {
    // MenuBarExtra (`.menu` style) renders SwiftUI Buttons as NSMenuItem.
    // Label(_:systemImage:) lets us pair an SF Symbol with the title — macOS
    // shows the symbol inside the standard menu-item icon slot, giving the
    // menu a more professional look that matches system menus.
    Button {
      appDelegate.appState.enabled.toggle()
    } label: {
      Label("Chuyển đổi ngôn ngữ 🇻🇳 | 🇺🇸", themedSymbol: "arrow.left.arrow.right.square")
    }

    Divider()

    Button {
      appDelegate.appState.typingMethod = .Telex
    } label: {
      Label(
        appDelegate.appState.typingMethod == .Telex ? "Kiểu Telex ✓" : "Kiểu Telex",
        themedSymbol: "keyboard"
      )
    }

    Button {
      appDelegate.appState.typingMethod = .VNI
    } label: {
      Label(
        appDelegate.appState.typingMethod == .VNI ? "Kiểu VNI ✓" : "Kiểu VNI",
        themedSymbol: "keyboard.badge.ellipsis"
      )
    }

    Divider()

    // Cài đặt và SmartSwitch cùng 1 section
    Button {
      // Promote to .regular so the Settings window can become key — required for
      // KeyboardShortcuts.Recorder to receive keystrokes from the global event stream.
      NSApp.setActivationPolicy(.regular)
      try? openSettings()
      NSApp.activate(ignoringOtherApps: true)
    } label: {
      Label("Cài đặt", themedSymbol: "gearshape")
    }

    Button {
      smartSwitchEnabled.toggle()
    } label: {
      Label(
        smartSwitchEnabled ? "Smart Switch ✓" : "Smart Switch",
        themedSymbol: "arrow.left.arrow.right.circle"
      )
    }

    Button {
      spellCheckEnabled.toggle()
    } label: {
      Label(
        spellCheckEnabled ? "Sửa lỗi chính tả ✓" : "Sửa lỗi chính tả",
        themedSymbol: "checkmark.circle"
      )
    }

    Button {
      macroEnabled.toggle()
    } label: {
      Label(
        macroEnabled ? "Macro ✓" : "Macro",
        themedSymbol: "text.cursor"
      )
    }

    // v2.2.2: 4 themes — xoá "3D bóng bẩy" (icon style threeD) và "Sơn Mài"
    // theo user request. Thêm "Liquid Glass" (refractive glass macOS Tahoe).
    // Mỗi option set CẢ `appTheme` (icon style) lẫn `uiTheme`.
    Menu {
      Button { setAppearance(ui: .classic, icon: .default) } label: {
        Label(
          isAppearance(.classic, .default) ? "Mặc định ✓" : "Mặc định",
          themedSymbol: "circle"
        )
      }
      Button { setAppearance(ui: .classic, icon: .emoji) } label: {
        Label(
          isAppearance(.classic, .emoji) ? "Emoji vui tươi ✓" : "Emoji vui tươi",
          themedSymbol: "sparkles"
        )
      }
      Divider()
      Button { setAppearance(ui: .tonal, icon: .default) } label: {
        Label(
          isAppearance(.tonal, .default) ? "Tonal ✓" : "Tonal",
          themedSymbol: "paintpalette"
        )
      }
      Button { setAppearance(ui: .liquidGlass, icon: .default) } label: {
        Label(
          isAppearance(.liquidGlass, .default) ? "Liquid Glass ✓" : "Liquid Glass",
          themedSymbol: "drop.halffull"
        )
      }
    } label: {
      Label("Giao diện ứng dụng", themedSymbol: "paintbrush")
    }

    Divider()

    Button {
      appDelegate.openDonate()
    } label: {
      Label("Ủng hộ tác giả", themedSymbol: "cup.and.saucer")
    }

    Button {
      if let url = URL(string: "https://github.com/tuanlongsav/vkey") {
        NSWorkspace.shared.open(url)
      }
    } label: {
      Label("Thông tin dự án", themedSymbol: "info.circle")
    }

    Button {
      Updater.checkForUpdates(manual: true)
    } label: {
      Label("Kiểm tra cập nhật", themedSymbol: "arrow.triangle.2.circlepath")
    }

    Divider()

    Button {
      NSApp.terminate(nil)
    } label: {
      Label("Thoát", themedSymbol: "power")
    }
  }
}

struct GuideMenuView: View {
  @ObservedObject var appDelegate: AppDelegate

  var body: some View {
    Button("Hướng dẫn cài đặt") {
      appDelegate.openGuide()
    }
    
    Divider()
    
    Button("Thoát") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q", modifiers: .command)
  }
}

struct MenuBarLabel: View {
  @ObservedObject var appDelegate: AppDelegate
  @ObservedObject var appState: AppState

  var body: some View {
    if !appDelegate.isTrusted {
      ThemedSymbol(name: "gear.badge.questionmark")
    } else if appState.secureInputActive {
      ThemedSymbol(name: "lock.square")
    } else {
      Image(appState.enabled ? "vn-flag" : "us-flag")
        .resizable()
        .interpolation(.high)
        .frame(width: 22, height: 14)
    }
  }
}
