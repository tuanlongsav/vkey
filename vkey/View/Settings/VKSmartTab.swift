//
//  VKSmartTab.swift
//  vkey — Tab "Smart Switch" & cách gửi phím theo ứng dụng.
//

import Defaults
import SwiftUI

struct VKSmartTab: View {
  @Default(.smartSwitchEnabled) private var smartSwitch
  @Default(.appSmartSwitchConfigs) private var configs
  @Default(.appSendingModes) private var sendingModes
  @State private var newBundleId = ""
  @State private var showingRunningApps = false
  @State private var showingAutoLearn = false

  private var sortedConfigs: [(key: String, value: AppSmartSwitchConfig)] {
    configs.sorted { $0.key < $1.key }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {
      VKSection {
        VKRowGroup {
          VKToggleRow(
            icon: "shuffle", iconColor: VK.Color.brand,
            label: "Smart Switch",
            hint: "Tự động chọn chế độ gõ phù hợp cho từng ứng dụng (Tiếng Việt / Tiếng Anh / Tắt).",
            isOn: $smartSwitch)
        }
      }

      if smartSwitch {
        VKSection {
          HStack {
            Text("DANH SÁCH ỨNG DỤNG")
              .font(.vk(.eyebrow)).tracking(0.6).foregroundStyle(VK.Color.fgMuted)
            Spacer()
            VKButton(
              title: "Tự học từ Thống kê", icon: "wand.and.stars",
              variant: .secondary, size: .sm
            ) {
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

        VKSection {
          HStack(spacing: VK.Space.s2) {
            TextField("com.example.app", text: $newBundleId)
              .textFieldStyle(.plain)
              .font(.system(size: 12.5, design: .monospaced))
              .padding(.horizontal, 10).frame(height: 30)
              .background(
                RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
                  .fill(VK.Color.bgElevated)
                  .overlay(
                    RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
                      .strokeBorder(VK.Color.border1, lineWidth: 1)))
            VKButton(title: "Thêm", icon: "plus", variant: .primary, size: .sm, action: addApp)
          }
          VKButton(
            title: "Chọn từ ứng dụng đang chạy", icon: "square.stack.3d.up",
            variant: .secondary, fullWidth: true
          ) {
            showingRunningApps = true
          }
          VKGroupHint("Lấy Bundle ID bằng Terminal: osascript -e 'id of app \"Tên App\"'")
        }
      }

      sendingModeSection

      VKGroupHint("Trong app điều khiển máy từ xa (Screen Sharing, iPhone Mirroring, AnyDesk, RustDesk, TeamViewer, Windows App…) vkey tự đứng ngoài để bộ gõ ở máy kia làm việc. Muốn vkey gõ ở đó, thêm app vào danh sách ứng dụng và chọn Tiếng Việt.")
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
    let name = RunningAppsLookup.displayName(for: bundleId)
    HStack(spacing: VK.Space.s3) {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(modeColor(config.state))
        .frame(width: 34, height: 34)
        .overlay(
          Text(String(name.prefix(1)).uppercased())
            .font(VK.Font.sans(15, .bold)).foregroundStyle(.white))
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(VK.Font.sans(13.5, .semibold)).foregroundStyle(VK.Color.fg1)
        Text(bundleId).font(.system(size: 12, design: .monospaced)).foregroundStyle(VK.Color.fgMuted)
          .lineLimit(1).truncationMode(.middle)
      }
      Spacer(minLength: VK.Space.s2)
      if config.source == .autoLearn {
        Text(config.source.displayName)
          .font(VK.Font.sans(10.5, .medium))
          .foregroundStyle(VK.Color.fgMuted)
          .padding(.horizontal, 6).frame(height: 20)
          .background(Capsule().strokeBorder(VK.Color.border1, lineWidth: 1))
          .help("vkey tự ghi cấu hình này từ thống kê gõ. Chọn lại chế độ để đặt theo ý bạn.")
      }
      Menu {
        Button("🇻🇳 Tiếng Việt") { setState(bundleId, .vietnameseMode) }
        Button("🇺🇸 Tiếng Anh") { setState(bundleId, .englishMode) }
        Button("Không sử dụng vkey") { setState(bundleId, .disabled) }
        Divider()
        Button("Để vkey tự quyết (xoá)") { configs.removeValue(forKey: bundleId) }
      } label: {
        Text(config.state.shortLabel)
          .font(VK.Font.sans(12, .medium))
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

  // MARK: Cách gửi phím theo ứng dụng

  private var addableSendingApps: [RunningAppInfo] {
    RunningAppsLookup.regularRunningApps().filter { sendingModes[$0.bundleId] == nil }
  }

  @ViewBuilder
  private var sendingModeSection: some View {
    VKSection("Cách gửi phím theo ứng dụng") {
      VKRowGroup {
        if sendingModes.isEmpty {
          HStack {
            Text("Mọi app đang dùng cách gửi tự động.")
              .font(.vk(.small)).foregroundStyle(VK.Color.fgMuted)
            Spacer()
          }
          .padding(.horizontal, VK.Space.s4).padding(.vertical, 12)
        } else {
          ForEach(sendingModes.keys.sorted(), id: \.self) { bundleId in
            sendingModeRow(bundleId: bundleId, mode: sendingModes[bundleId] ?? .paced)
          }
        }
      }
      Menu {
        ForEach(addableSendingApps) { app in
          Button(app.displayName) { sendingModes[app.bundleId] = .paced }
        }
      } label: {
        Label("Thêm ứng dụng đang chạy", systemImage: "plus")
          .font(VK.Font.sans(12.5, .medium))
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .disabled(addableSendingApps.isEmpty)
      VKGroupHint("Chỉ cần khi một app bị rớt hoặc lặp chữ lúc bỏ dấu. \"Có nhịp nghỉ\" và \"Từng phím\" chậm hơn; nếu gõ nhanh mà chữ bị đảo thứ tự thì xoá dòng đó để về tự động.")
    }
  }

  @ViewBuilder
  private func sendingModeRow(bundleId: String, mode: AppSendingMode) -> some View {
    let name = RunningAppsLookup.displayName(for: bundleId)
    HStack(spacing: VK.Space.s3) {
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(VK.Font.sans(13.5, .semibold)).foregroundStyle(VK.Color.fg1)
        Text(bundleId).font(.system(size: 12, design: .monospaced)).foregroundStyle(VK.Color.fgMuted)
          .lineLimit(1).truncationMode(.middle)
      }
      Spacer(minLength: VK.Space.s2)
      Menu {
        ForEach(AppSendingMode.allCases, id: \.self) { option in
          Button(option.label) { sendingModes[bundleId] = option }
        }
        Divider()
        Button("Tự động (xoá)") { sendingModes.removeValue(forKey: bundleId) }
      } label: {
        Text(mode.label)
          .font(VK.Font.sans(12, .medium))
          .padding(.horizontal, 8).frame(height: 24)
          .background(Capsule().fill(VK.Color.bgSunken))
      }
      .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
      Button { sendingModes.removeValue(forKey: bundleId) } label: {
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
