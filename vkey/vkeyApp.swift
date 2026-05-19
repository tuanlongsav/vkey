import Defaults
import SwiftUI

@main
struct vkeyApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra {
      MenuContentView(appDelegate: appDelegate)
    } label: {
      MenuBarLabel(appDelegate: appDelegate, appState: appDelegate.appState)
    }

    Settings {
      TabView {
        GeneralView()
          .environmentObject(appDelegate.appState)
          .tabItem { Label("Chung", themedSymbol: "gear") }

        SmartSwitchView()
          .tabItem { Label("Smart Switch", themedSymbol: "arrow.left.arrow.right.circle") }

        MacroView()
          .tabItem { Label("Macro", themedSymbol: "text.cursor") }

        SpellCheckView()
          .tabItem { Label("Chính tả", themedSymbol: "text.badge.checkmark") }

        // 1.5.0: Usage Statistics + personal-data backup/restore. Tab is the
        // single user-visible touchpoint for both features — keeping them
        // together emphasises that statistics never leave the machine.
        StatisticsView()
          .tabItem { Label("Thống kê & Sao lưu", themedSymbol: "chart.bar.doc.horizontal") }
      }
    }
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

  var body: some View {
    // MenuBarExtra (`.menu` style) renders SwiftUI Buttons as NSMenuItem.
    // Label(_:systemImage:) lets us pair an SF Symbol with the title — macOS
    // shows the symbol inside the standard menu-item icon slot, giving the
    // menu a more professional look that matches system menus.
    Button {
      appDelegate.appState.enabled.toggle()
    } label: {
      Label("Chuyển đổi bộ gõ  🇻🇳 | 🇺🇸", themedSymbol: "arrow.left.arrow.right.square")
    }

    Divider()

    Button {
      appDelegate.appState.typingMethod = .Telex
    } label: {
      Label(
        appDelegate.appState.typingMethod == .Telex ? "Kiểu Telex  ✓" : "Kiểu Telex",
        themedSymbol: "keyboard"
      )
    }

    Button {
      appDelegate.appState.typingMethod = .VNI
    } label: {
      Label(
        appDelegate.appState.typingMethod == .VNI ? "Kiểu VNI  ✓" : "Kiểu VNI",
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
        smartSwitchEnabled ? "Smart Switch  ✓" : "Smart Switch",
        themedSymbol: "arrow.left.arrow.right.circle"
      )
    }

    Button {
      spellCheckEnabled.toggle()
    } label: {
      Label(
        spellCheckEnabled ? "Sửa lỗi chính tả  ✓" : "Sửa lỗi chính tả",
        themedSymbol: "checkmark.circle"
      )
    }

    Button {
      macroEnabled.toggle()
    } label: {
      Label(
        macroEnabled ? "Macro  ✓" : "Macro",
        themedSymbol: "text.cursor"
      )
    }

    Menu {
      Button { appTheme = .default } label: {
        Label(
          appTheme == .default ? "Mặc định  ✓" : "Mặc định",
          themedSymbol: "circle"
        )
      }
      Button { appTheme = .threeD } label: {
        Label(
          appTheme == .threeD ? "3D  ✓" : "3D",
          themedSymbol: "cube"
        )
      }
    } label: {
      Label("Giao diện ứng dụng", themedSymbol: "paintbrush")
    }

    Divider()

    // Footer utility row: 3 icon nén thành 1 hàng cho gọn.
    MenuBarFooterRow(
      onDonate: { appDelegate.openDonate() },
      onInfo:   {
        if let url = URL(string: "https://github.com/tuanlongsav/vkey") {
          NSWorkspace.shared.open(url)
        }
      },
      onUpdate: { Updater.checkForUpdates(manual: true) }
    )

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
      Image(systemName: "gear.badge.questionmark")
    } else if appState.secureInputActive {
      Image(systemName: "lock.square")
    } else {
      Image(appState.enabled ? "vn-flag" : "us-flag")
        .resizable()
        .interpolation(.high)
        .frame(width: 22, height: 14)
    }
  }
}
