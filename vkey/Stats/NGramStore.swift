//
//  NGramStore.swift
//  vkey
//
//  1.7.x: Lưu bigram/trigram cho Word Prediction ngoài UserDefaults.
//
//  Vì sao tách: dict `[String: [String: Int]]` có thể lên vài MB sau
//  nhiều tháng gõ. `Defaults[.userBigrams] = ...` serialize plist
//  đồng bộ trên thread gọi (main) → mỗi commit từ block UI vài chục ms.
//
//  Cách giải: in-memory dict + background queue + throttled flush 10s
//  ra atomic JSON file ở `~/Library/Application Support/vkey/ngram/`.
//  Match pattern UsageStatistics.swift.
//
//  Migration: lần đầu init, nếu disk trống + Defaults[.userBigrams]
//  còn data → copy sang in-memory + flush ngay + xóa Defaults. Idempotent.
//

import Defaults
import Foundation
import os.log

private let ngramLog = OSLog(subsystem: "dev.longht.vkey", category: "NGramStore")

/// Snapshot serialize được ra disk. Tách thành struct riêng để hỗ trợ
/// versioning sau này (thêm `version`, `lastSeen` per entry…).
private struct NGramSnapshot: Codable {
  var bigrams: [String: [String: Int]] = [:]
  var trigrams: [String: [String: Int]] = [:]
}

final class NGramStore {
  static let shared = NGramStore()

  // Concurrent queue + barrier writes — match LexiconManager pattern để
  // cho phép nhiều reader đồng thời từ topPrediction (main thread).
  private let queue = DispatchQueue(label: "dev.longht.vkey.ngram", qos: .utility, attributes: .concurrent)

  private var bigrams: [String: [String: Int]] = [:]   // [prev1: [cur: count]]
  private var trigrams: [String: [String: Int]] = [:]  // ["prev2|prev1": [cur: count]]
  private var pendingFlushItem: DispatchWorkItem?

  /// Caps để bound disk + memory growth — không có TTL nên cap theo size.
  /// Mỗi prev key giữ top-50 next words theo count. Cap 5000 prev keys
  /// (bigram) / 10000 (trigram, có thể nhiều key hơn vì có prev2 thêm vào).
  private let maxNextsPerKey = 50
  private let maxBigramKeys = 5000
  private let maxTrigramKeys = 10000

  let storageDir: URL

  /// Test-only initializer. Production code dùng `.shared`.
  init(storageDir: URL? = nil) {
    let resolved: URL
    if let custom = storageDir {
      resolved = custom
    } else {
      let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
      resolved = (appSupport ?? URL(fileURLWithPath: "/tmp"))
        .appendingPathComponent("vkey/ngram", isDirectory: true)
    }
    try? FileManager.default.createDirectory(
      at: resolved, withIntermediateDirectories: true, attributes: nil
    )
    // Privacy: ngrams.json chứa cặp/bộ-ba từ người dùng đã gõ (plaintext) →
    // loại khỏi backup iCloud/Time Machine (L7).
    UsageStatistics.excludeFromBackup(resolved)
    self.storageDir = resolved
    loadFromDisk()
    migrateFromDefaultsIfNeeded()
  }

  // MARK: - Reads (hot path từ PredictionEngine.collectCandidates)

  /// Snapshot of next-word counts cho `prev1`. Returns nil-equivalent
  /// (empty dict) nếu không có data.
  func bigramNexts(prev1: String) -> [String: Int] {
    queue.sync { bigrams[prev1] ?? [:] }
  }

  /// Snapshot of next-word counts cho cặp `(prev2, prev1)`.
  func trigramNexts(prev2: String, prev1: String) -> [String: Int] {
    let key = "\(prev2)|\(prev1)"
    return queue.sync { trigrams[key] ?? [:] }
  }

  // MARK: - Writes (từ PredictionEngine.learnTransition)

