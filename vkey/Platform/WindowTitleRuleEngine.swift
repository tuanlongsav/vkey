//
//  WindowTitleRuleEngine.swift
//  vkey
//
//  2.0 (B1): Đánh giá `WindowTitleRule[]` cho context hiện tại
//  (bundle ID + window title) và trả về resolved overrides.
//
//  Cấu trúc 1 rule: bundleIdPrefix + titleRegex (cả 2 đều optional).
//  Match cho rule: bundleIdPrefix prefix-match (case-insensitive) AND
//  titleRegex matches. Rule đầu tiên thắng (ordering quan trọng).
//

import AppKit
import ApplicationServices
import Defaults
import Foundation

/// Resolved overrides cho 1 context hiện tại. Default (no rule match) là
/// `init()` — không override gì.
struct ResolvedRuleOverrides {
  var disablePrediction = false
  var disableSpellCheck = false
  var flushDelayMs = 0
  var overrideState: AppSmartSwitchState? = nil
}

final class WindowTitleRuleEngine {
  // Singleton — không cần @MainActor vì các ops chỉ đọc Defaults + AX
  // (cả 2 thread-safe). AppState gọi từ activeApplicationDidChange (main),
  // EventHook callback có thể gọi từ event-tap thread.
  static let shared = WindowTitleRuleEngine()

  private var cachedBundleId: String?
  private var cachedTitle: String?
  private var cachedResult: ResolvedRuleOverrides = .init()

  private init() {}

  /// Đánh giá rules cho `bundleId` + current focused window title.
  /// Cache kết quả theo (bundleId, title) — invalidate khi state đổi.
  func evaluate(bundleId: String) -> ResolvedRuleOverrides {
    let title = focusedWindowTitle() ?? ""
    if cachedBundleId == bundleId && cachedTitle == title {
      return cachedResult
    }
    cachedBundleId = bundleId
    cachedTitle = title
    let resolved = computeOverrides(bundleId: bundleId, title: title)
    cachedResult = resolved
    return resolved
  }

  func invalidateCache() {
    cachedBundleId = nil
    cachedTitle = nil
    cachedResult = .init()
  }

  // MARK: - Internal

  /// Lấy title của focused window. Trả về nil nếu không xác định.
  private func focusedWindowTitle() -> String? {
    // 1. Lấy focused window từ frontmost app.
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var windowRef: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(
      axApp,
      kAXFocusedWindowAttribute as CFString,
      &windowRef
    )
    guard err == .success, let window = windowRef else { return nil }
    let axWindow = window as! AXUIElement

    var titleRef: CFTypeRef?
    let titleErr = AXUIElementCopyAttributeValue(
      axWindow,
      kAXTitleAttribute as CFString,
      &titleRef
    )
    guard titleErr == .success, let title = titleRef as? String else { return nil }
    return title
  }

  private func computeOverrides(bundleId: String, title: String) -> ResolvedRuleOverrides {
    let rules = Defaults[.windowTitleRules].filter { $0.enabled }
    var result = ResolvedRuleOverrides()

    for rule in rules {
      // Match bundle ID nếu có prefix.
      if !rule.bundleIdPrefix.isEmpty {
        if !bundleId.lowercased().hasPrefix(rule.bundleIdPrefix.lowercased()) {
          continue
        }
      }
      // Match title regex nếu có.
      if !rule.titleRegex.isEmpty {
        guard matchesRegex(title: title, pattern: rule.titleRegex) else { continue }
      }
      // Match → apply.
      if rule.disablePrediction { result.disablePrediction = true }
      if rule.disableSpellCheck { result.disableSpellCheck = true }
      if rule.flushDelayMs > 0 { result.flushDelayMs = max(result.flushDelayMs, rule.flushDelayMs) }
      if let state = rule.overrideState {
        result.overrideState = state
      }
      // First match wins for `overrideState`; flags accumulate.
      if result.overrideState != nil {
        break
      }
    }

    return result
  }

  private func matchesRegex(title: String, pattern: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return false
    }
    let range = NSRange(title.startIndex..<title.endIndex, in: title)
    return regex.firstMatch(in: title, options: [], range: range) != nil
  }
}
