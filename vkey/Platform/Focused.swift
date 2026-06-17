//
//  Focused.swift
//
//

import AppKit
import ApplicationServices
import Foundation

public struct Focused {
  /// 1.9.0: timeout cho AX queries (giây). Gọi 1 lần lúc app launch để
  /// áp dụng global. Tránh AX call block quá lâu khi target app không
  /// responsive (vd app hang) → giảm risk macOS disable event tap.
  /// Áp dụng cho system-wide element nên cover tất cả AX query subsequent.
  public static func setupAXTimeout(_ timeoutSeconds: Float = 0.1) {
    let systemWide = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(systemWide, timeoutSeconds)
  }

  public static func focusedAppBundleId() -> String? {
    guard let focusedElement = Focused.element() else { return nil }
    var pid: pid_t = 0
    if AXUIElementGetPid(focusedElement, &pid) == .success {
      if let app = NSRunningApplication(processIdentifier: pid) {
        return app.bundleIdentifier
      }
    }
    return nil
  }

  public static func element() -> AXUIElement? {
    let systemWideElement = AXUIElementCreateSystemWide()
    return systemWideElement.getAttribute(property: kAXFocusedUIElementAttribute)
  }

  public static func elementText() -> String? {
    guard let focusedElement = Focused.element() else { return nil }
    guard let text: String = focusedElement.getAttribute(property: kAXValueAttribute)
    else { return nil }
    return text
  }

  public static func hasHighlightedText() -> Bool {
    guard let focusedElement = Focused.element() else { return false }

    // Method 1: Check selected text content directly
    if let highlightedText: String = focusedElement.getAttribute(
      property: kAXSelectedTextAttribute)
    {
      if !highlightedText.isEmpty {
        return true
      }
    }

    // Method 2: Check selected text range length (fallback)
    // Some apps (e.g., Chrome's address bar) don't expose kAXSelectedTextAttribute
    // but do expose kAXSelectedTextRangeAttribute with a valid CFRange.
    if let rangeValue: AXValue = focusedElement.getAttribute(
      property: kAXSelectedTextRangeAttribute)
    {
      var range = CFRange(location: 0, length: 0)
      if AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0 {
        #if DEBUG
          print(
            "[vkey] hasHighlightedText: detected via selectedTextRange (location=\(range.location), length=\(range.length))"
          )
        #endif
        return true
      }
    }

    return false
  }

  public static func highlightedText() -> String? {
    guard let focusedElement = Focused.element() else { return nil }
    guard let highlightedText: String = focusedElement.getAttribute(
      property: kAXSelectedTextAttribute)
    else { return nil }
    guard !highlightedText.isEmpty else { return nil }
    return highlightedText
  }

  public static func isComboBoxOrSearchField() -> Bool {
    guard let focusedElement = Focused.element() else { return false }
    if let role: String = focusedElement.getAttribute(property: kAXRoleAttribute) {
      return role == "AXComboBox" || role == "AXSearchField"
    }
    return false
  }

  /// v3.9: phân loại ngữ cảnh của focused element (leo cây AX) để caller quyết
  /// định kiểu diff (NFC/NFD) và chiến lược gửi (synthetic vs axDirect).
  public enum FieldKind {
    /// Dưới `AXWebArea` — web content Chromium/Electron: lưu/xoá theo scalar
    /// → diff NFD synthetic.
    case webContent
    /// Trong hộp thoại modal native (`AXSheet` / cửa sổ subrole dialog) — vd
    /// `NSSavePanel`/`NSOpenPanel`: AppKit thật → diff NFC synthetic.
    case nativePanel
    /// Field thường trong cửa sổ chính (KHÔNG web area, KHÔNG dialog). Với app
    /// native = ô text bình thường; với app nhóm NFD (Chromium) đây là
    /// browser-chrome — vd THANH ĐỊA CHỈ (omnibox): field Chromium Views có
    /// inline autocomplete bôi đen → caller dùng diff NFC + chiến lược axDirect.
    case windowField
    /// Không xác định được (AX timeout / đứt chain / chạm trần) — giữ mặc định
    /// theo app.
    case unknown
  }

