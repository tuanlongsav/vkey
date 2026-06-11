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
      // v2.4.0: VKMenuBarLabel (cờ bo góc + hairline) — định nghĩa trong
      // VKMenuBar.swift.
      VKMenuBarLabel(appDelegate: appDelegate, appState: appDelegate.appState)
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
