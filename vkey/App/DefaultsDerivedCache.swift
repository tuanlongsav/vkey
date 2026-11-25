//
//  DefaultsDerivedCache.swift
//  vkey
//
//  Thread-safe derived cache invalidated synchronously via UserDefaults KVO
//  when any of its source Defaults keys change.
//

import Defaults
import Foundation
import os

/// Giá trị dựng từ một hay nhiều key `Defaults`, dựng lần đầu khi đọc rồi giữ
/// lại cho tới khi một key nguồn đổi (tránh giải mã JSON lặp trên hot path).
final class DefaultsDerivedCache<Value: Sendable>: @unchecked Sendable {
  private struct State {
    var generation = 0
    var value: Value?
  }

  private let state = OSAllocatedUnfairLock(initialState: State())
  private let compute: () -> Value
  private var observations: [Defaults.Observation] = []

  init(_ keys: Defaults._AnyKey..., compute: @escaping () -> Value) {
    self.compute = compute
    observations = keys.map { key in
      Defaults.observe(keys: key, options: []) { [weak self] in
        self?.invalidate()
      }
    }
  }

  var value: Value {
    let (generation, cached) = state.withLock { ($0.generation, $0.value) }
    if let cached { return cached }
    let fresh = compute()
    state.withLock {
      if $0.generation == generation { $0.value = fresh }
    }
    return fresh
  }

  func invalidate() {
    state.withLock {
      $0.generation += 1
      $0.value = nil
    }
  }
}
