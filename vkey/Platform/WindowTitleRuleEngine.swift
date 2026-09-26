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
struct ResolvedRuleOverrides: Equatable {
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
  private var cachedRules: CompiledRules?

  /// Rule đang bật + regex tiêu đề đã biên dịch, dựng lại khi danh sách đổi.
  /// Trước đây mỗi lần cache (bundleId, title) trượt là giải mã lại toàn bộ
  /// `Defaults[.windowTitleRules]` và biên dịch lại `NSRegularExpression` của
  /// từng rule. Bất biến sau khi dựng nên đọc được từ mọi thread.
  private final class CompiledRules: @unchecked Sendable {
    let entries: [(rule: WindowTitleRule, regex: NSRegularExpression?)]

    init(_ rules: [WindowTitleRule]) {
      entries = rules.filter { $0.enabled }.map { rule in
        let regex = rule.titleRegex.isEmpty
          ? nil
          : try? NSRegularExpression(pattern: rule.titleRegex, options: [.caseInsensitive])
        return (rule, regex)
      }
    }
  }

  private let compiledRules = DefaultsDerivedCache<CompiledRules>(.windowTitleRules) {
    CompiledRules(Defaults[.windowTitleRules])
  }

  private init() {}

  /// Đánh giá rules cho `bundleId` + current focused window title.
  /// Cache kết quả theo (bundleId, title) — invalidate khi state đổi.
  func evaluate(bundleId: String) -> ResolvedRuleOverrides {
    let compiled = compiledRules.value
    // Không có rule nào bật (mặc định) thì kết quả luôn rỗng — khỏi hỏi AX
    // tiêu đề cửa sổ (frontmostApplication + 2 message AX) ở mỗi lần đổi app
    // / refresh focus.
    guard !compiled.entries.isEmpty else { return .init() }
    let title = focusedWindowTitle() ?? ""
    // `cachedRules === compiled`: danh sách rule đổi thì kết quả cũ hết hiệu lực
    // dù (bundleId, title) trùng.
    if cachedRules === compiled && cachedBundleId == bundleId && cachedTitle == title {
      return cachedResult
    }
    cachedRules = compiled
    cachedBundleId = bundleId
    cachedTitle = title
    let resolved = computeOverrides(bundleId: bundleId, title: title, rules: compiled.entries)
    cachedResult = resolved
    return resolved
  }

  func invalidateCache() {
    cachedRules = nil
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

  private func computeOverrides(
    bundleId: String,
    title: String,
    rules: [(rule: WindowTitleRule, regex: NSRegularExpression?)]
  ) -> ResolvedRuleOverrides {
    var result = ResolvedRuleOverrides()

    for (rule, regex) in rules {
      // Match bundle ID nếu có prefix.
      if !rule.bundleIdPrefix.isEmpty {
        if !bundleId.lowercased().hasPrefix(rule.bundleIdPrefix.lowercased()) {
          continue
        }
      }
      // Match title regex nếu có (regex sai cú pháp ⇒ `nil` ⇒ rule không khớp).
      if !rule.titleRegex.isEmpty {
        guard let regex, Self.matches(regex, title: title) else { continue }
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

  private static func matches(_ regex: NSRegularExpression, title: String) -> Bool {
    let range = NSRange(title.startIndex..<title.endIndex, in: title)
    return regex.firstMatch(in: title, options: [], range: range) != nil
  }
}
