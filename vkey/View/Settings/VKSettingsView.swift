//
//  VKSettingsView.swift
//  vkey — Cửa sổ Cài đặt (2 cột tự dựng: sidebar 232pt + detail pane).
//

import Defaults
import SwiftUI

enum VKTab: String, CaseIterable, Identifiable {
  case general, smart, macro, spell, stats, theme
  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: return "Chung"
    case .smart:   return "Smart Switch"
    case .macro:   return "Macro"
    case .spell:   return "Chính tả"
    case .stats:   return "Thống kê & Sao lưu"
    case .theme:   return "Quản lý giao diện"
    }
  }

  var icon: String {
    switch self {
    case .general: return "gearshape.fill"
    case .smart:   return "shuffle"
    case .macro:   return "square.and.pencil"
    case .spell:   return "checkmark.seal.fill"
    case .stats:   return "chart.bar.fill"
    case .theme:   return "paintbrush.fill"
    }
  }

  var tileColor: Color {
    switch self {
    case .general: return VK.Color.brand
    case .smart:   return VK.Color.info
    case .macro:   return VK.Color.gold
    case .spell:   return VK.Color.success
    case .stats:   return VK.Color.gold
    case .theme:   return VK.Color.danger
    }
  }
}

struct VKSettingsView: View {
  @EnvironmentObject var appState: AppState
  @AppStorage("vk-settings-tab") private var storedTabRaw: String = VKTab.general.rawValue
  @State private var overrideTabRaw: String?
  @Default(.appearanceMode) private var appearanceMode
  @Default(.uiTheme) private var uiTheme
  @Default(.themeConfigs) private var themeConfigs

  /// Cho phép inject tab ban đầu mà không ghi đè `UserDefaults` (dùng cho Marketing export).
  init(initialTab: VKTab? = nil) {
    _overrideTabRaw = State(initialValue: initialTab?.rawValue)
  }

  private var selectedBinding: Binding<String> {
    Binding(
      get: { overrideTabRaw ?? storedTabRaw },
      set: { newValue in
        if overrideTabRaw != nil {
          overrideTabRaw = newValue
        } else {
          storedTabRaw = newValue
        }
      }
    )
  }

  private var selected: VKTab { VKTab(rawValue: selectedBinding.wrappedValue) ?? .general }

  private var themeToken: String {
    let c = themeConfigs[uiTheme.rawValue] ?? .defaultFor(uiTheme)
    return "\(uiTheme.rawValue)-\(c.accent.rawValue)-\(c.radius.rawValue)-\(c.density.rawValue)-\(c.font.rawValue)"
  }

  var body: some View {
    HStack(spacing: 0) {
      VKSidebar(selectedRaw: selectedBinding)
        .frame(width: 232)
        .id("side-\(themeToken)")

      Rectangle()
        .fill(VK.Color.border1)
        .frame(width: 1)
        .ignoresSafeArea(.container, edges: .top)

      VStack(spacing: 0) {
        ZStack {
          Text(selected.title)
            .font(VK.Font.sans(16, .bold))
            .foregroundStyle(
              VK.isNeural
                ? AnyShapeStyle(VK.Color.brandGradient)
                : AnyShapeStyle(VK.Color.fg1))
            .frame(maxWidth: .infinity, alignment: .center)
          HStack {
            Spacer()
            VKAppearanceSegment()
          }
        }
        .padding(.horizontal, VK.Space.s4)
        .frame(height: 38)
        .overlay(alignment: .bottom) {
          Rectangle().fill(VK.Color.border1).frame(height: 1)
        }

        ScrollView {
          Group {
            switch selected {
            case .general: VKGeneralTab()
            case .smart:   VKSmartTab()
            case .macro:   VKMacroTab()
            case .spell:   VKSpellTab()
            case .stats:   VKStatsTab()
            case .theme:   VKThemeTab()
            }
          }
          .frame(maxWidth: 620)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, VK.Space.s6)
          .padding(.vertical, 20)
        }
      }
      .id("detail-\(themeToken)")
      .background(detailBackground)
    }
    .frame(minWidth: 820, minHeight: 600)
    .background(rootBackground)
    .background(VKWindowConfigurator(theme: uiTheme))
    .tint(VK.Color.brand)
    .onAppear { applyAppearance(appearanceMode) }
    .onChange(of: appearanceMode) { _, newValue in applyAppearance(newValue) }
  }

  @ViewBuilder private var detailBackground: some View {
    if uiTheme == .tonal {
      VK.Color.bg.ignoresSafeArea(.container, edges: .top)
    } else {
      Color.clear
    }
  }

  @ViewBuilder private var rootBackground: some View {
    switch uiTheme {
    case .glass:  VKGlassBackdrop().ignoresSafeArea()
    case .neural: VKNeuralBackdrop().ignoresSafeArea()
    case .tonal:  VK.Color.bg.ignoresSafeArea()
    }
  }

  private func applyAppearance(_ mode: AppearanceMode) {
    let appearance: NSAppearance?
    switch mode {
    case .auto:  appearance = nil
    case .light: appearance = NSAppearance(named: .aqua)
    case .dark:  appearance = NSAppearance(named: .darkAqua)
    }
    NSApp.appearance = appearance
  }
}
