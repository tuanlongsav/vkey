//
//  ThemedSymbol.swift
//  vkey
//
//  Wrapper hiển thị icon theo `Defaults[.appTheme]`. Thay cho
//  `Image(systemName:)` ở mọi nơi không phải là menu bar state flag /
//  AppIcon (giữ nguyên flag VN/US PNG và AppIcon mặc định).
//
//  Hai theme:
//
//  - `.default`: render SF Symbol gốc, không hiệu ứng.
//  - `.threeD`: ưu tiên 1 bitmap PDF ở `Assets.xcassets/Icons3D/<name>`
//    (Phase 6b — designer có thể drop artwork sau). Nếu chưa có asset,
//    fallback runtime: SF Symbol + `.symbolRenderingMode(.multicolor)` +
//    `.symbolVariant(.fill)` + LinearGradient foreground + shadow để
//    mang cảm giác "3D-ish" / glossy.
//
//  Đối với `Label(_, systemImage:)`, dùng extension
//  `Label(_, themedSymbol:)` thay vì wrap thủ công ThemedSymbol +
//  Text trong icon builder.
//

import AppKit
import Defaults
import SwiftUI

struct ThemedSymbol: View {
  let name: String
  @Default(.appTheme) private var theme

  var body: some View {
    switch theme {
    case .default:
      Image(systemName: name)
    case .threeD:
      if NSImage(named: "Icons3D/\(name)") != nil {
        Image("Icons3D/\(name)")
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        // Runtime fallback effects.
        Image(systemName: name)
          .symbolRenderingMode(.multicolor)
          .symbolVariant(.fill)
          .foregroundStyle(
            LinearGradient(
              colors: [.accentColor, .accentColor.opacity(0.65)],
              startPoint: .top, endPoint: .bottom
            )
          )
          .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 1)
      }
    }
  }
}

extension Label where Title == Text, Icon == ThemedSymbol {
  /// Drop-in thay cho `Label(_, systemImage:)`. Icon render qua
  /// `ThemedSymbol` để tự đổi theo `Defaults[.appTheme]`.
  init(_ title: String, themedSymbol name: String) {
    self.init {
      Text(title)
    } icon: {
      ThemedSymbol(name: name)
    }
  }
}
