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
    .frame(width: 480, height: 420)
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

      // De-duplicate by `from` field. Existing macros take precedence so the
      // user's current bindings are never silently overwritten.
      let existing = Set(macros.map { $0.from.trimmingCharacters(in: .whitespaces) })
      var added = 0
      for seed in seeds {
        let from = seed.from.trimmingCharacters(in: .whitespaces)
        if from.isEmpty || existing.contains(from) { continue }
        macros.append(Macro(from: seed.from, to: seed.to))
        added += 1
      }
      importStatus = "Đã nhập \(added) macro mới (bỏ qua \(seeds.count - added) trùng)"
    } catch {
      importStatus = "Lỗi khi nhập: \(error.localizedDescription)"
    }
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
