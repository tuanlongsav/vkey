//
//  VKMacroTab.swift
//  vkey — Tab "Macro" redesign (đầy đủ chức năng 2.15).
//

import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct VKMacroTab: View {
  @Default(.macroEnabled) private var macroEnabled
  @Default(.macros) private var macros
  @State private var showingSuggestion = false
  @State private var importStatus = ""

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {

      // Master toggle
      VKSection {
        VKRowGroup {
          VKToggleRow(icon: "square.and.pencil", iconColor: VK.Color.brand,
                      label: "Bật / Tắt Macro",
                      hint: "Gõ phần \"Viết tắt\" rồi nhấn cách hoặc dấu câu, vkey thay bằng \"Cụm dài\".",
                      isOn: $macroEnabled)
        }
      }

      // Bảng macro
      VKSection("Danh sách macro") {
        VKRowGroup {
          // Header
          HStack {
            Text("VIẾT TẮT").font(.vk(.eyebrow)).foregroundStyle(VK.Color.fgMuted)
              .frame(width: 120, alignment: .leading)
            Text("CỤM DÀI").font(.vk(.eyebrow)).foregroundStyle(VK.Color.fgMuted)
              .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 28)
          }
          .padding(.horizontal, VK.Space.s4)
          .padding(.vertical, 9)

          if macros.isEmpty {
            VKEmptyState(
              systemImage: "text.badge.plus",
              title: "Chưa có macro nào",
              message: "Thêm cụm viết tắt đầu tiên — vkey sẽ tự bung khi bạn gõ.",
              actionTitle: "Thêm macro",
              action: { macros.append(Macro(from: "", to: "")) })
          } else {
            ForEach($macros) { $m in
              HStack(spacing: VK.Space.s3) {
                TextField("vt", text: $m.from)
                  .textFieldStyle(.plain)
                  .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                  .foregroundStyle(VK.Color.accent)
                  .frame(width: 120, alignment: .leading)
                TextField("Cụm dài", text: $m.to)
                  .textFieldStyle(.plain)
                  .font(.system(size: 13.5))
                  .foregroundStyle(VK.Color.fg1)
                  .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                  macros.removeAll { $0.id == m.id }
                } label: {
                  Image(systemName: "trash")
                    .font(.system(size: 13)).foregroundStyle(VK.Color.danger)
                }
                .buttonStyle(.plain).frame(width: 28)
              }
              .padding(.horizontal, VK.Space.s4).padding(.vertical, 9)
            }
          }
        }

        // Hàng nút
        HStack {
          VKButton(title: "Thêm", icon: "plus", variant: .primary, size: .sm) {
            macros.append(Macro(from: "", to: ""))
          }
          VKButton(title: "Xuất", icon: "square.and.arrow.up", variant: .secondary, size: .sm) {
            exportMacros()
          }
          VKButton(title: "Nhập", icon: "square.and.arrow.down", variant: .secondary, size: .sm) {
            importMacros()
          }
          Spacer()
          Text("\(macros.count) macro")
            .font(.vk(.small)).foregroundStyle(VK.Color.fgMuted)
        }
        .padding(.top, 2)

        if !importStatus.isEmpty {
          VKGroupHint(importStatus)
        }
      }

      // Gợi ý
      VKSection {
        VKRowGroup {
          VKRow(icon: "lightbulb.fill", iconColor: VK.Color.gold,
                label: "Gợi ý từ thường gõ",
                hint: "Đề xuất viết tắt cho các từ bạn gõ nhiều lần.") {
            VKButton(title: "Xem & thêm", variant: .secondary, size: .sm) {
              showingSuggestion = true
            }
          }
        }
      }
    }
    .sheet(isPresented: $showingSuggestion) {
      MacroSuggestionSheet()
    }
  }

  // MARK: - Export / Import (JSON)

  private func exportMacros() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "vkey-macros.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try JSONEncoder().encode(macros)
      try data.write(to: url)
      importStatus = "Đã xuất \(macros.count) macro."
    } catch {
      importStatus = "Lỗi xuất: \(error.localizedDescription)"
    }
  }

  private func importMacros() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      let imported = try JSONDecoder().decode([Macro].self, from: data)
      var existing = Set(macros.map { $0.from.lowercased() })
      var added = 0
      for m in imported where !m.from.isEmpty && !existing.contains(m.from.lowercased()) {
        macros.append(m); existing.insert(m.from.lowercased()); added += 1
      }
      importStatus = "Đã nhập \(added) macro mới (bỏ qua trùng)."
    } catch {
      importStatus = "Lỗi nhập: \(error.localizedDescription)"
    }
  }
}
