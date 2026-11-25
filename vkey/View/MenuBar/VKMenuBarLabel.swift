//
//  VKMenuBarLabel.swift
//  vkey
//
//  Biểu tượng trên thanh menu (cờ bo góc / khoá Secure Input / cảnh báo / Remote Desktop)
//  và helper đóng MenuBarExtra panel.
//

import AppKit
import SwiftUI

/// Đóng window-style MenuBarExtra panel sau khi click item.
@MainActor func vkCloseMenuBarPanel() {
  for w in NSApp.windows {
    let n = String(describing: type(of: w))
    if n.contains("MenuBarExtra") { w.close(); return }
  }
  if let k = NSApp.keyWindow, k is NSPanel { k.close() }
}

/// Cờ bo góc + hairline cho status item.
struct VKMenuBarLabel: View {
  @ObservedObject var appDelegate: AppDelegate
  @ObservedObject var appState: AppState

  static let secureInputWarningSymbol = "exclamationmark.triangle"
  static let remoteDesktopSymbol = "display"

  var body: some View {
    if !appDelegate.isTrusted {
      Image(systemName: "gear.badge.questionmark")
        .symbolRenderingMode(.hierarchical)
    } else if appState.secureInputActive {
      Image(systemName: "lock.square")
        .symbolRenderingMode(.hierarchical)
    } else if appState.remoteDesktopStandAside {
      Image(systemName: Self.remoteDesktopSymbol)
        .symbolRenderingMode(.hierarchical)
    } else if appState.secureInputHolderName != nil {
      Image(systemName: Self.secureInputWarningSymbol)
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
