//
//  MenuBarFooterRow.swift
//  vkey
//
//  Footer row trong MenuBarExtra dropdown gom 3 action utility
//  (Ủng hộ tác giả / Thông tin dự án / Kiểm tra cập nhật) thành 1 hàng
//  icon-only để tiết kiệm không gian dọc.
//
//  Trong MenuBarExtra `.menu` style, SwiftUI `HStack` đặt thẳng giữa
//  các `Button` sẽ được wrap thành một NSMenuItem custom-view trên
//  macOS 14+. Mỗi icon là một SwiftUI `Button` + `.help(...)` tooltip
//  để user biết nó làm gì khi hover. Click vào icon đóng menu (do bản
//  thân Button trong menu context tự dismiss).
//

import AppKit
import SwiftUI

struct MenuBarFooterRow: View {
  let onDonate: () -> Void
  let onInfo: () -> Void
  let onUpdate: () -> Void

  var body: some View {
    HStack(spacing: 24) {
      iconButton(
        systemName: "cup.and.saucer.fill",
        help: "Ủng hộ tác giả",
        action: onDonate
      )
      iconButton(
        systemName: "info.circle.fill",
        help: "Thông tin dự án",
        action: onInfo
      )
      iconButton(
        systemName: "arrow.triangle.2.circlepath.circle.fill",
        help: "Kiểm tra cập nhật",
        action: onUpdate
      )
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private func iconButton(
    systemName: String,
    help: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      ThemedSymbol(name: systemName)
        .font(.system(size: 18, weight: .medium))
        .frame(width: 28, height: 28)
    }
    .buttonStyle(.plain)
    .help(help)
  }
}
