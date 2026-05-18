//
//  MacroView.swift
//  vkey
//
//  Created by KhanhIceTea on 12/3/24.
//

import Defaults
import Foundation
import SwiftUI

struct MacroView: View {
  @Default(.macros) private var macros
  @State private var selection = Set<Macro.ID>()

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Macro — Viết tắt → Cụm dài")
        .font(.headline)

      Text("Gõ phần \"Viết tắt\" rồi nhấn cách hoặc dấu câu, vkey sẽ thay bằng \"Cụm dài\".")
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
          Label("Thêm", systemImage: "plus")
        }

        Button {
          macros.removeAll { selection.contains($0.id) }
          selection.removeAll()
        } label: {
          Label("Xoá", systemImage: "trash")
        }
        .disabled(selection.isEmpty)

        Spacer()

        Text("\(macros.count) macro")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(width: 420, height: 360)
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
}

struct MacroView_Previews: PreviewProvider {
  static var previews: some View {
    MacroView()
  }
}
