//
//  InputSourceMonitor.swift
//  vkey
//
//  2.0 (B2): Theo dõi sự thay đổi keyboard input source. Khi user chuyển
//  sang non-Latin IME (Japanese / Chinese / Korean / Arabic / Thai …),
//  vkey tự động disable để tránh xung đột — bộ gõ Vietnamese không có
//  ý nghĩa khi target app đang ở chế độ IME khác.
//
//  Khi user quay về Latin input source (US English, Dvorak, French, etc.),
//  AppState restore state trước đó qua Smart Switch.
//

import AppKit
import Carbon
import Foundation
import os.log

private let isLog = OSLog(subsystem: "dev.longht.vkey", category: "InputSource")

/// Phân loại input source theo language để quyết định có disable vkey không.
enum InputSourceCategory {
  case latin       // US English, French, German, Vietnamese keyboard … — OK với vkey
  case nonLatin    // Japanese, Chinese, Korean, Arabic, Thai, Hebrew … — disable
  case unknown     // không xác định — không disable (an toàn)
}

final class InputSourceMonitor {

  /// Callback khi input source đổi. Tham số: category mới (Latin/nonLatin/unknown).
  /// Gọi trên main thread.
  var onInputSourceChange: ((InputSourceCategory) -> Void)?

  private var observer: NSObjectProtocol?

  init() {}

  deinit {
    stop()
  }

  func start() {
    guard observer == nil else { return }

    // Notification từ Text Input Source manager khi user đổi input source
    // (vd qua menu bar globe icon hoặc ⌃Space). Dùng
    // DistributedNotificationCenter vì notification được post cross-process.
    let center = DistributedNotificationCenter.default()
    observer = center.addObserver(
      forName: kTISNotifySelectedKeyboardInputSourceChanged as NSNotification.Name,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleInputSourceChange()
    }

    // Fire một lần ngay sau khi start để sync state hiện tại với UI/AppState.
    DispatchQueue.main.async { [weak self] in
      self?.handleInputSourceChange()
    }
  }

  func stop() {
    if let observer = observer {
      DistributedNotificationCenter.default().removeObserver(observer)
      self.observer = nil
    }
  }

  /// Lấy category của input source hiện tại. Public để AppState gọi
  /// trong init mà không phải đợi notification.
  static func currentCategory() -> InputSourceCategory {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
      return .unknown
    }
    return classify(source: source)
  }

  private func handleInputSourceChange() {
    let category = Self.currentCategory()
    onInputSourceChange?(category)
  }

  /// Phân loại một TISInputSource. Logic:
  /// 1. Nếu category là `kTISCategoryKeyboardInputSource` và type là
  ///    `kTISTypeKeyboardLayout` → đơn thuần keyboard layout → Latin.
  /// 2. Nếu type là `kTISTypeKeyboardInputMode` hoặc category là
  ///    `kTISCategoryKeyboardInputMode` → IME mode → check language.
  /// 3. Đọc primary language từ `kTISPropertyInputSourceLanguages`. Nếu nằm
  ///    trong allow-list Latin → Latin; ngược lại → nonLatin.
  private static func classify(source: TISInputSource) -> InputSourceCategory {
    // Lấy primary language ID (ISO 639). Nếu lấy được → trust language.
    if let languages = property(source, kTISPropertyInputSourceLanguages) as? [String],
       let primary = languages.first {
      return classify(languageCode: primary)
    }

    // Fallback: check type. Keyboard layout đơn thuần thường là Latin.
    if let type = property(source, kTISPropertyInputSourceType) as? String {
      let layoutTypes: Set<String> = [
        kTISTypeKeyboardLayout as String,
      ]
      if layoutTypes.contains(type) {
        return .latin
      }
      // Mọi loại IME khác coi như non-Latin (an toàn — disable vkey).
      return .nonLatin
    }

    return .unknown
  }

  private static func classify(languageCode: String) -> InputSourceCategory {
    // Lấy primary subtag (vd "en-US" → "en", "zh-Hans" → "zh").
    let primary = languageCode
      .split(separator: "-")
      .first
      .map(String.init)?
      .lowercased() ?? languageCode.lowercased()

    // Latin-script languages — input methods cho các ngôn ngữ này tương thích
    // với cách vkey hoạt động (intercept US keyboard layout).
    let latinScriptCodes: Set<String> = [
      "en", "vi", "fr", "de", "es", "it", "pt", "nl",
      "sv", "no", "da", "fi", "is", "pl", "cs", "sk",
      "hu", "ro", "hr", "sl", "et", "lv", "lt", "tr",
      "id", "ms", "tl", "sw", "ca", "gl", "eu", "cy",
      "ga", "mt", "sq", "af",
    ]
    if latinScriptCodes.contains(primary) {
      return .latin
    }

    // Non-Latin scripts — disable vkey để tránh xung đột với IME.
    let nonLatinCodes: Set<String> = [
      "ja", "zh", "ko", "th", "ar", "he", "fa", "ur",
      "hi", "bn", "ta", "te", "kn", "ml", "gu", "pa",
      "or", "as", "si", "lo", "km", "my", "el", "ru",
      "uk", "bg", "sr", "mk", "be", "ka", "hy", "am",
      "iw", "yi",
    ]
    if nonLatinCodes.contains(primary) {
      return .nonLatin
    }

    return .unknown
  }

  private static func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
    guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
  }
}
