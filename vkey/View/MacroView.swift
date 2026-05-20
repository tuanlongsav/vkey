//
//  MacroView.swift
//  vkey
//
//  Created by KhanhIceTea on 12/3/24.
//

import AppKit
import Defaults
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct MacroView: View {
  @Default(.macros) private var macros
  @Default(.macroEnabled) private var macroEnabled
  @State private var selection = Set<Macro.ID>()
  @State private var importStatus: String = ""
  @State private var showingSuggestionSheet = false

  /// Số gợi ý từ thống kê còn lại (chưa có macro `to == word` rồi).
  /// Tính lại mỗi khi `macros` thay đổi qua `onChange`.
  @State private var suggestionCount: Int = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Macro — Viết tắt → Cụm dài")
        .font(.headline)

      Toggle(isOn: $macroEnabled) {
        Label("Bật / Tắt Macro", themedSymbol: "text.cursor")
      }
      .toggleStyle(SwitchToggleStyle(tint: .accentColor))

      Text(macroEnabled
        ? "Gõ phần \"Viết tắt\" rồi nhấn cách hoặc dấu câu, vkey sẽ thay bằng \"Cụm dài\"."
        : "Macro đang tắt. Danh sách bên dưới được giữ — bật lại để dùng.")
        .font(.caption)
        .foregroundStyle(.secondary)

      Table(macros, selection: $selection) {
        TableColumn("Viết tắt") { macro in
          TextField(
            "viết tắt",
            text: binding(for: macro, keyPath: \.from)
          )
        }
        TableColumn("Cụm dài") { macro in
          TextField(
            "cụm dài",
            text: binding(for: macro, keyPath: \.to)
          )
        }
      }

      HStack {
        Button {
          let new = Macro(from: "", to: "")
          macros.insert(new, at: 0)
          selection = [new.id]
        } label: {
          Label("Thêm", themedSymbol: "plus")
        }

        Button {
          macros.removeAll { selection.contains($0.id) }
          selection.removeAll()
        } label: {
          Label("Xoá", themedSymbol: "trash")
        }
        .disabled(selection.isEmpty)

        Spacer()

        // 1.5.0: Import / Export macros as JSON. Useful for sharing setups
        // between machines and for the upcoming onboarding macro preset.
        Button(action: exportMacros) {
          Label("Xuất", themedSymbol: "square.and.arrow.up")
        }
        .help("Lưu danh sách macro ra tệp JSON")

        Button(action: importMacros) {
          Label("Nhập", themedSymbol: "square.and.arrow.down")
        }
        .help("Đọc tệp JSON và gộp vào danh sách hiện tại (bỏ qua trùng)")

        Text("\(macros.count) macro")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if !importStatus.isEmpty {
        Text(importStatus)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.top, 2)
      }

      // 1.5.5: Gợi ý macro từ Thống kê.
      if macroEnabled {
        Divider()
        HStack(spacing: 8) {
          Image(systemName: "lightbulb.fill")
            .foregroundStyle(.yellow)
          if suggestionCount == 0 {
            Text("Chưa có gợi ý — gõ nhiều hơn để vkey học thói quen của bạn (cần ≥10 lần/từ).")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            Text("Có \(suggestionCount) từ bạn gõ ≥10 lần có thể đặt thành viết tắt.")
              .font(.caption)
          }
          Spacer()
          if suggestionCount > 0 {
            Button("Xem & thêm") { showingSuggestionSheet = true }
          }
        }
      }
    }
    .padding(12)
    .frame(minWidth: 160, minHeight: 720)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $showingSuggestionSheet) {
      MacroSuggestionSheet()
        .onDisappear { recomputeSuggestionCount() }
    }
    .onAppear { recomputeSuggestionCount() }
    .onChange(of: macros) { _ in recomputeSuggestionCount() }
  }

  private func recomputeSuggestionCount() {
    let aggregated = UsageStatistics.shared.aggregatedTopVietnameseWords(threshold: 10)
    let existingTo = Set(macros.map { $0.to.lowercased() })
    suggestionCount = aggregated.filter { !existingTo.contains($0.word.lowercased()) }.count
  }

  private func binding(for macro: Macro, keyPath: WritableKeyPath<Macro, String>) -> Binding<String> {
    Binding(
      get: {
        guard let index = macros.firstIndex(where: { $0.id == macro.id }) else { return "" }
        return macros[index][keyPath: keyPath]
      },
      set: { newValue in
        guard let index = macros.firstIndex(where: { $0.id == macro.id }) else { return }
        macros[index][keyPath: keyPath] = newValue
      }
    )
  }

  // MARK: - Import / Export (1.5.0)

  /// Persisted form of a macro — no UUID, just from/to. Keeps imports
  /// idempotent across machines and matches the `macros_recommended` shape
  /// inside `lexicon-update.json`.
  private struct MacroExport: Codable {
    let from: String
    let to: String
  }

  private func exportMacros() {
    let panel = NSSavePanel()
    panel.title = "Xuất Macro"
    panel.nameFieldStringValue = "vkey-macros.json"
    panel.allowedContentTypes = [.json]

    guard panel.runModal() == .OK, let url = panel.url else { return }

    let payload = macros.map { MacroExport(from: $0.from, to: $0.to) }
    do {
      let data = try JSONEncoder.indented.encode(payload)
      try data.write(to: url, options: .atomic)
      importStatus = "Đã xuất \(payload.count) macro → \(url.lastPathComponent)"
    } catch {
      importStatus = "Lỗi khi xuất: \(error.localizedDescription)"
    }
  }

  private func importMacros() {
    let panel = NSOpenPanel()
    panel.title = "Nhập Macro"
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false

    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
      let data = try Data(contentsOf: url)
      let seeds = try JSONDecoder().decode([MacroExport].self, from: data)
      let imported = seeds.filter {
        !$0.from.trimmingCharacters(in: .whitespaces).isEmpty &&
        !$0.to.trimmingCharacters(in: .whitespaces).isEmpty
      }
      guard !imported.isEmpty else {
        importStatus = "File không chứa macro hợp lệ."
        return
      }

      // Đếm trùng (theo from HOẶC to) để hiển thị trong dialog.
      let existingFroms = Set(macros.map { $0.from })
      let existingTos = Set(macros.map { $0.to })
      let duplicates = imported.filter {
        existingFroms.contains($0.from) || existingTos.contains($0.to)
      }.count

      let alert = NSAlert()
      alert.messageText = "Nhập \(imported.count) macro từ \(url.lastPathComponent)?"
      alert.informativeText = duplicates > 0
        ? "Có \(duplicates) macro trùng `viết tắt` hoặc `viết dài` với macro hiện tại. Chọn cách xử lý:"
        : "Không có macro nào trùng — Gộp và Ghi đè cho cùng kết quả."
      alert.alertStyle = .informational
      alert.addButton(withTitle: "Gộp (giữ macro hiện tại)")
      alert.addButton(withTitle: "Ghi đè (thay macro trùng)")
      alert.addButton(withTitle: "Huỷ")

      let response = alert.runModal()
      switch response {
      case .alertFirstButtonReturn:  // Gộp
        mergeImported(imported, replace: false)
      case .alertSecondButtonReturn: // Ghi đè
        mergeImported(imported, replace: true)
      default:
        importStatus = "Đã huỷ nhập macro."
        return
      }
    } catch {
      importStatus = "Lỗi khi nhập: \(error.localizedDescription)"
    }
  }

  /// Áp dụng `imported` vào `macros` theo policy.
  /// - `replace=false` (Gộp): skip imported macro nếu trùng `from` HOẶC `to`.
  /// - `replace=true` (Ghi đè): với mỗi imported macro, xóa các macro hiện
  ///   có trùng `from` HOẶC `to`, rồi thêm imported.
  private func mergeImported(_ imported: [MacroExport], replace: Bool) {
    var current = macros
    var added = 0
    var replaced = 0
    var skipped = 0

    for seed in imported {
      let dupIdxs = current.indices.filter {
        current[$0].from == seed.from || current[$0].to == seed.to
      }

      if replace {
        // Xóa từ cuối lên đầu để giữ index ổn định.
        for idx in dupIdxs.reversed() {
          current.remove(at: idx)
        }
        current.append(Macro(from: seed.from, to: seed.to))
        if dupIdxs.isEmpty { added += 1 } else { replaced += 1 }
      } else {
        // Gộp: skip nếu trùng.
        if !dupIdxs.isEmpty {
          skipped += 1
          continue
        }
        current.append(Macro(from: seed.from, to: seed.to))
        added += 1
      }
    }

    macros = current
    importStatus = replace
      ? "Đã ghi đè: thêm \(added), thay thế \(replaced) macro trùng."
      : "Đã gộp: thêm \(added) macro mới, bỏ qua \(skipped) trùng."
  }
}

private extension JSONEncoder {
  /// Pre-configured encoder for human-readable macro export.
  static let indented: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return e
  }()
}

struct MacroView_Previews: PreviewProvider {
  static var previews: some View {
    MacroView()
  }
}
