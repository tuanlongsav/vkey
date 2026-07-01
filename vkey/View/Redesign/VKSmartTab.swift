//
//  VKSmartTab.swift
//  vkey — Tab "Smart Switch" redesign (đầy đủ chức năng 2.15).
//

import Defaults
import SwiftUI

struct VKSmartTab: View {
  @Default(.smartSwitchEnabled) private var smartSwitch
  @Default(.appSmartSwitchConfigs) private var configs
  @State private var newBundleId = ""
  @State private var showingRunningApps = false
  @State private var showingAutoLearn = false

  private var sortedConfigs: [(key: String, value: AppSmartSwitchConfig)] {
    configs.sorted { $0.key < $1.key }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {

      // Master toggle
      VKSection {
        VKRowGroup {
          VKToggleRow(icon: "shuffle", iconColor: VK.Color.brand,
                      label: "Smart Switch",
                      hint: "Tự động chọn chế độ gõ phù hợp cho từng ứng dụng (Tiếng Việt / Tiếng Anh / Tắt).",
                      isOn: $smartSwitch)
        }
      }

      if smartSwitch {
        // Auto-learn button
        VKSection {
          HStack {
            Text("DANH SÁCH ỨNG DỤNG")
              .font(.vk(.eyebrow)).tracking(0.6).foregroundStyle(VK.Color.fgMuted)
            Spacer()
            VKButton(title: "Tự học từ Thống kê", icon: "wand.and.stars",
                     variant: .secondary, size: .sm) {
              showingAutoLearn = true
            }
          }
          .padding(.bottom, 2)

          VKRowGroup {
            if sortedConfigs.isEmpty {
              VKEmptyState(
                systemImage: "shuffle",
                title: "Chưa có app nào được cấu hình",
                message: "Đặt chế độ gõ riêng cho từng ứng dụng để vkey tự chuyển khi bạn đổi app.",
                actionTitle: "Chọn từ ứng dụng đang chạy",
                action: { showingRunningApps = true })
            } else {
              ForEach(sortedConfigs, id: \.key) { entry in
                appRow(bundleId: entry.key, config: entry.value)
              }
            }
          }
        }

        // Thêm app
        VKSection {
          HStack(spacing: VK.Space.s2) {
            TextField("com.example.app", text: $newBundleId)
              .textFieldStyle(.plain)
              .font(.system(size: 12.5, design: .monospaced))
              .padding(.horizontal, 10).frame(height: 30)
              .background(
                RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
                  .fill(VK.Color.bgElevated)
                  .overlay(RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
                            .strokeBorder(VK.Color.border1, lineWidth: 1)))
            VKButton(title: "Thêm", icon: "plus", variant: .primary, size: .sm) {
              addApp()
            }
          }
          VKButton(title: "Chọn từ ứng dụng đang chạy", icon: "square.stack.3d.up",
                   variant: .secondary, fullWidth: true) {
            showingRunningApps = true
          }
          VKGroupHint("Lấy Bundle ID bằng Terminal: osascript -e 'id of app \"Tên App\"'")
        }

        // Quy tắc theo cửa sổ (nâng cao) — override theo bundle ID + title regex.
        VKSection {
          WindowRulesSection()
            .padding(.horizontal, -12) // bù padding nội bộ của section cũ
            .background(
              RoundedRectangle(cornerRadius: VK.Radius.lg, style: .continuous)
                .fill(VK.Color.bgElevated)
                .overlay(RoundedRectangle(cornerRadius: VK.Radius.lg, style: .continuous)
                          .strokeBorder(VK.Color.border1, lineWidth: 1)))
        }
      }
    }
    .sheet(isPresented: $showingRunningApps) {
      SmartSwitchRunningAppsSheet()
    }
    .sheet(isPresented: $showingAutoLearn) {
      SmartSwitchAutoLearnSheet()
    }
  }

  @ViewBuilder
  private func appRow(bundleId: String, config: AppSmartSwitchConfig) -> some View {
    let app = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }
    let name = app?.localizedName ?? bundleId.components(separatedBy: ".").last ?? bundleId
    HStack(spacing: VK.Space.s3) {
      // icon
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(modeColor(config.state))
        .frame(width: 34, height: 34)
        .overlay(Text(String(name.prefix(1)).uppercased())
                  .font(.system(size: 15, weight: .bold)).foregroundStyle(.white))
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(VK.Color.fg1)
        Text(bundleId).font(.system(size: 12, design: .monospaced)).foregroundStyle(VK.Color.fgMuted)
          .lineLimit(1).truncationMode(.middle)
      }
      Spacer(minLength: VK.Space.s2)
      // mode chip
      Menu {
        Button("🇻🇳 Tiếng Việt") { setState(bundleId, .vietnameseMode) }
        Button("🇺🇸 Tiếng Anh") { setState(bundleId, .englishMode) }
        Button("Không sử dụng vkey") { setState(bundleId, .disabled) }
        Divider()
        Button("Để vkey tự quyết (xoá)") { configs.removeValue(forKey: bundleId) }
      } label: {
        Text(config.state.shortLabel)
          .font(.system(size: 12, weight: .medium))
          .padding(.horizontal, 8).frame(height: 24)
          .background(Capsule().fill(VK.Color.bgSunken))
      }
      .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
      Button { configs.removeValue(forKey: bundleId) } label: {
        Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(VK.Color.danger)
      }.buttonStyle(.plain)
    }
    .padding(.horizontal, VK.Space.s4).padding(.vertical, 10)
  }

  private func modeColor(_ s: AppSmartSwitchState) -> Color {
    switch s {
    case .vietnameseMode: return VK.Color.brand
    case .englishMode: return VK.Color.info
    case .disabled: return VK.Color.ink200
    }
  }

  private func setState(_ bundleId: String, _ state: AppSmartSwitchState) {
    configs[bundleId] = AppSmartSwitchConfig(state: state, source: .user, lastModified: Date())
  }

  private func addApp() {
    let id = newBundleId.trimmingCharacters(in: .whitespaces)
    guard !id.isEmpty else { return }
    configs[id] = AppSmartSwitchConfig(state: .englishMode, source: .user, lastModified: Date())
    newBundleId = ""
  }
}
