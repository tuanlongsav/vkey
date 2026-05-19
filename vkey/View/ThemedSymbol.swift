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
        // Runtime fallback — 1.5.5 enhanced glossy:
        //  - 4-stop gradient mô phỏng ball lighting (top bright → mid
        //    dim → bottom bump để giả lập đáy phản chiếu).
        //  - Double shadow: outer accent halo + inner sharper drop
        //    để icon "nổi" hơn so với background.
        //  - `.hierarchical` rendering giúp SF Symbol multi-layer
        //    nhận gradient nhất quán.
        Image(systemName: name)
          .symbolRenderingMode(.hierarchical)
          .symbolVariant(.fill)
          .foregroundStyle(
            LinearGradient(
              stops: [
                .init(color: .accentColor,                      location: 0.0),
                .init(color: .accentColor.opacity(0.85),        location: 0.30),
                .init(color: .accentColor.opacity(0.55),        location: 0.70),
                .init(color: .accentColor.opacity(0.80),        location: 1.0),
              ],
              startPoint: .top, endPoint: .bottom
            )
          )
          .shadow(color: .accentColor.opacity(0.35), radius: 4, x: 0, y: 2)
          .shadow(color: .black.opacity(0.20),       radius: 1, x: 0, y: 0.5)
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
