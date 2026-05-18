//
//  vkeyApp.swift
//  vkey
//
//  Created by KhanhIceTea on 20/02/2024.
//

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
          .tabItem { Label("Chung", systemImage: "gear") }

        MacroView()
          .tabItem { Label("Macro", systemImage: "text.cursor") }
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
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    // MenuBarExtra (`.menu` style) renders SwiftUI Buttons as NSMenuItem.
    // Label(_:systemImage:) lets us pair an SF Symbol with the title — macOS
    // shows the symbol inside the standard menu-item icon slot, giving the
    // menu a more professional look that matches system menus.
    Button {
      appDelegate.appState.enabled.toggle()
    } label: {
      Label("Chuyển đổi bộ gõ  🇻🇳 | 🇺🇸", systemImage: "arrow.left.arrow.right.square")
    }

    Divider()

    Button {
      appDelegate.appState.typingMethod = .Telex
    } label: {
      Label(
        appDelegate.appState.typingMethod == .Telex ? "Kiểu Telex  ✓" : "Kiểu Telex",
        systemImage: "keyboard"
      )
    }

    Button {
      appDelegate.appState.typingMethod = .VNI
    } label: {
      Label(
        appDelegate.appState.typingMethod == .VNI ? "Kiểu VNI  ✓" : "Kiểu VNI",
        systemImage: "keyboard.badge.ellipsis"
      )
    }

    Divider()

    Button {
      // Promote to .regular so the Settings window can become key — required for
      // KeyboardShortcuts.Recorder to receive keystrokes from the global event stream.
      NSApp.setActivationPolicy(.regular)
      try? openSettings()
      NSApp.activate(ignoringOtherApps: true)
    } label: {
      Label("Cài đặt", systemImage: "gearshape")
    }
    // No .keyboardShortcut: AppKit reserves a right-column for shortcut hints
    // and widens the whole menu to fit, leaving an empty gap on items that
    // don't have a hint. Dropping the hint lets the menu shrink to text width.

    Button {
      appDelegate.openDonate()
    } label: {
      Label("Ủng hộ tác giả", systemImage: "cup.and.saucer")
    }
    
    Button {
      NSWorkspace.shared.open(URL(string: "https://github.com/tuanlongsav/vkey")!)
    } label: {
      Label("Thông tin dự án", systemImage: "info.circle")
    }
    
    Button {
      Updater.checkForUpdates(manual: true)
    } label: {
      Label("Kiểm tra cập nhật", systemImage: "arrow.triangle.2.circlepath")
    }

    Divider()

    Button {
      NSApp.terminate(nil)
    } label: {
      Label("Thoát", systemImage: "power")
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
