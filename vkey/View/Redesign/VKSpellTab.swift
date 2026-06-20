//
//  VKSpellTab.swift
//  vkey — Tab "Chính tả" redesign (đầy đủ chức năng 2.15).
//

import AppKit
import Defaults
import SwiftUI

struct VKSpellTab: View {
  @Default(.spellCheckEnabled) private var spellCheck
  @Default(.suggestionEnabled) private var suggestion
  @Default(.autoApplyHighConfidenceSuggestion) private var autoApply
  @Default(.personalDictionaryEnabled) private var personalDict
  @Default(.autoPersonalDictFeedback) private var weeklyFeedback
  @Default(.wordPredictionEnabled) private var wordPrediction
  @Default(.wordPredictionExcludedApps) private var predictionExcludedApps
  @Default(.englishAutoRestoreEnabled) private var spaceRestore
  @Default(.restorePolicy) private var restorePolicy
  @Default(.useEnVnReference) private var useRefDict
  @Default(.predictionHUDLineOffset) private var hudOffset
  @Default(.predictionHUDFontSize) private var hudFontSize
  @Default(.predictionMaxWords) private var predictionMaxWords
  @Default(.hudOpacityPercent) private var hudOpacity

  @State private var showingDictEditor = false
  @State private var newExcludedBundleId = ""
  @State private var showingExcludedRunningApps = false

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {

      // Cấu hình kiểm tra chính tả
      VKSection("Cấu hình kiểm tra chính tả") {
        VKRowGroup {
          VKToggleRow(icon: "checkmark.seal.fill", iconColor: VK.Color.success,
                      label: "Kiểm tra chính tả", isOn: $spellCheck)
          if spellCheck {
            VKToggleRow(icon: "lightbulb.fill", iconColor: VK.Color.gold,
                        label: "Gợi ý sửa lỗi chính tả", isOn: $suggestion)
            if suggestion {
              VKToggleRow(icon: "wand.and.stars", iconColor: VK.Color.info,
                          label: "Tự động sửa khi tin cậy cao", isOn: $autoApply)
            }
            VKToggleRow(icon: "person.fill", iconColor: VK.Color.ink200,
                        label: "Sử dụng từ điển cá nhân", isOn: $personalDict)
            VKRow(icon: "character.book.closed.fill", iconColor: VK.Color.brand,
                  label: "Từ điển cá nhân") {
              VKButton(title: "Quản lý", icon: "slider.horizontal.3", variant: .secondary, size: .sm) {
                showingDictEditor = true
              }
            }
            VKToggleRow(icon: "arrow.clockwise", iconColor: VK.Color.brand,
                        label: "Tự động đề xuất hàng tuần",
                        hint: "Học từ thống kê sử dụng để gợi ý bổ sung từ điển.",
                        isOn: $weeklyFeedback)
          }
        }
      }

      // Đoán từ tiếp theo
      if spellCheck {
        VKSection("Đoán từ tiếp theo") {
          VKRowGroup {
            VKToggleRow(icon: "sparkles", iconColor: VK.Color.gold,
                        label: "Bật đoán từ",
                        hint: "Hiện HUD nhỏ cạnh con trỏ, nhấn ⇥ Tab để nhận cụm 1–3 từ.",
                        isOn: $wordPrediction)
            if wordPrediction {
              VKRow(icon: "text.word.spacing", iconColor: VK.Color.gold,
                    label: "Số từ gợi ý tối đa") {
                stepperControl(value: $predictionMaxWords, range: 1...3, unit: "từ")
              }
              VKRow(icon: "arrow.up.and.down", iconColor: VK.Color.info,
                    label: "Khoảng cách HUD đến con trỏ") {
                stepperControl(value: $hudOffset, range: 1...20, unit: "dòng")
              }
              VKRow(icon: "textformat.size", iconColor: VK.Color.ink200,
                    label: "Cỡ chữ HUD") {
                stepperControl(value: $hudFontSize, range: 12...24, unit: "pt")
              }
              VKRow(icon: "circle.lefthalf.filled", iconColor: VK.Color.brand,
                    label: "Độ đậm HUD") {
                stepperControl(value: $hudOpacity, range: 30...100, step: 5, unit: "%")
              }
            }
          }
        }

        if wordPrediction {
          VKSection("Loại trừ ứng dụng") {
            VKRowGroup {
              if predictionExcludedApps.isEmpty {
                HStack {
                  Text("Chưa loại trừ app nào. Đoán từ hoạt động trên mọi app.")
                    .font(.vk(.small)).foregroundStyle(VK.Color.fgMuted)
                  Spacer()
                }
                .padding(.horizontal, VK.Space.s4).padding(.vertical, 12)
              } else {
                ForEach(predictionExcludedApps.sorted(), id: \.self) { bundleId in
                  excludedAppRow(bundleId: bundleId)
                }
              }
            }
            HStack(spacing: VK.Space.s2) {
              TextField("com.example.app", text: $newExcludedBundleId)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, design: .monospaced))
                .padding(.horizontal, 10).frame(height: 30)
                .background(
                  RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
                    .fill(VK.Color.bgElevated)
                    .overlay(RoundedRectangle(cornerRadius: VK.Radius.sm, style: .continuous)
                              .strokeBorder(VK.Color.border1, lineWidth: 1)))
              VKButton(title: "Thêm", icon: "plus", variant: .primary, size: .sm) {
                addExcludedApp()
              }
            }
            VKButton(title: "Chọn từ ứng dụng đang chạy", icon: "square.stack.3d.up",
                     variant: .secondary, fullWidth: true) {
              showingExcludedRunningApps = true
            }
            VKGroupHint("Đoán từ sẽ không hoạt động (không hiện HUD, không nhận Tab) trong các app được liệt kê.")
          }
        }
      }

      // Space Restore
      if spellCheck {
        VKSection("Tự động khôi phục tiếng Anh · Space Restore") {
          VKRowGroup {
            VKToggleRow(icon: "return", iconColor: VK.Color.info,
                        label: "Tự động khôi phục tiếng Anh", isOn: $spaceRestore)
            if spaceRestore {
              VKRow(icon: "slider.horizontal.3", iconColor: VK.Color.ink200,
                    label: "Chính sách khôi phục") {
                VKSegmented(selection: $restorePolicy,
                            options: [(.vietnameseFirst, "Ưu tiên VI"),
                                      (.balanced, "Cân bằng"),
                                      (.englishFirst, "Ưu tiên EN")])
              }
              VKToggleRow(icon: "character.book.closed.fill", iconColor: VK.Color.gold,
                          label: "Dùng từ điển tham chiếu Anh – Việt", isOn: $useRefDict)
            }
          }
          VKGroupHint("Lựa chọn cách xử lý với các từ mơ hồ giữa tiếng Việt và tiếng Anh (ví dụ: 'of', 'if', 'see', 'tee').")
        }
      }
    }
    .sheet(isPresented: $showingDictEditor) {
      PersonalDictionaryEditorView()
    }
    .sheet(isPresented: $showingExcludedRunningApps) {
      WordPredictionExcludedAppsSheet()
    }
  }

  @ViewBuilder
  private func excludedAppRow(bundleId: String) -> some View {
    let app = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }
    let name = app?.localizedName ?? bundleId.components(separatedBy: ".").last ?? bundleId
    HStack(spacing: VK.Space.s3) {
      if let icon = app?.icon {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 24, height: 24)
      } else {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(VK.Color.ink200)
          .frame(width: 24, height: 24)
          .overlay(Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(VK.Color.fg1)
        Text(bundleId).font(.system(size: 12, design: .monospaced)).foregroundStyle(VK.Color.fgMuted)
          .lineLimit(1).truncationMode(.middle)
      }
      Spacer(minLength: VK.Space.s2)
      Button {
        predictionExcludedApps.removeAll { $0 == bundleId }
      } label: {
        Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(VK.Color.danger)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, VK.Space.s4).padding(.vertical, 10)
  }

  private func addExcludedApp() {
    let id = newExcludedBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty, !predictionExcludedApps.contains(id) else { return }
    predictionExcludedApps.append(id)
    newExcludedBundleId = ""
  }

  // Value đặt rõ bên trái + Stepper bare bên phải (không bị cắt như cũ).
  @ViewBuilder
  private func stepperControl(value: Binding<Int>, range: ClosedRange<Int>,
                              step: Int = 1, unit: String) -> some View {
    HStack(spacing: 8) {
      Text("\(value.wrappedValue) \(unit)")
        .font(.system(size: 12.5, weight: .medium, design: .rounded))
        .foregroundStyle(VK.Color.fg2)
        .frame(minWidth: 52, alignment: .trailing)
        .monospacedDigit()
      Stepper("", value: value, in: range, step: step)
        .labelsHidden()
    }
    .fixedSize()
  }
}

