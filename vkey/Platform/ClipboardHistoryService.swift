//
//  ClipboardHistoryService.swift
//  vkey
//
//  Lịch sử clipboard tùy chỉnh: ⌘C lưu snapshot, ⌥⌘V mở menu chọn mục paste.
//  Lưu trong RAM (phiên làm việc) — không ghi disk.
//

import AppKit
import Defaults
import Foundation

enum ClipboardHistoryContentMode: String, CaseIterable, Codable, Defaults.Serializable {
  case textOnly
  case textAndFiles

  var label: String {
    switch self {
    case .textOnly: return "Chỉ văn bản"
    case .textAndFiles: return "Văn bản và tệp"
    }
  }
}

@MainActor
final class ClipboardHistoryService: NSObject {
  static let shared = ClipboardHistoryService()

  struct Entry: Identifiable {
    let id: UUID
    let capturedAt: Date
    let items: [NSPasteboardItem]
    let preview: String
    let isFileEntry: Bool
  }

  private(set) var entries: [Entry] = []
  /// Bỏ qua lần capture kế tiếp (Text Tools / paste nội bộ của vkey).
  var suppressNextCapture = false

  var hasEntries: Bool { !entries.isEmpty }

  private override init() {
    super.init()
  }

  func clear() {
    entries.removeAll()
  }

  /// Gọi sau Cmd+C khi pasteboard đã đổi.
  func captureIfPasteboardChanged(since changeCount: Int) {
    guard Defaults[.clipboardHistoryEnabled] else { return }
    if suppressNextCapture {
      suppressNextCapture = false
      return
    }
    let pasteboard = NSPasteboard.general
    guard pasteboard.changeCount != changeCount else { return }
    captureCurrentPasteboard(pasteboard)
  }

  func captureCurrentPasteboard(_ pasteboard: NSPasteboard = .general) {
    guard Defaults[.clipboardHistoryEnabled] else { return }
    let mode = Defaults[.clipboardHistoryContentMode]
    guard let snapshot = Self.buildSnapshot(from: pasteboard, mode: mode) else { return }
    if let latest = entries.first, latest.preview == snapshot.preview,
       latest.isFileEntry == snapshot.isFileEntry {
      return
    }
    let entry = Entry(
      id: UUID(),
      capturedAt: Date(),
      items: snapshot.items,
      preview: snapshot.preview,
      isFileEntry: snapshot.isFileEntry
    )
    entries.insert(entry, at: 0)
    let cap = max(3, min(50, Defaults[.clipboardHistoryCapacity]))
    if entries.count > cap {
      entries.removeLast(entries.count - cap)
    }
  }

  func showPickerAndPaste() {
    guard Defaults[.clipboardHistoryEnabled], !entries.isEmpty else {
      NSSound.beep()
      return
    }
    let menu = NSMenu(title: "Clipboard")
    for (index, entry) in entries.prefix(20).enumerated() {
      let title = Self.menuTitle(for: entry, index: index)
      let item = NSMenuItem(title: title, action: #selector(handlePasteMenuItem(_:)), keyEquivalent: "")
      item.target = self
      item.tag = index
      item.toolTip = entry.preview
      menu.addItem(item)
    }
    menu.addItem(.separator())
    let plain = NSMenuItem(
      title: "Dán clipboard hệ thống (⌘V)",
      action: #selector(pasteSystemClipboard),
      keyEquivalent: ""
    )
    plain.target = self
    menu.addItem(plain)

    let location = NSEvent.mouseLocation
    menu.popUp(positioning: nil, at: location, in: nil)
  }

  @objc private func handlePasteMenuItem(_ sender: NSMenuItem) {
    let index = sender.tag
    guard entries.indices.contains(index) else { return }
    pasteEntry(at: index)
  }

  @objc private func pasteSystemClipboard() {
    suppressNextCapture = true
    TextConversionService.sendCmdV()
  }

  func pasteEntry(at index: Int) {
    guard entries.indices.contains(index) else { return }
    let entry = entries[index]
    let pasteboard = NSPasteboard.general
    suppressNextCapture = true
    pasteboard.clearContents()
    if !entry.items.isEmpty {
      pasteboard.writeObjects(entry.items)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
      TextConversionService.sendCmdV()
    }
  }

  // MARK: - Snapshot helpers

  struct Snapshot {
    let items: [NSPasteboardItem]
    let preview: String
    let isFileEntry: Bool
  }

  static func buildSnapshot(
    from pasteboard: NSPasteboard,
    mode: ClipboardHistoryContentMode
  ) -> Snapshot? {
    guard let rawItems = pasteboard.pasteboardItems, !rawItems.isEmpty else { return nil }

    let text = pasteboard.string(forType: .string)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let fileURLs = fileURLs(from: pasteboard)

    switch mode {
    case .textOnly:
      guard !text.isEmpty else { return nil }
      let items = snapshotItems(rawItems, allowFiles: false)
      guard !items.isEmpty else { return nil }
      return Snapshot(items: items, preview: previewText(text), isFileEntry: false)

    case .textAndFiles:
      if !text.isEmpty {
        return Snapshot(
          items: snapshotItems(rawItems, allowFiles: true),
          preview: previewText(text),
          isFileEntry: false
        )
      }
      guard !fileURLs.isEmpty else { return nil }
      let items = snapshotItems(rawItems, allowFiles: true)
      guard !items.isEmpty else { return nil }
      return Snapshot(
        items: items,
        preview: previewFiles(fileURLs),
        isFileEntry: true
      )
    }
  }

  static func snapshotItems(_ items: [NSPasteboardItem], allowFiles: Bool) -> [NSPasteboardItem] {
    items.compactMap { item in
      let copy = NSPasteboardItem()
      var wrote = false
      for type in item.types {
        if !allowFiles, type == .fileURL || type.rawValue.contains("file-url") {
          continue
        }
        if let data = item.data(forType: type) {
          copy.setData(data, forType: type)
          wrote = true
        } else if let string = item.string(forType: type) {
          copy.setString(string, forType: type)
          wrote = true
        }
      }
      return wrote ? copy : nil
    }
  }

  static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
      return urls
    }
    return []
  }

  static func previewText(_ text: String) -> String {
    let oneLine = text.replacingOccurrences(of: "\n", with: " ")
    if oneLine.count <= 72 { return oneLine }
    return String(oneLine.prefix(69)) + "…"
  }

  static func previewFiles(_ urls: [URL]) -> String {
    let names = urls.prefix(3).map { $0.lastPathComponent }
    let suffix = urls.count > 3 ? " +\(urls.count - 3)" : ""
    return "📎 " + names.joined(separator: ", ") + suffix
  }

  static func menuTitle(for entry: Entry, index: Int) -> String {
    if index == 0 {
      return entry.preview
    }
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return "\(entry.preview)  ·  \(formatter.string(from: entry.capturedAt))"
  }
}
