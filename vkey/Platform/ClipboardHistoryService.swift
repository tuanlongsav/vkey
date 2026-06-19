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

  /// Giới hạn kích thước mỗi mục (byte) — tránh ảnh/tệp lớn chiếm RAM.
  static let maxEntryBytes = 2 * 1024 * 1024

  private static let capturePollDelays: [TimeInterval] = [0.06, 0.12, 0.20]

  private static let menuTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    f.dateStyle = .none
    return f
  }()

  struct Entry: Identifiable {
    let id: UUID
    let capturedAt: Date
    let items: [NSPasteboardItem]
    let preview: String
    let isFileEntry: Bool
    let fingerprint: String
  }

  private(set) var entries: [Entry] = []
  /// Bỏ qua capture khi changeCount khớp lần ghi pasteboard nội bộ (Text Tools restore).
  private var ignoredPasteboardChangeCount: Int?

  var hasEntries: Bool { !entries.isEmpty }

  private override init() {
    super.init()
  }

  func clear() {
    entries.removeAll()
    ignoredPasteboardChangeCount = nil
  }

  /// Poll pasteboard sau ⌘C — một số app cập nhật chậm hơn 60ms.
  func scheduleCaptureAfterCopy(since changeCount: Int, attempt: Int = 0) {
    guard Defaults[.clipboardHistoryEnabled] else { return }
    let delay = Self.capturePollDelays[min(attempt, Self.capturePollDelays.count - 1)]
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
      let pasteboard = NSPasteboard.general
      if pasteboard.changeCount != changeCount {
        self.captureIfPasteboardChanged(since: changeCount)
      } else if attempt + 1 < Self.capturePollDelays.count {
        self.scheduleCaptureAfterCopy(since: changeCount, attempt: attempt + 1)
      }
    }
  }

  /// Gọi sau ⌘C khi pasteboard đã đổi.
  func captureIfPasteboardChanged(since changeCount: Int) {
    guard Defaults[.clipboardHistoryEnabled] else { return }
    let pasteboard = NSPasteboard.general
    guard pasteboard.changeCount != changeCount else { return }
    if pasteboard.changeCount == ignoredPasteboardChangeCount {
      ignoredPasteboardChangeCount = nil
      return
    }
    captureCurrentPasteboard(pasteboard)
  }

  /// Đánh dấu changeCount sau khi vkey ghi pasteboard (không chặn ⌘C kế tiếp của user).
  func markInternalPasteboardWrite(_ pasteboard: NSPasteboard = .general) {
    ignoredPasteboardChangeCount = pasteboard.changeCount
  }

  func captureCurrentPasteboard(_ pasteboard: NSPasteboard = .general) {
    guard Defaults[.clipboardHistoryEnabled] else { return }
    let mode = Defaults[.clipboardHistoryContentMode]
    guard let snapshot = Self.buildSnapshot(from: pasteboard, mode: mode) else { return }
    if let latest = entries.first, latest.fingerprint == snapshot.fingerprint {
      return
    }
    let entry = Entry(
      id: UUID(),
      capturedAt: Date(),
      items: snapshot.items,
      preview: snapshot.preview,
      isFileEntry: snapshot.isFileEntry,
      fingerprint: snapshot.fingerprint
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
    let cap = max(3, min(50, Defaults[.clipboardHistoryCapacity]))
    let menu = NSMenu(title: "Clipboard")
    for (index, entry) in entries.prefix(cap).enumerated() {
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
    TextConversionService.sendCmdV()
  }

  func pasteEntry(at index: Int) {
    guard entries.indices.contains(index) else { return }
    let entry = entries[index]
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    if !entry.items.isEmpty {
      pasteboard.writeObjects(entry.items)
    }
    markInternalPasteboardWrite(pasteboard)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
      TextConversionService.sendCmdV()
    }
  }

  // MARK: - Snapshot helpers

  struct Snapshot {
    let items: [NSPasteboardItem]
    let preview: String
    let isFileEntry: Bool
    let fingerprint: String
  }

  static func buildSnapshot(
    from pasteboard: NSPasteboard,
    mode: ClipboardHistoryContentMode
  ) -> Snapshot? {
    guard let rawItems = pasteboard.pasteboardItems, !rawItems.isEmpty else { return nil }

    let text = pasteboard.string(forType: .string)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let fileURLs = fileURLs(from: pasteboard)

    let snapshot: Snapshot?
    switch mode {
    case .textOnly:
      guard !text.isEmpty else { return nil }
      let items = snapshotItems(rawItems, allowFiles: false)
      guard !items.isEmpty else { return nil }
      snapshot = Snapshot(
        items: items,
        preview: previewText(text),
        isFileEntry: false,
        fingerprint: fingerprint(for: items)
      )

    case .textAndFiles:
      if !text.isEmpty {
        let items = snapshotItems(rawItems, allowFiles: true)
        guard !items.isEmpty else { return nil }
        snapshot = Snapshot(
          items: items,
          preview: previewText(text),
          isFileEntry: false,
          fingerprint: fingerprint(for: items)
        )
      } else {
        guard !fileURLs.isEmpty else { return nil }
        let items = snapshotItems(rawItems, allowFiles: true)
        guard !items.isEmpty else { return nil }
        snapshot = Snapshot(
          items: items,
          preview: previewFiles(fileURLs),
          isFileEntry: true,
          fingerprint: fingerprint(for: items)
        )
      }
    }

    guard let snapshot else { return nil }
    guard totalDataSize(items: snapshot.items) <= maxEntryBytes else { return nil }
    return snapshot
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

  static func fingerprint(for items: [NSPasteboardItem]) -> String {
    items.map { item in
      item.types
        .sorted { $0.rawValue < $1.rawValue }
        .map { type in
          if let data = item.data(forType: type) {
            var digest = Hasher()
            digest.combine(data)
            return "\(type.rawValue):d:\(data.count):\(digest.finalize())"
          }
          if let string = item.string(forType: type) {
            var digest = Hasher()
            digest.combine(string)
            return "\(type.rawValue):s:\(string.utf8.count):\(digest.finalize())"
          }
          return "\(type.rawValue):0"
        }
        .joined(separator: ",")
    }
    .joined(separator: "|")
  }

  static func totalDataSize(items: [NSPasteboardItem]) -> Int {
    items.reduce(0) { total, item in
      total + item.types.reduce(0) { sum, type in
        sum + (item.data(forType: type)?.count ?? item.string(forType: type)?.utf8.count ?? 0)
      }
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
    return "\(entry.preview)  ·  \(menuTimeFormatter.string(from: entry.capturedAt))"
  }
}
