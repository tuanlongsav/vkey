//
//  AXDirectInjector.swift
//  vkey
//
//  Ghi trực tiếp giá trị ô nhập qua Accessibility API cho Spotlight,
//  SystemUIServer và thanh địa chỉ trình duyệt (omnibox Chromium).
//

import AppKit
import ApplicationServices
import Foundation
import os.log

private let axLog = OSLog(subsystem: "dev.longht.vkey", category: "AXDirect")

enum AXDirectInjector {

  /// Lấy phần tử đang focus nếu nó thuộc một tiến trình overlay đã biết
  /// (Spotlight / SystemUIServer / Dock). Dùng chung cho `focusedOverlayBundle`
  /// và `overlaySearchIsFocused`.
  private static func focusedOverlayElement(
    timeout: Float = Focused.hotPathAXTimeout
  ) -> (element: AXUIElement, bundleId: String)? {
    guard let el = Focused.focusedElement(timeout: timeout) else { return nil }
    AXUIElementSetMessagingTimeout(el, timeout)
    guard let bundle = el.bundleIdentifier(),
      AppCompatibilityRegistry.isOverlayBundle(bundle)
    else { return nil }
    return (el, bundle)
  }

  /// v4.11: bundle của overlay ĐANG thực-focus qua systemwide AX, hoặc nil.
  static func focusedOverlayBundle() -> String? {
    focusedOverlayElement()?.bundleId
  }

  /// True khi focused element là ô text/search ghi được thuộc overlay (Spotlight…).
  static func overlaySearchIsFocused() -> Bool {
    guard let (el, _) = focusedOverlayElement() else { return false }
    return AXHelpers.isEditableTextElement(el, timeout: Focused.hotPathAXTimeout)
  }

  /// Lấy focused element để ghi AX (chạy trên `simulationQueue`, dùng mặc định
  /// `Focused.defaultAXTimeout`):
  /// 1. system-wide (nhanh nhất),
  /// 2. app-element của `targetPID` (chụp đồng bộ lúc vào `sendReplacement`),
  /// 3. duyệt overlay đã biết (Spotlight / SystemUIServer / Dock).
  static func axFocusedElement(targetPID: pid_t) -> AXUIElement? {
    let systemWide = AXUIElementCreateSystemWide()
    var focusedRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(
      systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
      let ref = focusedRef, CFGetTypeID(ref) == AXUIElementGetTypeID()
    {
      return (ref as! AXUIElement)
    }

    if targetPID > 0,
      let el = AXHelpers.focusedElement(ofPID: targetPID),
      AXHelpers.isEditableTextElement(el)
    {
      os_log("axDirect: focus via target pid=%d", log: axLog, type: .info, targetPID)
      return el
    }

    for bundleId in AppCompatibilityRegistry.overlayBundleIds {
      for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleId) {
        let pid = app.processIdentifier
        if let el = AXHelpers.focusedElement(ofPID: pid),
          AXHelpers.isEditableTextElement(el)
        {
          os_log(
            "axDirect: focus via overlay %{public}@ pid=%d",
            log: axLog, type: .info, bundleId, pid)
          return el
        }
      }
    }
    return nil
  }

  /// Ghi thẳng giá trị ô text qua Accessibility API: xoá `backspaceCount` đơn vị
  /// trước caret (theo đúng trục `usesNFC`) rồi chèn `insert` (precomposed NFC).
  static func axDirectReplace(
    backspaceCount: Int, insert: String, usesNFC: Bool, targetPID: pid_t
  ) -> Bool {
    guard let element = axFocusedElement(targetPID: targetPID) else {
      os_log(
        "axDirect: no focused element (systemwide + app pid both nil)",
        log: axLog, type: .default)
      return false
    }

    var valueRef: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success
    else {
      os_log("axDirect: AXValue unreadable", log: axLog, type: .default)
      return false
    }
    let valueStr = (valueRef as? String) ?? ""
    let valueNS = valueStr as NSString
    let valueLength = valueNS.length

    var caret = valueLength
    var selLen = 0
    if let sel = element.selectedTextRange(), sel.location >= 0 {
      caret = min(sel.location, valueLength)
      selLen = max(0, sel.length)
    }

    var start = caret
    var len = 0
    let selectionAtEnd = selLen > 0 && (caret + selLen == valueLength)
    if selLen > 0 && !selectionAtEnd {
      start = caret
      len = selLen
    } else {
      let deleteStart = TextDiff.axDeleteStart(
        valueStr, caretUTF16: caret, backspaceCount: backspaceCount, usesNFC: usesNFC)
      start = deleteStart
      len = (caret - deleteStart) + (selectionAtEnd ? selLen : 0)
    }
    if start + len > valueLength { len = valueLength - start }
    if len < 0 { len = 0 }

    let insertNFC = insert.precomposedStringWithCanonicalMapping
    let newValue = valueNS.replacingCharacters(
      in: NSRange(location: start, length: len), with: insertNFC)

    guard
      AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFTypeRef)
        == .success
    else {
      os_log("axDirect: AXValue write REFUSED", log: axLog, type: .default)
      return false
    }

    let targetCaret = start + (insertNFC as NSString).length
    let written = axReadValueAndSelection(element)
    if axShouldPlaceCaret(
      selectionAfterWrite: written.selection, targetCaret: targetCaret,
      valueLength: ((written.value ?? newValue) as NSString).length)
    {
      var newSel = CFRange(location: targetCaret, length: 0)
      if let newRange = AXValueCreate(.cfRange, &newSel) {
        AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, newRange)
      }
    }

    guard backspaceCount > 0 else { return true }
    var got = written.value
    for attempt in 0..<2 {
      if attempt > 0 {
        usleep(2000)
        got = axReadValueAndSelection(element).value
      }
      if let got, axWriteLanded(
        oldValue: valueStr, wanted: newValue, got: got, hadSuffixSelection: selectionAtEnd)
      {
        return true
      }
    }
    os_log("axDirect: verify FAILED (write not applied)", log: axLog, type: .default)
    return false
  }

  /// Đọc AXValue và AXSelectedTextRange của ô vừa ghi.
  private static func axReadValueAndSelection(
    _ element: AXUIElement
  ) -> (value: String?, selection: CFRange?) {
    var valueRef: CFTypeRef?
    let value = AXUIElementCopyAttributeValue(
      element, kAXValueAttribute as CFString, &valueRef) == .success
      ? (valueRef as? String) : nil
    return (value, element.selectedTextRange())
  }

  /// Có cần đặt lại con trỏ sau khi ghi AXValue không.
  static func axShouldPlaceCaret(
    selectionAfterWrite: CFRange?, targetCaret: Int, valueLength: Int
  ) -> Bool {
    guard let sel = selectionAfterWrite, sel.location == targetCaret else { return true }
    let isSuggestionTail = sel.location + sel.length == valueLength
    return !(sel.length == 0 || isSuggestionTail)
  }

  /// Lần ghi AXValue đã tới field chưa (so sau chuẩn hoá NFC).
  static func axWriteLanded(
    oldValue: String, wanted: String, got: String, hadSuffixSelection: Bool
  ) -> Bool {
    let gotNFC = got.precomposedStringWithCanonicalMapping
    let wantNFC = wanted.precomposedStringWithCanonicalMapping
    if gotNFC == wantNFC { return true }
    if hadSuffixSelection && gotNFC.hasPrefix(wantNFC) { return true }
    return gotNFC != oldValue.precomposedStringWithCanonicalMapping
  }
}
