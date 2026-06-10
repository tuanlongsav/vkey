import Defaults
import SwiftUI

@main
struct vkeyApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra {
      // 2.16 redesign: dark-glass panel (VKMenuPanel) thay menu native,
      // khớp design Tonal. .window style để render SwiftUI custom panel.
      VKMenuPanel(appDelegate: appDelegate)
        .tint(VK.Color.brand)
    } label: {
      MenuBarLabel(appDelegate: appDelegate, appState: appDelegate.appState)
    }
    .menuBarExtraStyle(.window)

    Settings {
      // 2.16 redesign: NavigationSplitView (sidebar 232pt) thay TabView.
      VKSettingsView()
        .environmentObject(appDelegate.appState)
        .tint(VK.Color.brand)
    }
    .windowResizability(.contentMinSize)
    .defaultSize(width: 860, height: 640)
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
