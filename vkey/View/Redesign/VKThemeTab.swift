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
                }
                .buttonStyle(.plain)
                .help(c.displayName)
              }
            }
          }
          VKRow(icon: "textformat", iconColor: VK.Color.brand, label: "Phông chữ") {
            Menu {
              Picker("", selection: bind(\.font)) {
                ForEach(ThemeFont.allCases, id: \.self) { f in
                  Text(f.displayName).tag(f)
                }
              }.labelsHidden()
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

      // Liquid Glass — độ trong suốt
      if theme == .glass {
        VKSection("Liquid Glass") {
          VKRowGroup {
            VKRow(icon: "drop.halffull", iconColor: VK.Color.brand,
                  label: "Độ trong suốt",
                  hint: "Kéo cao = kính trong hơn, thấy nền sau rõ hơn.") {
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
          VKGroupHint("Liquid Glass dùng nền trong mờ + blur khúc xạ. Trên macOS Tahoe sẽ trong và mượt nhất.")
        }
      }
    }
  }

  // MARK: - Theme card

  private func themeCard(_ t: UITheme) -> some View {
    let active = theme == t
    return Button {
      withAnimation(VK.Motion.easeOut) { theme = t }
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        // preview swatch
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(t == .glass
                  ? AnyShapeStyle(.ultraThinMaterial)
                  : AnyShapeStyle(VK.Color.bgSunken))
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(t == .glass ? VK.Color.brand.opacity(0.18) : VK.Color.brand.opacity(0.9))
            .frame(width: 34, height: 12)
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
    }
    .buttonStyle(.plain)
  }
}
