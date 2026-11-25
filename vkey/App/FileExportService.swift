//
//  FileExportService.swift
//  vkey
//
//  Tiện ích chọn file (`NSSavePanel`/`NSOpenPanel`), xuất/nhập JSON & văn bản
//  dùng chung cho `VKStatsTab`, `VKMacroTab` và `PersonalDictionarySheet`.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum FileExportService {

  /// Mở `NSSavePanel` và trả về URL nếu người dùng bấm Lưu.
  @MainActor
  static func chooseSaveURL(
    defaultFileName: String,
    allowedContentTypes: [UTType]
  ) -> URL? {
    let panel = NSSavePanel()
    panel.allowedContentTypes = allowedContentTypes
    panel.nameFieldStringValue = defaultFileName
    return panel.runModal() == .OK ? panel.url : nil
  }

  /// Mở `NSOpenPanel` chọn 1 tệp và trả về URL nếu người dùng bấm Mở.
  @MainActor
  static func chooseOpenURL(allowedContentTypes: [UTType]) -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = allowedContentTypes
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    return panel.runModal() == .OK ? panel.url : nil
  }

  /// Xuất đối tượng `Encodable` ra file JSON qua `NSSavePanel`. Trả `nil` nếu huỷ.
  @MainActor
  static func exportJSON<T: Encodable>(
    _ value: T,
    defaultFileName: String
  ) -> Result<URL, Error>? {
    guard let url = chooseSaveURL(defaultFileName: defaultFileName, allowedContentTypes: [.json])
    else { return nil }
    do {
      let data = try JSONEncoder().encode(value)
      try data.write(to: url, options: .atomic)
      return .success(url)
    } catch {
      return .failure(error)
    }
  }

  /// Nhập đối tượng `Decodable` từ file JSON qua `NSOpenPanel`. Trả `nil` nếu huỷ.
  @MainActor
  static func importJSON<T: Decodable>(_ type: T.Type) -> Result<T, Error>? {
    guard let url = chooseOpenURL(allowedContentTypes: [.json]) else { return nil }
    do {
      let data = try Data(contentsOf: url)
      let decoded = try JSONDecoder().decode(T.self, from: data)
      return .success(decoded)
    } catch {
      return .failure(error)
    }
  }

  /// Đọc chuỗi văn bản từ file, ưu tiên UTF-8 và fallback tự nhận diện encoding.
  static func readTextFile(at url: URL) -> String? {
    if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
      return utf8
    }
    var detected = String.Encoding.utf8
    return try? String(contentsOf: url, usedEncoding: &detected)
  }

  /// Hiện NSAlert đơn giản dùng chung cho phản hồi nhập/xuất tệp.
  @MainActor
  static func showAlert(
    title: String,
    message: String,
    style: NSAlert.Style = .warning
  ) {
    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = title
    alert.informativeText = message
    alert.runModal()
  }
}
