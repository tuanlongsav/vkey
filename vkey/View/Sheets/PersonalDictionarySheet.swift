//
//  PersonalDictionarySheet.swift
//  vkey
//
//  Sheet quản lý từ điển cá nhân (Cho phép / Ưu tiên giữ / Loại bỏ),
//  tách ra khỏi `SettingView.swift` cũ và dùng chung `VKSheetScaffold` + `FileExportService`.
//

import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct PersonalDictionaryEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedTab = 0
  @State private var newWord = ""

  @Default(.userAllowWords) private var userAllowWords
  @Default(.userKeepWords) private var userKeepWords
  @Default(.userDenyWords) private var userDenyWords

  var body: some View {
    VKSheetScaffold(
      title: "Quản lý từ điển cá nhân",
      width: 400,
      height: 520
    ) {
      VStack(spacing: 0) {
        Picker("Loại từ điển", selection: $selectedTab) {
          Text("Cho phép").tag(0)
          Text("Ưu tiên giữ").tag(1)
          Text("Loại bỏ").tag(2)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

        HStack {
          TextField("Nhập từ mới…", text: $newWord)
            .textFieldStyle(.roundedBorder)
            .onSubmit(addWord)
          Button("Thêm", action: addWord)
            .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)

        List {
          let words = currentWordsList()
          if words.isEmpty {
            Text("Chưa có từ nào trong danh sách.")
              .foregroundColor(.secondary)
              .italic()
              .frame(maxWidth: .infinity, alignment: .center)
              .listRowBackground(Color.clear)
          } else {
            ForEach(words, id: \.self) { word in
              HStack {
                Text(word)
                Spacer()
                Button { removeWord(word) } label: {
                  Image(systemName: "trash")
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
        .listStyle(.inset)
      }
    } footer: {
      Button(action: importWords) {
        Label("Nhập file", systemImage: "square.and.arrow.down")
      }
      Button(action: exportWords) {
        Label("Xuất file", systemImage: "square.and.arrow.up")
      }
      Spacer()
      Button("Đóng") { dismiss() }
        .keyboardShortcut(.defaultAction)
    }
  }

  // MARK: - Import / Export

  private func importWords() {
    guard let url = FileExportService.chooseOpenURL(allowedContentTypes: [.text, .commaSeparatedText])
    else { return }
    guard let content = FileExportService.readTextFile(at: url) else {
      FileExportService.showAlert(
        title: "Không đọc được file",
        message: "File không phải dạng văn bản hoặc dùng bảng mã không hỗ trợ.")
      return
    }

    let separators = CharacterSet.newlines.union(CharacterSet(charactersIn: ","))
    let entries = content.components(separatedBy: separators)

    var targetList = currentWordsList()
    var addedCount = 0
    for entry in entries {
      let word = entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      if !word.isEmpty && !targetList.contains(word) {
        targetList.append(word)
        addedCount += 1
      }
    }

    if addedCount > 0 {
      setCurrentWordsList(targetList)
    }
    FileExportService.showAlert(
      title: "Nhập từ điển",
      message: addedCount > 0
        ? "Đã thêm \(addedCount) từ mới vào danh sách."
        : "Không có từ mới nào (toàn bộ đã có sẵn hoặc file trống).",
      style: .informational)
  }

  private func exportWords() {
    guard let url = FileExportService.chooseSaveURL(
      defaultFileName: "vkey_dictionary_export.txt",
      allowedContentTypes: [.text])
    else { return }
    let content = currentWordsList().joined(separator: "\n")
    do {
      try content.write(to: url, atomically: true, encoding: .utf8)
    } catch {
      FileExportService.showAlert(
        title: "Không xuất được file",
        message: error.localizedDescription)
    }
  }

  // MARK: - List Helpers

  private func currentWordsList() -> [String] {
    switch selectedTab {
    case 0: return userAllowWords
    case 1: return userKeepWords
    case 2: return userDenyWords
    default: return []
    }
  }

  private func setCurrentWordsList(_ list: [String]) {
    switch selectedTab {
    case 0: userAllowWords = list
    case 1: userKeepWords = list
    case 2: userDenyWords = list
    default: break
    }
  }

  private func addWord() {
    let cleaned = newWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !cleaned.isEmpty else { return }
    var list = currentWordsList()
    if !list.contains(cleaned) {
      list.append(cleaned)
      setCurrentWordsList(list)
    }
    newWord = ""
  }

  private func removeWord(_ word: String) {
    var list = currentWordsList()
    list.removeAll { $0 == word }
    setCurrentWordsList(list)
  }
}
