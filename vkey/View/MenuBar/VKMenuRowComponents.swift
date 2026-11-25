//
//  VKMenuRowComponents.swift
//  vkey
//
//  Các thành phần con của Menu Bar panel: hàng menu, header trạng thái VI/EN,
//  separator, checkmark, shortcut badge và nút icon footer.
//

import SwiftUI

struct VKMenuPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
  }
}

struct VKMenuRow<Trailing: View>: View {
  let icon: String
  let title: String
  var iconTint: Color? = nil
  var action: () -> Void
  @ViewBuilder var trailing: () -> Trailing

  @State private var hover = false

  init(
    _ icon: String,
    _ title: String,
    iconTint: Color? = nil,
    action: @escaping () -> Void,
    @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
  ) {
    self.icon = icon
    self.title = title
    self.iconTint = iconTint
    self.action = action
    self.trailing = trailing
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .medium))
          .symbolRenderingMode(.hierarchical)
          .frame(width: 18, height: 18)
          .foregroundStyle(hover ? Color.white : (iconTint ?? Color.white.opacity(0.85)))
        Text(title)
          .font(VK.Font.sans(13))
          .foregroundStyle(Color.white.opacity(hover ? 1 : 0.95))
        Spacer(minLength: 8)
        trailing()
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: VK.Radius.scaled(7), style: .continuous)
          .fill(hover ? AnyShapeStyle(VK.Color.brandGradient) : AnyShapeStyle(Color.clear))
      )
      .contentShape(RoundedRectangle(cornerRadius: VK.Radius.scaled(7), style: .continuous))
    }
    .buttonStyle(VKMenuPressStyle())
    .onHover { h in
      withAnimation(.easeOut(duration: 0.12)) { hover = h }
    }
  }
}

struct VKMenuSep: View {
  var body: some View {
    Rectangle()
      .fill(Color.white.opacity(0.08))
      .frame(height: 1)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
  }
}

struct VKMenuCheck: View {
  var on: Bool
  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Color.white.opacity(0.92))
      .frame(width: 14)
      .scaleEffect(on ? 1 : 0.5)
      .opacity(on ? 1 : 0)
      .animation(.spring(response: 0.25, dampingFraction: 0.6), value: on)
  }
}

struct VKShortcutBadge: View {
  let label: String
  init(_ label: String) { self.label = label }

  var body: some View {
    Text(label)
      .font(.system(size: 11, weight: .medium, design: .monospaced))
      .foregroundStyle(Color.white.opacity(0.6))
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(Color.white.opacity(0.07))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
      )
  }
}

struct VKStatusHeaderRow: View {
  let isVietnamese: Bool
  let subtitle: String
  let action: () -> Void
  @State private var hover = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(isVietnamese ? "vn-flag" : "us-flag")
          .resizable().interpolation(.high)
          .frame(width: 26, height: 18)
          .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
          .shadow(color: .black.opacity(0.3), radius: 3, y: 1)

        VStack(alignment: .leading, spacing: 1) {
          Text(isVietnamese ? "Tiếng Việt" : "English")
            .font(VK.Font.sans(13, .semibold))
            .foregroundStyle(.white)
          Text(subtitle)
            .font(VK.Font.sans(11))
            .foregroundStyle(Color.white.opacity(0.55))
        }

        Spacer(minLength: 8)

        HStack(spacing: 0) {
          segment("VI", active: isVietnamese)
          segment("EN", active: !isVietnamese)
        }
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: VK.Radius.scaled(8), style: .continuous)
          .fill(Color.white.opacity(hover ? 0.08 : 0.04))
      )
      .contentShape(RoundedRectangle(cornerRadius: VK.Radius.scaled(8), style: .continuous))
    }
    .buttonStyle(VKMenuPressStyle())
    .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
  }

  private func segment(_ label: String, active: Bool) -> some View {
    Text(label)
      .font(VK.Font.sans(10.5, .bold))
      .foregroundStyle(active ? Color.white : Color.white.opacity(0.45))
      .padding(.horizontal, 8)
      .padding(.vertical, 3.5)
      .background(
        Capsule().fill(active ? AnyShapeStyle(VK.Color.brandGradient) : AnyShapeStyle(Color.clear))
      )
      .animation(.spring(response: 0.3, dampingFraction: 0.75), value: active)
  }
}

struct VKFooterIconButton: View {
  let icon: String
  let help: String
  let action: () -> Void
  @State private var hover = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 13, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(Color.white.opacity(hover ? 1 : 0.65))
        .frame(width: 30, height: 26)
        .background(
          RoundedRectangle(cornerRadius: VK.Radius.scaled(6), style: .continuous)
            .fill(Color.white.opacity(hover ? 0.10 : 0))
        )
        .contentShape(RoundedRectangle(cornerRadius: VK.Radius.scaled(6), style: .continuous))
    }
    .buttonStyle(VKMenuPressStyle())
    .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
    .help(help)
  }
}
