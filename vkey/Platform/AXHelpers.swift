//
//  AXHelpers.swift
//  vkey
//
//  Tiện ích Accessibility API dùng chung giữa `Focused` và `AXDirectInjector`.
//

import AppKit
import ApplicationServices
import Foundation

enum AXHelpers {
  /// Role của các ô nhập chữ chuẩn (dùng chung cho `Focused.plainTextRoles` và
  /// kiểm tra ô text có thể ghi ở `AXDirectInjector`).
  static let editableTextRoles: Set<String> = [
    "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField",
  ]

  /// Element focus đọc qua app-element của 1 PID (element-scope timeout,
  /// không đụng mặc định toàn tiến trình).
  static func focusedElement(
    ofPID pid: pid_t, timeout: Float = Focused.defaultAXTimeout
  ) -> AXUIElement? {
    guard pid > 0 else { return nil }
    let appEl = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(appEl, timeout)
    var ref: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &ref)
        == .success,
      let r = ref, CFGetTypeID(r) == AXUIElementGetTypeID()
    else { return nil }
    return (r as! AXUIElement)
  }

  /// True nếu element là ô text/search chuẩn và `AXValue` cho phép ghi.
  static func isEditableTextElement(
    _ el: AXUIElement, timeout: Float = Focused.defaultAXTimeout
  ) -> Bool {
    AXUIElementSetMessagingTimeout(el, timeout)
    guard let role: String = el.getAttribute(property: kAXRoleAttribute),
      editableTextRoles.contains(role)
    else { return false }
    var settable: DarwinBoolean = false
    AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable)
    return settable.boolValue
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

  /// Đọc `kAXSelectedTextRangeAttribute` dưới dạng `CFRange`.
  func selectedTextRange() -> CFRange? {
    var rangeRef: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        self, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
      let rv = rangeRef, CFGetTypeID(rv) == AXValueGetTypeID()
    else { return nil }
    var sel = CFRange()
    return AXValueGetValue(rv as! AXValue, .cfRange, &sel) ? sel : nil
  }

  /// PID của tiến trình sở hữu element này.
  func processID() -> pid_t? {
    var pid: pid_t = 0
    guard AXUIElementGetPid(self, &pid) == .success, pid > 0 else { return nil }
    return pid
  }

  /// Bundle ID của tiến trình sở hữu element này (nếu có).
  func bundleIdentifier() -> String? {
    guard let pid = processID() else { return nil }
    return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
  }
}
