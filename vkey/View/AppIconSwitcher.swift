//
//  AppIconSwitcher.swift
//  vkey
//
//  v2.1.1: switch the app's icon at runtime when the theme changes.
//
//  vkey is `LSUIElement = YES` (no Dock icon), so the "app icon" only
//  surfaces in: notification banners, dock badge if shown, and per-frame
//  alert dialogs. The Finder Get Info / About-box icon comes from the
//  compiled `AppIcon.icns` and is fixed at build time.
//
//  We update `NSApplication.shared.applicationIconImage` whenever the
//  user picks a theme so notifications match the active theme.
//

import AppKit

enum AppIconSwitcher {
    @MainActor
    static func apply(theme: UITheme) {
        // Both imagesets ship at full size in the asset catalog and are
        // loadable by name. The "Cficon" family is a regular imageset (not
        // an .appiconset), so NSImage(named:) is reliable.
        let imageName: String
        switch theme {
        case .tonal:   imageName = "Cficon"
        case .classic: imageName = "CficonClassic"
        }
        guard let img = NSImage(named: imageName) else { return }
        NSApplication.shared.applicationIconImage = img
    }
}
