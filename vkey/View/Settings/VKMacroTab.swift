//
//  VKMacroTab.swift
//  vkey — Tab "Macro".
//

import Defaults
import SwiftUI

struct VKMacroTab: View {
  @Default(.macroEnabled) private var macroEnabled
  @Default(.macros) private var macros
  @State private var showingSuggestion = false
  @State private var importStatus = ""

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {
      VKSection {
        VKRowGroup {
          VKToggleRow(
            icon: "square.and.pencil", iconColor: VK.Color.brand,
            label: "Bật / Tắt Macro",
            hint: "Gõ phần \"Viết tắt\" rồi nhấn cách hoặc dấu câu, vkey thay bằng \"Cụm dài\".",
            isOn: $macroEnabled)
        }
      }

      VKSection("Danh sách macro") {
        VKRowGroup {
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
                  .font(VK.Font.sans(13.5))
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

        HStack {
          VKButton(title: "Thêm", icon: "plus", variant: .primary, size: .sm) {
            macros.append(Macro(from: "", to: ""))
          }
          VKButton(title: "Xuất", icon: "square.and.arrow.up", variant: .secondary, size: .sm, action: exportMacros)
          VKButton(title: "Nhập", icon: "square.and.arrow.down", variant: .secondary, size: .sm, action: importMacros)
          Spacer()
          Text("\(macros.count) macro")
            .font(.vk(.small)).foregroundStyle(VK.Color.fgMuted)
        }
        .padding(.top, 2)

        if !importStatus.isEmpty {
          VKGroupHint(importStatus)
        }
      }

      VKSection {
        VKRowGroup {
          VKRow(
            icon: "lightbulb.fill", iconColor: VK.Color.gold,
            label: "Gợi ý từ thường gõ",
            hint: "Đề xuất viết tắt cho các từ bạn gõ nhiều lần."
          ) {
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

  private func exportMacros() {
    guard let result = FileExportService.exportJSON(macros, defaultFileName: "vkey-macros.json")
    else { return }
    switch result {
    case .success:
      importStatus = "Đã xuất \(macros.count) macro."
    case .failure(let error):
      importStatus = "Lỗi xuất: \(error.localizedDescription)"
    }
  }

  private func importMacros() {
    guard let result = FileExportService.importJSON([Macro].self) else { return }
    switch result {
    case .success(let imported):
      var existing = Set(macros.map { $0.from.lowercased() })
      var added = 0
      for m in imported where !m.from.isEmpty && !existing.contains(m.from.lowercased()) {
        macros.append(m)
        existing.insert(m.from.lowercased())
        added += 1
      }
      importStatus = "Đã nhập \(added) macro mới (bỏ qua trùng)."
    case .failure(let error):
      importStatus = "Lỗi nhập: \(error.localizedDescription)"
    }
  }
}