// MARK: - Sheet chọn app đang chạy để loại trừ đoán từ

struct WordPredictionExcludedAppsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Default(.wordPredictionExcludedApps) private var excludedApps

  private struct RunningApp: Identifiable {
    let id: String
    let bundleId: String
    let displayName: String
    let icon: NSImage?
  }

  @State private var apps: [RunningApp] = []
  @State private var searchText = ""

  private var filteredApps: [RunningApp] {
    guard !searchText.isEmpty else { return apps }
    let q = searchText.lowercased()
    return apps.filter {
      $0.displayName.lowercased().contains(q) || $0.bundleId.lowercased().contains(q)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Loại trừ app khỏi đoán từ")
          .font(.headline)
        Text("Click 1 app để thêm vào danh sách loại trừ. App đã loại trừ sẽ hiện ✓.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 8)

      HStack {
        ThemedSymbol(name: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Tìm theo tên hoặc bundle ID", text: $searchText)
          .textFieldStyle(.plain)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color(NSColor.controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .padding(.horizontal, 16)
      .padding(.bottom, 8)

      Divider()

      if filteredApps.isEmpty {
        VStack(spacing: 8) {
          Spacer()
          ThemedSymbol(name: "tray")
            .font(.system(size: 36))
            .foregroundStyle(.tertiary)
          Text(apps.isEmpty ? "Không tìm thấy app đang chạy" : "Không có app khớp tìm kiếm")
            .font(.callout)
            .foregroundStyle(.secondary)
          Spacer()
        }
      } else {
        List {
          ForEach(filteredApps) { app in
            Button { addApp(app) } label: {
              HStack(spacing: 10) {
                if let icon = app.icon {
                  Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                } else {
                  ThemedSymbol(name: "app.dashed")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                  Text(app.displayName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                  Text(app.bundleId)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                Spacer()
                if excludedApps.contains(app.bundleId) {
                  ThemedSymbol(name: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                } else {
                  ThemedSymbol(name: "plus.circle")
                    .foregroundStyle(Color.accentColor)
                }
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(excludedApps.contains(app.bundleId))
          }
        }
        .listStyle(.inset)
      }

      Divider()

      HStack {
        Text("\(filteredApps.count) app")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Đóng") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding(16)
    }
    .frame(width: 420, height: 520)
    .onAppear(perform: loadRunningApps)
  }

  private func loadRunningApps() {
    let vkeyId = Bundle.main.bundleIdentifier ?? ""
    apps = NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular }
      .filter { $0.bundleIdentifier != nil && $0.bundleIdentifier != vkeyId }
      .compactMap { app in
        guard let id = app.bundleIdentifier else { return nil }
        return RunningApp(
          id: id,
          bundleId: id,
          displayName: app.localizedName ?? id,
          icon: app.icon
        )
      }
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }

  private func addApp(_ app: RunningApp) {
    guard !excludedApps.contains(app.bundleId) else { return }
    excludedApps.append(app.bundleId)
    loadRunningApps()
  }
}
