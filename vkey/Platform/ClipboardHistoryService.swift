//
//  ClipboardHistoryService.swift
//  vkey
//
//  Lịch sử clipboard tùy chỉnh: ⌘C lưu snapshot; phím tắt (mặc định ⇧⌘V)
//  mở menu chọn mục paste. Lưu trong RAM (phiên làm việc) — không ghi disk.
//

import AppKit
import Defaults
import Foundation
import os
import UniformTypeIdentifiers

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
  /// Đọc từ event tap (không phải main thread) — tránh nuốt ⇧⌘V khi history rỗng.
  private let entryCount = OSAllocatedUnfairLock(initialState: 0)
  nonisolated var hasEntriesForEventTap: Bool {
    entryCount.withLock { $0 > 0 }
  }
  /// Bỏ qua capture khi changeCount khớp lần ghi pasteboard nội bộ (Text Tools restore).
  private var ignoredPasteboardChangeCount: Int?
  /// Tránh HUD cảnh báo oversized lặp liên tục khi user ⌘C nhiều lần.
  private var lastOversizedWarningAt: Date?
  private let oversizedWarningDebounce: TimeInterval = 8

  private override init() {
    super.init()
  }

  func clear() {
    entries.removeAll()
    syncEntryCount()
    ignoredPasteboardChangeCount = nil
  }

  private func syncEntryCount() {
    let count = entries.count
    entryCount.withLock { $0 = count }
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
    // Dựng snapshot TRƯỚC rồi mới đo. Trước đây đo trước bằng một hàm ước
    // lượng đọc MỌI loại dữ liệu từ pasteboard server chỉ để cộng byte, rồi
    // `buildSnapshot` đọc lại lần hai. Đo trên bản chép thì
    // mỗi loại chỉ qua IPC một lần, và nội dung vốn không được lưu (vd ảnh
    // không kèm chữ ở chế độ chỉ văn bản) không còn bật HUD "quá lớn" oan.
    guard let snapshot = Self.buildSnapshot(from: pasteboard, mode: mode) else { return }
    let maxBytes = Self.maxEntryBytesFromSettings()
    if snapshot.byteCount > maxBytes {
      showOversizedWarning(actualBytes: snapshot.byteCount, maxBytes: maxBytes)
      return
    }
    // Băm SAU khi qua giới hạn — mục bị từ chối có thể tới 200 MB.
    let fingerprint = Self.fingerprint(for: snapshot.items)
    if let latest = entries.first, latest.fingerprint == fingerprint {
      return
    }
    let entry = Entry(
      id: UUID(),
      capturedAt: Date(),
      items: snapshot.items,
      preview: snapshot.preview,
      isFileEntry: snapshot.isFileEntry,
      fingerprint: fingerprint
    )
    entries.insert(entry, at: 0)
    let cap = max(3, min(50, Defaults[.clipboardHistoryCapacity]))
    if entries.count > cap {
      entries.removeLast(entries.count - cap)
    }
    syncEntryCount()
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
    /// Dung lượng tính vào giới hạn mỗi mục: payload đã chép + (chế độ có tệp)
    /// kích thước trên đĩa của các tệp được tham chiếu (hành vi 3.18).
    let byteCount: Int
  }

  static func buildSnapshot(
    from pasteboard: NSPasteboard,
    mode: ClipboardHistoryContentMode
  ) -> Snapshot? {
    guard let rawItems = pasteboard.pasteboardItems, !rawItems.isEmpty else { return nil }

    // Privacy (P1): KHÔNG bao giờ lưu vào lịch sử các mục bí mật/tạm thời do
    // trình quản lý mật khẩu (1Password/Bitwarden/Keychain…) đánh dấu bằng
    // `org.nspasteboard.ConcealedType` (và Transient/AutoGenerated) — chúng gắn
    // marker này chính là để công cụ clipboard-history bỏ qua. Tôn trọng điều đó
    // để mật khẩu không lọt vào history kèm preview plaintext.
    if containsSecretPasteboardType(rawItems) { return nil }

    let text = pasteboard.string(forType: .string)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let allowFiles = mode == .textAndFiles
    // Chế độ chỉ văn bản không bao giờ dùng tới URL tệp — khỏi đọc.
    let fileURLs = allowFiles ? fileURLs(from: pasteboard) : []

    let preview: String
    let isFileEntry: Bool
    if !text.isEmpty {
      preview = previewText(text)
      isFileEntry = false
    } else if !fileURLs.isEmpty {
      preview = previewFiles(fileURLs)
      isFileEntry = true
    } else {
      return nil
    }

    let items = snapshotItems(rawItems, allowFiles: allowFiles)
    guard !items.isEmpty else { return nil }
    let fileBytes = fileURLs.isEmpty ? 0 : filePayloadBytes(from: fileURLs)
    return Snapshot(
      items: items,
      preview: preview,
      isFileEntry: isFileEntry,
      byteCount: payloadBytes(of: items, allowFiles: true) + fileBytes
    )
  }

  /// Các marker pasteboard báo hiệu nội dung KHÔNG được lưu vào history
  /// (mật khẩu, token dùng một lần, giá trị auto-fill sinh tự động).
  static let secretPasteboardTypes: Set<String> = [
    "org.nspasteboard.ConcealedType",
    "org.nspasteboard.TransientType",
    "org.nspasteboard.AutoGeneratedType",
  ]

  /// True nếu bất kỳ item nào mang marker bí mật/tạm thời ở trên.
  static func containsSecretPasteboardType(_ items: [NSPasteboardItem]) -> Bool {
    items.contains { item in
      item.types.contains { secretPasteboardTypes.contains($0.rawValue) }
    }
  }

  /// Các loại dữ liệu của `item` được chép vào lịch sử (chưa đọc payload nào).
  ///
  /// Khi item ĐÃ có chữ (plain text / RTF / HTML), bản ảnh / PDF / webarchive /
  /// RTFD của nó là CÙNG nội dung được app nguồn dựng lại thành hình — thứ nặng
  /// nhất trên pasteboard: Excel/Word/Numbers kèm TIFF + PDF của vùng chọn,
  /// Safari kèm webarchive chứa luôn ảnh của trang. Đa số là dữ liệu HỨA
  /// (promised): app nguồn chỉ dựng khi có người đọc, nên chính lời gọi
  /// `data(forType:)` của vkey bắt Excel vẽ ra TIFF chục MB rồi vkey giữ nó
  /// trong RAM suốt phiên. Bỏ chúng TRƯỚC khi đọc — dán lại vẫn giữ định dạng
  /// qua RTF/HTML. Item không có chữ (vd tệp từ Finder) giữ nguyên như trước.
  ///
  /// Ngoại lệ: item mang `public.url` (vd "Sao chép ảnh" của trình duyệt kèm
  /// URL dạng chữ) — ở đó chữ chỉ là địa chỉ, ảnh mới là nội dung → giữ nguyên.
  static func capturedTypes(
    of item: NSPasteboardItem,
    allowFiles: Bool
  ) -> [NSPasteboard.PasteboardType] {
    let types = item.types
    let dropRenditions = types.contains { isTextType($0) } && !types.contains(.URL)
    return types.filter { type in
      if !allowFiles, type == .fileURL || type.rawValue.contains("file-url") {
        return false
      }
      return !(dropRenditions && isRenditionType(type))
    }
  }

  static func isTextType(_ type: NSPasteboard.PasteboardType) -> Bool {
    if type == .string || type == .rtf || type == .html { return true }
    return resolvedUTType(type)?.conforms(to: .plainText) ?? false
  }

  /// Ảnh, PDF, audio/video, webarchive, RTFD — xem `capturedTypes(of:allowFiles:)`.
  private static let renditionUTTypes: [UTType] = [
    .image, .pdf, .audiovisualContent, .webArchive, .rtfd, .flatRTFD,
  ]

  static func isRenditionType(_ type: NSPasteboard.PasteboardType) -> Bool {
    guard let uti = resolvedUTType(type) else { return false }
    return renditionUTTypes.contains { uti.conforms(to: $0) }
  }

  private static let legacyPasteboardTagClass = UTTagClass(rawValue: "com.apple.nspboard-type")
  private static let osTypeTagClass = UTTagClass(rawValue: "com.apple.ostype")
  private static let carbonFlavorPrefix = "CorePasteboardFlavorType 0x"

  /// UTI của một loại pasteboard, kể cả những tên KHÔNG phải UTI mà app đời cũ
  /// (Office là điển hình) vẫn ghi song song: tên pboard NeXT/Cocoa ("NeXT TIFF
  /// v4.0 pasteboard type", "Apple PDF pasteboard type"…), dạng `dyn.*` mã hoá
  /// chúng, và flavor Carbon ("CorePasteboardFlavorType 0x54494646" = 'TIFF').
  /// Không nhận ra chúng thì bản TIFF/PDF đi kèm lọt qua bộ lọc bản dựng.
  static func resolvedUTType(_ type: NSPasteboard.PasteboardType) -> UTType? {
    let raw = type.rawValue
    let direct = UTType(raw)
    if let direct, direct.isDeclared { return direct }
    if raw.hasPrefix(carbonFlavorPrefix),
       let code = UInt32(raw.dropFirst(carbonFlavorPrefix.count), radix: 16) {
      let bytes = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }
      if let osType = String(bytes: bytes, encoding: .macOSRoman),
         let uti = UTType(tag: osType, tagClass: osTypeTagClass, conformingTo: nil),
         uti.isDeclared {
        return uti
      }
    }
    // `dyn.*` giữ tên pboard gốc trong tags; tên thô thì tra thẳng.
    let legacyName = direct?.tags[legacyPasteboardTagClass]?.first ?? raw
    if let uti = UTType(tag: legacyName, tagClass: legacyPasteboardTagClass, conformingTo: nil),
       uti.isDeclared {
      return uti
    }
    return direct
  }

  static func snapshotItems(_ items: [NSPasteboardItem], allowFiles: Bool) -> [NSPasteboardItem] {
    items.compactMap { item in
      let copy = NSPasteboardItem()
      var wrote = false
      for type in capturedTypes(of: item, allowFiles: allowFiles) {
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

  /// Tổng byte của những loại `capturedTypes` sẽ chép trong `items`.
  static func payloadBytes(of items: [NSPasteboardItem], allowFiles: Bool) -> Int {
    items.reduce(0) { total, item in
      total + capturedTypes(of: item, allowFiles: allowFiles).reduce(0) { sum, type in
        if let data = item.data(forType: type) {
          return sum + data.count
        }
        if let string = item.string(forType: type) {
          return sum + string.utf8.count
        }
        return sum
      }
    }
  }

  static func filePayloadBytes(from urls: [URL]) -> Int {
    urls.reduce(0) { sum, url in
      let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
      return sum + fileSize
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

  // MARK: - Size limits & warnings

  static func maxEntryBytesFromSettings() -> Int {
    let mb = max(1, min(200, Defaults[.clipboardHistoryMaxEntryMegabytes]))
    return mb * 1024 * 1024
  }

  private func showOversizedWarning(actualBytes: Int, maxBytes: Int) {
    let now = Date()
    if let last = lastOversizedWarningAt,
       now.timeIntervalSince(last) < oversizedWarningDebounce {
      return
    }
    lastOversizedWarningAt = now
    let actual = Self.formatMegabytes(actualBytes)
    let limit = Self.formatMegabytes(maxBytes)
    let message = """
    Nội dung \(actual) vượt giới hạn \(limit). \
    Không lưu vào lịch sử — sao chép và dán vẫn như macOS.
    """
    NoticeHUDWindow.shared.show(message: message, title: "Nội dung clipboard quá lớn")
  }

  static func formatMegabytes(_ bytes: Int) -> String {
    let mb = Double(bytes) / (1024 * 1024)
    if mb >= 100 { return String(format: "%.0f MB", mb) }
    if mb >= 10 { return String(format: "%.0f MB", mb) }
    return String(format: "%.1f MB", mb)
  }
}
