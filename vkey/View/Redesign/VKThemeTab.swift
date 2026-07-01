//
//  VKThemeTab.swift
//  vkey — Tab "Quản lý giao diện" (2.16): chọn theme (Mặc định / Liquid Glass)
//  + tuỳ chỉnh font, độ bo góc, mật độ dòng, và độ trong suốt (Liquid Glass).
//

import Defaults
import SwiftUI

struct VKThemeTab: View {
  @Default(.uiTheme) private var theme
  @Default(.themeConfigs) private var configs
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hoverAccent: AccentColorChoice?
  @State private var hoverTheme: UITheme?

  /// Cấu hình của theme đang chọn.
  private var cfg: ThemeConfig { configs[theme.rawValue] ?? .defaultFor(theme) }

  /// Binding ghi vào config của theme hiện tại (lưu per-theme).
  private func bind<V>(_ kp: WritableKeyPath<ThemeConfig, V>) -> Binding<V> {
    Binding(
      get: { (configs[theme.rawValue] ?? .defaultFor(theme))[keyPath: kp] },
      set: { newVal in
        var c = configs[theme.rawValue] ?? .defaultFor(theme)
        c[keyPath: kp] = newVal
        configs[theme.rawValue] = c
      }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {

      // Chọn giao diện
      VKSection("Giao diện") {
        HStack(spacing: VK.Space.s3) {
          ForEach(UITheme.allCases, id: \.self) { t in
            themeCard(t)
          }
        }
        VKGroupHint("Đổi giao diện áp dụng ngay, không cần khởi động lại.")
      }

      // Tuỳ chỉnh chung
      VKSection("Tuỳ chỉnh") {
        VKRowGroup {
          VKRow(icon: "paintpalette.fill", iconColor: VK.Color.brand, label: "Màu nhấn") {
            HStack(spacing: 9) {
              ForEach(AccentColorChoice.allCases, id: \.self) { c in
                Button {
                  bind(\.accent).wrappedValue = c
                } label: {
                  Circle()
                    .fill(VK.Color.accentSwatch(c))
                    .frame(width: 20, height: 20)
                    .overlay(Image(systemName: "checkmark")
                              .font(.system(size: 10, weight: .bold))
                              .foregroundStyle(.white)
                              .opacity(cfg.accent == c ? 1 : 0))
                    .overlay(Circle().strokeBorder(VK.Color.fg2,
                                                   lineWidth: cfg.accent == c ? 2 : 0).padding(-3))
                    .scaleEffect(hoverAccent == c ? 1.12 : 1)   // v4.8 hover
                }
                .buttonStyle(.plain)
                .vkFocusRing(radius: 12)                        // v4.8 focus (radio)
                .onHover { hoverAccent = $0 ? c : (hoverAccent == c ? nil : hoverAccent) }
                .animation(reduceMotion ? nil : VK.Motion.easeOut, value: hoverAccent)
                .help(c.displayName)
              }
            }
          }
          VKRow(icon: "textformat", iconColor: VK.Color.brand, label: "Phông chữ") {
            // Menu + Button thường (Picker lồng Menu không bắn selection —
            // đây là lý do trước đây chọn font không có tác dụng).
            Menu {
              ForEach(ThemeFont.allCases, id: \.self) { f in
                Button {
                  bind(\.font).wrappedValue = f
                } label: {
                  HStack {
                    Text(f.displayName)
                      .font(f.postScriptName.map { .custom($0, size: 13) }
                            ?? .system(size: 13))
                    if f == cfg.font { Image(systemName: "checkmark") }
                  }
                }
              }
            } label: {
              HStack(spacing: 5) {
                Text(cfg.font.displayName).font(.vk(.small)).foregroundStyle(VK.Color.fg1)
                Image(systemName: "chevron.up.chevron.down")
                  .font(.system(size: 9)).foregroundStyle(VK.Color.fgMuted)
              }
              .padding(.horizontal, 10).frame(height: 26)
              .background(Capsule().fill(VK.Color.bgSunken))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
          }
          VKRow(icon: "square.on.square.dashed", iconColor: VK.Color.info, label: "Độ bo góc") {
            VKSegmented(selection: bind(\.radius),
                        options: ThemeRadius.allCases.map { ($0, $0.displayName) })
          }
          VKRow(icon: "rectangle.compress.vertical", iconColor: VK.Color.gold,
                label: "Mật độ dòng menu") {
            VKSegmented(selection: bind(\.density),
                        options: ThemeDensity.allCases.map { ($0, $0.displayName) })
          }
        }
      }

      // Liquid Glass: độ trong suốt · Neural AI: cường độ phát sáng (cùng slot clarity)
      if theme == .glass || theme == .neural {
        VKSection(theme == .glass ? "Liquid Glass" : "Neural AI") {
          VKRowGroup {
            VKRow(icon: theme == .glass ? "drop.halffull" : "sparkles",
                  iconColor: VK.Color.brand,
                  label: theme == .glass ? "Độ trong suốt" : "Cường độ phát sáng",
                  hint: theme == .glass
                    ? "Kéo cao = kính trong hơn, thấy nền sau rõ hơn."
                    : "Kéo cao = aurora và halo gradient rực hơn.") {
              HStack(spacing: 8) {
                Slider(value: bind(\.clarity), in: 0...1)
                  .frame(width: 150)
                  .tint(VK.Color.brand)
                Text("\(Int(cfg.clarity * 100))%")
                  .font(.system(size: 12, weight: .medium, design: .monospaced))
                  .foregroundStyle(VK.Color.fg2)
                  .frame(width: 40, alignment: .trailing)
              }
            }
          }
          VKGroupHint(theme == .glass
            ? "Liquid Glass dùng nền trong mờ + blur khúc xạ. Trên macOS Tahoe sẽ trong và mượt nhất."
            : "Neural AI: aurora tím–cyan trôi trên nền obsidian, gradient trí tuệ tô tiêu đề / nav / nút.")
        }
      }
    }
  }

  // MARK: - Theme card

  private func themeCard(_ t: UITheme) -> some View {
    let active = theme == t
    return Button {
      withAnimation(reduceMotion ? nil : VK.Motion.easeOut) { theme = t }
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        // preview swatch
        ZStack {
          switch t {
          case .glass:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(VK.Color.brand.opacity(0.18))
              .frame(width: 34, height: 12)
          case .neural:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(Color(vkHex: "#0B0B14"))
            Circle().fill(Color(vkHex: "#8B5CF6").opacity(0.5))
              .frame(width: 34).blur(radius: 10).offset(x: -16, y: -6)
            Circle().fill(Color(vkHex: "#22D3EE").opacity(0.4))
              .frame(width: 28).blur(radius: 10).offset(x: 18, y: 8)
            Capsule()
              .fill(LinearGradient(colors: [Color(vkHex: "#8B5CF6"), Color(vkHex: "#EC4899"), Color(vkHex: "#22D3EE")],
                                   startPoint: .leading, endPoint: .trailing))
              .frame(width: 34, height: 12)
          case .tonal:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(VK.Color.bgSunken)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(VK.Color.brand.opacity(0.9))
              .frame(width: 34, height: 12)
          }
        }
        .frame(height: 48)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))

        HStack(spacing: 6) {
          Text(t.displayName).font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(VK.Color.fg1)
          Spacer()
          Image(systemName: active ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 14))
            .foregroundStyle(active ? VK.Color.brand : VK.Color.fgMuted)
        }
        Text(t.caption).font(.vk(.small)).foregroundStyle(VK.Color.fgMuted)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: VK.Radius.lg, style: .continuous)
          .fill(VK.Color.bgElevated)
          .overlay(RoundedRectangle(cornerRadius: VK.Radius.lg, style: .continuous)
                    .strokeBorder(active ? VK.Color.brand : VK.Color.border1,
                                  lineWidth: active ? 2 : 1))
      )
      .offset(y: hoverTheme == t && !active ? -1 : 0)   // v4.8 hover lift
    }
    .buttonStyle(.plain)
    .vkFocusRing(radius: VK.Radius.lg)                   // v4.8 focus
    .onHover { hoverTheme = $0 ? t : (hoverTheme == t ? nil : hoverTheme) }
    .animation(reduceMotion ? nil : VK.Motion.easeOut, value: hoverTheme)
  }
}
