//
//  FocusContextTracker.swift
//  vkey
//
//  Theo dõi bundle ID và loại ô đang focus (đồng bộ trên đường gõ phím +
//  làm mới bất đồng bộ gộp nhịp kèm nhịp trễ 0,5s cho hộp thoại native).
//

import Foundation
import os

final class FocusContextTracker {

  /// Cached bundle ID của ô đang focus.
  private(set) var currentFocusedBundleId: String?

  /// Phân loại field đang focus (`webContent`, `nativePanel`, `windowField`, `unknown`).
  private(set) var currentFocusedFieldKind: Focused.FieldKind = .unknown {
    didSet {
      onFieldKindChange?(currentFocusedFieldKind)
    }
  }

  /// Gọi mỗi khi `currentFocusedFieldKind` thay đổi (đẩy sang `InputProcessor`).
  var onFieldKindChange: ((Focused.FieldKind) -> Void)?

  private let refreshQueue = DispatchQueue(
    label: "dev.longht.vkey.focusRefresh", qos: .userInteractive,
    autoreleaseFrequency: .workItem
  )
  private var pendingDelayedRefresh: DispatchWorkItem?
  private let immediateRefreshQueued = OSAllocatedUnfairLock(initialState: false)

  func noteFocusedBundleId(_ bid: String) {
    currentFocusedBundleId = bid
  }

  /// Snapshot AX đồng bộ ngay trước transform (chạy trên tap thread với `hotPathAXTimeout`).
  func syncForKeystroke() {
    let snap = Focused.snapshot()
    if let bid = snap.bundleId {
      currentFocusedBundleId = bid
    }
    currentFocusedFieldKind = snap.fieldKind
  }

  /// Làm mới bất đồng bộ (gộp nhịp ngay + nhịp trễ 0,5s bắt hộp thoại Save/Open panel).
  func refreshAsync() {
    let alreadyQueued = immediateRefreshQueued.withLock { queued -> Bool in
      defer { queued = true }
      return queued
    }
    if !alreadyQueued {
      refreshQueue.async { [weak self] in
        self?.immediateRefreshQueued.withLock { $0 = false }
        self?.performRefresh()
      }
    }

    pendingDelayedRefresh?.cancel()
    let delayed = DispatchWorkItem { [weak self] in
      self?.performRefresh()
    }
    pendingDelayedRefresh = delayed
    refreshQueue.asyncAfter(deadline: .now() + 0.5, execute: delayed)
  }

  private func performRefresh() {
    // Chạy trên queue nền (ngoài tap thread) → dùng ngân sách nền `defaultAXTimeout` (0,1s).
    let snap = Focused.snapshot(timeout: Focused.defaultAXTimeout)
    DispatchQueue.main.async {
      self.currentFocusedBundleId = snap.bundleId
      self.currentFocusedFieldKind = snap.fieldKind
    }
  }
}
