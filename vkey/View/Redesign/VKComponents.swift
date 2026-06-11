//
//  VKComponents.swift
//  vkey — UI primitives cho redesign (Tonal).
//  Port từ ui.jsx + components.css. Pixel-faithful.
//

import SwiftUI

// MARK: - Section (nhãn eyebrow + nội dung)

struct VKSection<Content: View>: View {
  var title: String?
  @ViewBuilder var content: Content

  init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s2) {
      if let title {
        Text(title.uppercased())
          .font(.vk(.eyebrow))
          .tracking(0.6)
          .foregroundStyle(VK.Color.fgMuted)
          .padding(.horizontal, 2)
          .padding(.bottom, 2)
      }
      content
    }
  }
}

// MARK: - RowGroup (thẻ bo, các Row ngăn bằng kẻ)

struct VKRowGroup<Content: View>: View {
  @ViewBuilder var content: Content
  @Environment(\.colorScheme) private var scheme
  init(@ViewBuilder content: () -> Content) { self.content = content() }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: VK.Radius.lg, style: .continuous)
    VStack(spacing: 0) {
      _VariadicDivided { content }
    }
    .background {
      if VK.Glass.isOn {
        shape.fill(VK.Glass.card(dark: scheme == .dark))
          .background(.ultraThinMaterial, in: shape)
      } else if VK.isNeural {
        // ai.css --ai-card: trắng mờ rất nhạt nổi trên aurora
        shape.fill(scheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.86))
      } else {
        shape.fill(VK.Color.bgElevated)
      }
    }
    .clipShape(shape)
    .overlay(
      shape.strokeBorder(VK.Glass.isOn ? VK.Glass.edgeLo : VK.Color.border1, lineWidth: 1)
    )
  }
}

/// Chèn divider giữa các Row con (trừ hàng cuối). Dùng `_VariadicView`.
private struct _VariadicDivided<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    _VariadicView.Tree(_DividedLayout()) { content }
  }
}

private struct _DividedLayout: _VariadicView.MultiViewRoot {
  @ViewBuilder
  func body(children: _VariadicView.Children) -> some View {
    let last = children.last?.id
    ForEach(children) { child in
      child
      if child.id != last {
        Rectangle()
          .fill(VK.Color.border1)
          .frame(height: 1)
      }
    }
  }
}

// MARK: - IconTile (ô icon nền màu, dùng trong Row)

struct VKIconTile: View {
  var systemName: String
  var color: Color = VK.Color.brand
  var size: CGFloat = 32

  var body: some View {
    if VK.Glass.isOn || VK.isNeural {
      // Liquid Glass / Neural: tile tinted — nền màu nhạt + blur + glyph theo
      // màu + viền specular (per design `.icon-tile`).
      let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
      shape.fill(color.opacity(0.20))
        .frame(width: size, height: size)
        .background(.ultraThinMaterial, in: shape)
        .overlay(
          Image(systemName: systemName)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(color))
        .overlay(shape.strokeBorder(color.opacity(0.32), lineWidth: 1))
        .overlay(shape.strokeBorder(Color.white.opacity(0.45), lineWidth: 0.5)
                  .blendMode(.screen))
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
    } else {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(color)
        .frame(width: size, height: size)
        .overlay(
          Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1)
    }
  }
}

// MARK: - Row (hàng cài đặt)

struct VKRow<Control: View>: View {
  var icon: String?
  var iconColor: Color
  var label: String
  var hint: String?
  @ViewBuilder var control: Control

  init(
    icon: String? = nil,
    iconColor: Color = VK.Color.brand,
    label: String,
    hint: String? = nil,
    @ViewBuilder control: () -> Control
  ) {
    self.icon = icon
    self.iconColor = iconColor
    self.label = label
    self.hint = hint
    self.control = control()
  }

  var body: some View {
    HStack(spacing: VK.Space.s3) {
      if let icon {
        VKIconTile(systemName: icon, color: iconColor)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(VK.Font.sans(13.5, .medium))
          .foregroundStyle(VK.Color.fg1)
          .fixedSize(horizontal: false, vertical: true)
        if let hint {
          Text(hint)
            .font(.vk(.small))
            .foregroundStyle(VK.Color.fgMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: VK.Space.s3)
      control
    }
    .padding(.horizontal, VK.Space.s4)
    .padding(.vertical, VK.Density.rowV)
  }
}

/// Row chỉ có toggle (tiện dụng).
struct VKToggleRow: View {
  var icon: String?
  var iconColor: Color = VK.Color.brand
  var label: String
  var hint: String?
  @Binding var isOn: Bool

  var body: some View {
    VKRow(icon: icon, iconColor: iconColor, label: label, hint: hint) {
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(VK.Color.brand)
    }
  }
}

// MARK: - GroupHint (chú thích dưới group)

struct VKGroupHint: View {
  var text: String
  init(_ text: String) { self.text = text }
  var body: some View {
    Text(text)
      .font(.vk(.small))
      .foregroundStyle(VK.Color.fgMuted)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 4)
      .padding(.top, 2)
  }
}

// MARK: - Segmented

struct VKSegmented<T: Hashable>: View {
  @Binding var selection: T
  var options: [(value: T, label: String)]

