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