  /// Học transition: tăng bigram[prev1][current] + (nếu có prev2)
  /// trigram["prev2|prev1"][current]. Async, không block caller.
  func learn(prev2: String?, prev1: String, current: String) {
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      var nexts = self.bigrams[prev1, default: [:]]
      nexts[current, default: 0] += 1
      self.bigrams[prev1] = nexts

      if let prev2 = prev2, !prev2.isEmpty {
        let key = "\(prev2)|\(prev1)"
        var trinexts = self.trigrams[key, default: [:]]
        trinexts[current, default: 0] += 1
        self.trigrams[key] = trinexts
      }
      self.scheduleFlush()
    }
  }

  /// 1.7.x: dùng cho UserDataMigration import/export — snapshot toàn bộ.
  func snapshot() -> (bigrams: [String: [String: Int]], trigrams: [String: [String: Int]]) {
    queue.sync { (bigrams, trigrams) }
  }

  /// 1.7.x: replace toàn bộ — dùng cho import (replaceLists mode).
  func replaceAll(bigrams: [String: [String: Int]], trigrams: [String: [String: Int]]) {
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      self.bigrams = bigrams
      self.trigrams = trigrams
      self.scheduleFlush()
    }
  }

  /// 1.7.x: merge (file wins per (prev, next) pair) — dùng cho import merge mode.
  /// Trả về số entry thực sự bị overwrite, để caller báo cho user.
  @discardableResult
  func merge(bigrams importBi: [String: [String: Int]], trigrams importTri: [String: [String: Int]]) -> (biChanged: Int, triChanged: Int) {
    return queue.sync(flags: .barrier) { [self] in
      var biChanged = 0
      for (prev, nextMap) in importBi {
        var existingNext = self.bigrams[prev] ?? [:]
        for (next, count) in nextMap where existingNext[next] != count {
          existingNext[next] = count
          biChanged += 1
        }
        self.bigrams[prev] = existingNext
      }
      var triChanged = 0
      for (prev, nextMap) in importTri {
        var existingNext = self.trigrams[prev] ?? [:]
        for (next, count) in nextMap where existingNext[next] != count {
          existingNext[next] = count
          triChanged += 1
        }
        self.trigrams[prev] = existingNext
      }
      if biChanged > 0 || triChanged > 0 { scheduleFlush() }
      return (biChanged, triChanged)
    }
  }

  // MARK: - Persistence

  private func scheduleFlush() {
    pendingFlushItem?.cancel()
    let item = DispatchWorkItem {}
    pendingFlushItem = item
    queue.asyncAfter(deadline: .now() + 10, flags: .barrier) { [weak self, item] in
      guard !item.isCancelled else { return }
      self?.flushNow()
    }
  }

  /// Public-equivalent — gọi từ app delegate khi terminate để đảm bảo
  /// data không mất nếu user gõ rồi quit ngay.
  func flushNowSync() {
    queue.sync(flags: .barrier) { [self] in flushNow() }
  }

  private func flushNow() {
    pruneIfNeeded()
    let snapshot = NGramSnapshot(bigrams: bigrams, trigrams: trigrams)
    let url = storageDir.appendingPathComponent("ngrams.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if let data = try? encoder.encode(snapshot) {
      do {
        try data.write(to: url, options: .atomic)
      } catch {
        os_log("NGramStore: flush failed — %{public}@",
               log: ngramLog, type: .error, error.localizedDescription)
      }
    }
  }

  private func loadFromDisk() {
    let url = storageDir.appendingPathComponent("ngrams.json")
    guard let data = try? Data(contentsOf: url),
          let snapshot = try? JSONDecoder().decode(NGramSnapshot.self, from: data) else {
      return
    }
    bigrams = snapshot.bigrams
    trigrams = snapshot.trigrams
  }

  /// Migration 1 lần: nếu disk trống NHƯNG Defaults có data → copy + clear.
  /// Idempotent — chạy lại sau khi đã clear Defaults sẽ thấy disk có data,
  /// skip Defaults.
  private func migrateFromDefaultsIfNeeded() {
    let onDiskEmpty = bigrams.isEmpty && trigrams.isEmpty
    let defaultsBi = Defaults[.userBigrams]
    let defaultsTri = Defaults[.userTrigrams]
    let defaultsHasData = !defaultsBi.isEmpty || !defaultsTri.isEmpty
    guard onDiskEmpty && defaultsHasData else { return }

    bigrams = defaultsBi
    trigrams = defaultsTri
    flushNow()  // đảm bảo disk có data trước khi xóa Defaults
    DispatchQueue.main.async {
      Defaults[.userBigrams] = [:]
      Defaults[.userTrigrams] = [:]
    }
    os_log("NGramStore: migrated %{public}d bigram keys / %{public}d trigram keys from Defaults",
           log: ngramLog, type: .info, bigrams.count, trigrams.count)
  }

  // MARK: - Pruning

  /// Giới hạn growth: mỗi prev key giữ top-N next words theo count, cap
  /// tổng số prev keys theo total count.
  private func pruneIfNeeded() {
    var biTotalChanged = false
    for (prev, nexts) in bigrams where nexts.count > maxNextsPerKey {
      let trimmed = nexts.sorted { $0.value > $1.value }.prefix(maxNextsPerKey)
      bigrams[prev] = Dictionary(uniqueKeysWithValues: trimmed.map { ($0.key, $0.value) })
      biTotalChanged = true
    }
    if bigrams.count > maxBigramKeys {
      // 1.9.0: secondary sort by key alphabetical để output deterministic
      // khi nhiều keys có cùng max count. Trước v1.9 order undefined → flush
      // khác nhau mỗi lần → khó debug + test.
      let keepers = bigrams.sorted { a, b in
        let ma = a.value.values.max() ?? 0
        let mb = b.value.values.max() ?? 0
        if ma != mb { return ma > mb }
        return a.key < b.key
      }.prefix(maxBigramKeys)
      bigrams = Dictionary(uniqueKeysWithValues: keepers.map { ($0.key, $0.value) })
      biTotalChanged = true
    }

    var triTotalChanged = false
    for (prev, nexts) in trigrams where nexts.count > maxNextsPerKey {
      let trimmed = nexts.sorted { $0.value > $1.value }.prefix(maxNextsPerKey)
      trigrams[prev] = Dictionary(uniqueKeysWithValues: trimmed.map { ($0.key, $0.value) })
      triTotalChanged = true
    }
    if trigrams.count > maxTrigramKeys {
      let keepers = trigrams.sorted { a, b in
        let ma = a.value.values.max() ?? 0
        let mb = b.value.values.max() ?? 0
        if ma != mb { return ma > mb }
        return a.key < b.key
      }.prefix(maxTrigramKeys)
      trigrams = Dictionary(uniqueKeysWithValues: keepers.map { ($0.key, $0.value) })
      triTotalChanged = true
    }
    if biTotalChanged {
      os_log("NGramStore: pruned to %{public}d bigram keys",
             log: ngramLog, type: .info, bigrams.count)
    }
    if triTotalChanged {
      os_log("NGramStore: pruned to %{public}d trigram keys",
             log: ngramLog, type: .info, trigrams.count)
    }
  }
}