  var body: some View {
    HStack(spacing: 2) {
      ForEach(options, id: \.value) { opt in
        let active = selection == opt.value
        Button {
          withAnimation(VK.Motion.easeOut) { selection = opt.value }
        } label: {
          Text(opt.label)
            .font(VK.Font.sans(12.5, .medium))
            .foregroundStyle(active ? VK.Color.fg1 : VK.Color.fg2)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
              RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(active ? VK.Color.bgElevated : .clear)
                .overlay(
                  RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(active ? VK.Color.border1 : .clear, lineWidth: 1)
                )
                .shadow(color: active ? .black.opacity(0.08) : .clear, radius: 1, y: 1)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(2)
    .background(
      RoundedRectangle(cornerRadius: VK.Radius.md, style: .continuous)
        .fill(VK.Color.bgSunken)
        .overlay(
          RoundedRectangle(cornerRadius: VK.Radius.md, style: .continuous)
            .strokeBorder(VK.Color.border1, lineWidth: 1)
        )
    )
  }
}

// MARK: - Keycap

struct VKKeycap: View {
  var text: String
  var large: Bool = false
  init(_ text: String, large: Bool = false) { self.text = text; self.large = large }

  var body: some View {
    Text(text)
      .font(.system(size: large ? 14 : 12, weight: .semibold))
      .foregroundStyle(VK.Color.fg1)
      .frame(minWidth: large ? 36 : 24, minHeight: large ? 36 : 24)
      .padding(.horizontal, large ? 10 : 6)
      .background(
        RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous)
          .fill(VK.Color.bgElevated)
          .overlay(
            RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous)
              .strokeBorder(VK.Color.border2, lineWidth: 1)
          )
      )
  }
}

// MARK: - Badge

struct VKBadge: View {
  enum Variant { case neutral, success, warning, danger, info, gold }
  var text: String
  var variant: Variant = .neutral

  private var fg: Color {
    switch variant {
    case .neutral: return VK.Color.fg2
    case .success: return VK.Color.success
    case .warning: return VK.Color.warning
    case .danger:  return VK.Color.danger
    case .info:    return VK.Color.info
    case .gold:    return VK.Color.gold
    }
  }
  private var bg: Color {
    switch variant {
    case .neutral: return VK.Color.bgSunken
    case .success: return VK.Color.successSoft
    case .warning: return VK.Color.warningSoft
    case .danger:  return VK.Color.dangerSoft
    case .info:    return VK.Color.infoSoft
    case .gold:    return VK.Color.warningSoft
    }
  }

  var body: some View {
    Text(text)
      .font(VK.Font.sans(11, .semibold))
      .foregroundStyle(fg)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Capsule().fill(bg))
  }
}

// MARK: - Button

struct VKButton: View {
  enum Variant { case primary, secondary, ghost, danger }
  enum Size { case sm, md }
  var title: String
  var icon: String?
  var variant: Variant = .secondary
  var size: Size = .md
  var fullWidth: Bool = false
  var disabled: Bool = false
  var action: () -> Void

  private var fg: Color {
    switch variant {
    case .primary: return .white
    case .secondary, .ghost: return VK.Color.fg1
    case .danger:  return VK.Color.danger
    }
  }
  private var bg: Color {
    switch variant {
    case .primary: return VK.Color.brand
    case .secondary: return VK.Color.bgElevated
    case .ghost: return .clear
    case .danger: return VK.Color.dangerSoft
    }
  }
  private var border: Color {
    switch variant {
    case .primary, .ghost: return .clear
    case .secondary: return VK.Color.border1
    case .danger: return VK.Color.danger.opacity(0.3)
    }
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let icon {
          Image(systemName: icon).font(.system(size: size == .sm ? 12 : 14, weight: .semibold))
        }
        Text(title).font(VK.Font.sans(13.5, .medium))
      }
      .foregroundStyle(fg)
      .frame(maxWidth: fullWidth ? .infinity : nil)
      .frame(height: size == .sm ? 30 : 36)
      .padding(.horizontal, 14)
      .background(
        RoundedRectangle(cornerRadius: VK.Radius.md, style: .continuous)
          .fill(variant == .primary ? AnyShapeStyle(VK.Color.brandGradient) : AnyShapeStyle(bg))
          .overlay(
            RoundedRectangle(cornerRadius: VK.Radius.md, style: .continuous)
              .strokeBorder(border, lineWidth: 1)
          )
      )
      // Halo gradient cho nút primary ở Neural (ai.css 0.7*k)
      .shadow(color: (variant == .primary && VK.isNeural)
                ? VK.Color.glow.opacity(0.5 * VK.glowK) : .clear,
              radius: 9, x: 0, y: 4)
      .opacity(disabled ? 0.45 : 1)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
  }
}
