//
//  VKSidebar.swift
//  vkey — Thanh điều hướng bên trái (232pt) của cửa sổ Cài đặt.
//

import SwiftUI

struct VKSidebar: View {
  @EnvironmentObject var appState: AppState
  @Binding var selectedRaw: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hoverTab: VKTab?

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s3) {
      identityCard

      Text("CÀI ĐẶT")
        .font(.vk(.eyebrow))
        .tracking(0.8)
        .foregroundStyle(VK.Color.fgMuted)
        .padding(.horizontal, 4)
        .padding(.top, 4)

      VStack(spacing: 2) {
        ForEach(VKTab.allCases) { tab in
          navItem(tab)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .frame(maxHeight: .infinity)
    .background {
      Group {
        if VK.Glass.isOn || VK.isNeural {
          Color.white.opacity(0.03)
        } else {
          VK.Color.bgSunken
        }
      }
      .ignoresSafeArea(.container, edges: .top)
    }
  }

  private var identityCard: some View {
    HStack(spacing: 11) {
      Group {
        if let icon = NSApp.applicationIconImage {
          Image(nsImage: icon).resizable()
        } else {
          RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VK.Color.brand)
        }
      }
      .frame(width: 44, height: 44)
      .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
      )
      .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1.5)

      VStack(alignment: .leading, spacing: 4) {
        Text("vkey")
          .font(VK.Font.sans(15, .bold))
          .foregroundStyle(
            VK.isNeural
              ? AnyShapeStyle(VK.Color.brandGradient)
              : AnyShapeStyle(VK.Color.fg1))
        HStack(spacing: 5) {
          Circle()
            .fill(appState.enabled ? VK.Color.success : VK.Color.fgMuted)
            .frame(width: 7, height: 7)
            .shadow(color: appState.enabled ? VK.Color.success.opacity(0.7) : .clear, radius: 3)
          Text(appState.enabled ? "Đang gõ tiếng Việt" : "Đang tắt")
            .font(VK.Font.sans(11.5, .medium))
            .foregroundStyle(appState.enabled ? VK.Color.success : VK.Color.fgMuted)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(11)
    .background(VKCardBackground(radius: VK.Radius.md))
  }

  private func navItem(_ tab: VKTab) -> some View {
    let active = selectedRaw == tab.rawValue
    let isHover = hoverTab == tab && !active
    return Button {
      selectedRaw = tab.rawValue
    } label: {
      HStack(spacing: 9) {
        navTile(tab, active: active)
        Text(tab.title)
          .font(VK.Font.sans(13.5, .medium))
          .foregroundStyle(active ? .white : VK.Color.fg1)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(
        RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
          .fill(
            active
              ? AnyShapeStyle(VK.Color.brandGradient)
              : AnyShapeStyle(isHover ? VK.Color.bgHover : Color.clear))
      )
      .shadow(
        color: (active && VK.isNeural) ? VK.Color.glow.opacity(0.55 * VK.glowK) : .clear,
        radius: 11, x: 0, y: 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .vkFocusRing(radius: VK.Radius.sm, onBrand: active)
    .onHover { hoverTab = $0 ? tab : (hoverTab == tab ? nil : hoverTab) }
    .animation(reduceMotion ? nil : VK.Motion.easeOut, value: hoverTab)
  }

  @ViewBuilder
  private func navTile(_ tab: VKTab, active: Bool) -> some View {
    let accent = VK.Color.tileAccent(tab.tileColor)
    if (VK.Glass.isOn || VK.isNeural) && !active {
      Circle()
        .fill(accent.opacity(0.22))
        .frame(width: 26, height: 26)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(
          Image(systemName: tab.icon)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(accent))
        .overlay(Circle().strokeBorder(accent.opacity(0.30), lineWidth: 1))
    } else {
      RoundedRectangle(cornerRadius: VK.Glass.isOn ? 13 : 7, style: .continuous)
        .fill(active ? Color.white.opacity(0.22) : accent)
        .frame(width: 26, height: 26)
        .overlay(
          Image(systemName: tab.icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white))
    }
  }
}
