//
//  VKBarControls.swift
//  vkey — VKAppearanceSegment: 3 nút Hệ thống/Sáng/Tối ở header Settings.
//

import Defaults
import SwiftUI

// MARK: - Appearance: 3 nút tách (Hệ thống / Sáng / Tối) — đặt trên-trái titlebar

struct VKAppearanceSegment: View {
  @Default(.appearanceMode) private var mode
  private let opts: [(mode: AppearanceMode, icon: String, label: String)] = [
    (.auto,  "circle.lefthalf.filled", "Hệ thống"),
    (.light, "sun.max.fill",           "Sáng"),
    (.dark,  "moon.fill",              "Tối"),
  ]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(opts, id: \.mode) { opt in
        let active = mode == opt.mode
        Button { mode = opt.mode } label: {
          Image(systemName: opt.icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(active ? Color.white : VK.Color.fgMuted)
            .frame(width: 26, height: 22)
            .background(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(active ? VK.Color.brand : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(opt.label)
      }
    }
  }
}