  public static func fieldKind() -> FieldKind {
    guard let focusedElement = Focused.element() else { return .unknown }
    return fieldKind(from: focusedElement)
  }

  /// Core leo cây AX từ `element` — tách ra để `snapshot()` tái dùng.
  /// Thứ tự kiểm tra QUAN TRỌNG: `AXWebArea` luôn là con của cửa sổ nên gặp
  /// TRƯỚC `AXWindow` → web content phân loại đúng trước khi chạm window.
  private static func fieldKind(from element: AXUIElement) -> FieldKind {
    var current: AXUIElement? = element
    var depth = 0
    // Trần 25 cấp: vòng lặp luôn có cận trên để không treo trên cây bệnh/đệ quy.
    while let el = current, depth < 25 {
      guard let role: String = el.getAttribute(property: kAXRoleAttribute) else {
        // Role không đọc được (AX timeout/lỗi) → không kết luận.
        return .unknown
      }
      if role == "AXWebArea" { return .webContent }
      if role == "AXSheet" { return .nativePanel }
      if role == "AXWindow" {
        let subrole: String? = el.getAttribute(property: kAXSubroleAttribute)
        if subrole == "AXDialog" || subrole == "AXSystemDialog" { return .nativePanel }
        return .windowField
      }
      if role == "AXApplication" { return .windowField }
      current = el.getAttribute(property: kAXParentAttribute)
      depth += 1
    }
    return .unknown
  }

  /// v3.7: ảnh chụp trạng thái focused element trong MỘT lần fetch system-wide.
  /// Trước đây `performFocusedElementRefresh` gọi 3 hàm riêng, mỗi hàm tự
  /// `Focused.element()` → 3 round-trip AX. Gộp còn 1 fetch + 1 lần leo cây.
  public struct FocusSnapshot {
    public let bundleId: String?
    public let isComboOrSearch: Bool
    public let fieldKind: FieldKind
  }

  public static func snapshot() -> FocusSnapshot {
    guard let element = Focused.element() else {
      return FocusSnapshot(bundleId: nil, isComboOrSearch: false, fieldKind: .unknown)
    }
    var bundleId: String? = nil
    var pid: pid_t = 0
    if AXUIElementGetPid(element, &pid) == .success {
      bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }
    let role: String? = element.getAttribute(property: kAXRoleAttribute)
    let isComboOrSearch = (role == "AXComboBox" || role == "AXSearchField")
    let kind = Focused.fieldKind(from: element)
    return FocusSnapshot(
      bundleId: bundleId, isComboOrSearch: isComboOrSearch, fieldKind: kind)
  }

  /// Whether the currently focused UI element (in the frontmost app) is a
  /// secure/password text field. Used to decide whether system-wide secure
  /// input actually belongs to the foreground app — `CGSIsSecureEventInputSet`
  /// is global and stays on while a *background* app holds a focused password
  /// field, which would otherwise keep vkey stuck in private mode after the
  /// user switches away.
  ///
  /// Returns `false` when AX can't resolve the focused element. Callers should
  /// treat that as "front app owns it" only when the front app is already the
  /// known secure-input owner (e.g. Terminal sudo, which exposes no secure
  /// subrole) — see `EventHook`.
  public static func isSecureField() -> Bool {
    guard let focusedElement = Focused.element() else { return false }
    if let subrole: String = focusedElement.getAttribute(property: kAXSubroleAttribute) {
      return subrole == (kAXSecureTextFieldSubrole as String)
    }
    return false
  }
}

extension AXUIElement {
  public func getAttribute<T>(property: String) -> T? {
    var ptr: AnyObject?
    if AXUIElementCopyAttributeValue(self, property as CFString, &ptr) != AXError.success {
      return nil
    }
    return ptr as? T
  }
}
