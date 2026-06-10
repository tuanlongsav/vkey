//
//  VKBarControls.swift
//  vkey — control góc trên: chọn màu accent + sáng/tối (gọn vào 2 nút).
//

import Defaults
import SwiftUI

// MARK: - Accent color: 1 nút swatch, click mở popover chọn 5 màu

struct VKAccentButton: View {
  @Default(.accentColorChoice) private var choice
  @State private var open = false

  var body: some View {
    Button { open.toggle() } label: {
      HStack(spacing: 5) {
        Circle()
          .fill(VK.Color.accentSwatch(choice))
          .frame(width: 14, height: 14)
          .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
        Image(systemName: "chevron.down")
          .font(.system(size: 8, weight: .semibold))
          .foregroundStyle(VK.Color.fgMuted)
      }
      .padding(.horizontal, 8)
      .frame(height: 24)
      .background(
        Capsule().fill(VK.Color.bgElevated)
          .overlay(Capsule().strokeBorder(VK.Color.border1, lineWidth: 1))
      )
    }
    .buttonStyle(.plain)
    .help("Màu accent")
    .popover(isPresented: $open, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: 8) {
        Text("MÀU ACCENT")
          .font(.vk(.eyebrow)).tracking(0.6)
          .foregroundStyle(VK.Color.fgMuted)
        HStack(spacing: 10) {
          ForEach(AccentColorChoice.allCases, id: \.self) { c in
            Button {
              choice = c
            } label: {
              Circle()
                .fill(VK.Color.accentSwatch(c))
                .frame(width: 24, height: 24)
                .overlay(
                  Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(choice == c ? 1 : 0)
                )
                .overlay(
                  Circle().strokeBorder(VK.Color.fg2, lineWidth: choice == c ? 2 : 0)
                    .padding(-3)
                )
                .help(c.displayName)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(14)
    }
  }
}

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

// MARK: - Appearance: 1 nút, click mở menu (Tự động / Sáng / Tối) — [cũ, không dùng]

struct VKAppearanceButton: View {
  @Default(.appearanceMode) private var mode

  private var icon: String {
    switch mode {
    case .auto:  return "circle.lefthalf.filled"
    case .light: return "sun.max.fill"
    case .dark:  return "moon.fill"
    }
  }

  var body: some View {
    Menu {
      Picker("", selection: $mode) {
        Label("Theo hệ thống", systemImage: "circle.lefthalf.filled").tag(AppearanceMode.auto)
        Label("Sáng", systemImage: "sun.max.fill").tag(AppearanceMode.light)
        Label("Tối", systemImage: "moon.fill").tag(AppearanceMode.dark)
      }
      .pickerStyle(.inline)
      .labelsHidden()
    } label: {
      HStack(spacing: 5) {
        Image(systemName: icon)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(VK.Color.fg1)
        Image(systemName: "chevron.down")
          .font(.system(size: 8, weight: .semibold))
          .foregroundStyle(VK.Color.fgMuted)
      }
      .padding(.horizontal, 8)
      .frame(height: 24)
      .background(
        Capsule().fill(VK.Color.bgElevated)
          .overlay(Capsule().strokeBorder(VK.Color.border1, lineWidth: 1))
      )
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help("Giao diện sáng/tối")
  }
}
