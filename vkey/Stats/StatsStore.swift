//
//  StatsStore.swift
//  vkey
//
//  Disk persistence, ISO-week rotation, 4-week retention pruning,
//  backup export/restore, and diagnostics for UsageStatistics.
//

import Foundation
import os.log

private let storeLog = OSLog(subsystem: "dev.longht.vkey", category: "UsageStatistics")

struct StatsStore {
  let storageDir: URL
  let maxWeeksRetained: Int

  init(storageDir: URL?, maxWeeksRetained: Int = 4) {
    let resolved: URL
    if let custom = storageDir {
      resolved = custom
    } else {
      let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
      resolved = (appSupport ?? URL(fileURLWithPath: "/tmp"))
        .appendingPathComponent("vkey/stats", isDirectory: true)
    }
    try? FileManager.default.createDirectory(
      at: resolved, withIntermediateDirectories: true, attributes: nil
    )
    Self.excludeFromBackup(resolved)
    self.storageDir = resolved
    self.maxWeeksRetained = maxWeeksRetained
  }

  static func excludeFromBackup(_ url: URL) {
    var mutableURL = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? mutableURL.setResourceValues(values)
  }

  private var currentFileURL: URL {
    storageDir.appendingPathComponent("current.json")
  }

  func loadCurrentWeek() -> WeekBucket? {
    guard let data = try? Data(contentsOf: currentFileURL) else { return nil }
    guard let loaded = try? JSONDecoder.statsConfigured.decode(WeekBucket.self, from: data) else {
      os_log("UsageStatistics: current.json decode failed; preserving in-memory state",
             log: storeLog, type: .error)
      return nil
    }
    return loaded
  }

  func saveCurrentWeek(_ bucket: WeekBucket) {
    if let data = try? JSONEncoder.statsIndented.encode(bucket) {
      try? data.write(to: currentFileURL, options: .atomic)
    }
  }

  /// Close `bucket` as `<weekId>.json`, remove `current.json`, and prune old weeks.
  func closeWeek(_ bucket: WeekBucket, nextWeekId: String) {
    let closedURL = storageDir.appendingPathComponent("\(bucket.weekId).json")
    if let data = try? JSONEncoder.statsIndented.encode(
      bucket.summary(promotedAllow: [], promotedKeep: [])
    ) {
      try? data.write(to: closedURL, options: .atomic)
    }
    os_log("UsageStatistics: rotated week %{public}@ → %{public}@",
           log: storeLog, type: .info, bucket.weekId, nextWeekId)
    try? FileManager.default.removeItem(at: currentFileURL)
    pruneOldWeeks()
  }

  func pruneOldWeeks() {
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: storageDir, includingPropertiesForKeys: nil
    )) ?? []
    let closed = urls
      .filter { $0.pathExtension == "json" && $0.lastPathComponent != "current.json" }
      .sorted { $0.lastPathComponent > $1.lastPathComponent }
    for url in closed.dropFirst(maxWeeksRetained) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  func historicalSummaries() -> [UsageSummary] {
    let currentWeekFile = "\(WeekBucket.currentWeekId()).json"
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: storageDir, includingPropertiesForKeys: nil
    )) ?? []
    var out: [UsageSummary] = []
    for url in urls where url.pathExtension == "json"
                         && url.lastPathComponent != "current.json"
                         && url.lastPathComponent != currentWeekFile {
      if let data = try? Data(contentsOf: url),
         let summary = try? JSONDecoder.statsConfigured.decode(UsageSummary.self, from: data) {
        out.append(summary)
      }
    }
    out.sort { $0.weekId > $1.weekId }
    return out
  }

  func allWeekBucketsForExport(current: WeekBucket) -> [WeekBucket] {
    var out: [WeekBucket] = [current]
    let currentWeekFile = "\(WeekBucket.currentWeekId()).json"
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: storageDir, includingPropertiesForKeys: nil
    )) ?? []
    for url in urls where url.pathExtension == "json"
                         && url.lastPathComponent != "current.json"
                         && url.lastPathComponent != currentWeekFile {
      guard let data = try? Data(contentsOf: url) else { continue }
      if let bucket = try? JSONDecoder.statsConfigured.decode(WeekBucket.self, from: data) {
        out.append(bucket)
      } else if let summary = try? JSONDecoder.statsConfigured.decode(UsageSummary.self, from: data) {
        out.append(WeekBucket(fromLegacySummary: summary))
      }
    }
    return out
  }

  func writeClosedWeekBucket(_ bucket: WeekBucket) -> Bool {
    let url = storageDir.appendingPathComponent("\(bucket.weekId).json")
    guard let data = try? JSONEncoder.statsIndented.encode(bucket) else { return false }
    do {
      try data.write(to: url, options: .atomic)
      return true
    } catch {
      os_log("UsageStatistics.restoreFromBackup: write %{public}@ failed: %{public}@",
             log: storeLog, type: .error, bucket.weekId, error.localizedDescription)
      return false
    }
  }

  func clearAllFiles() {
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: storageDir, includingPropertiesForKeys: nil
    )) ?? []
    for url in urls {
      try? FileManager.default.removeItem(at: url)
    }
  }

  func diagnosticReport(current: WeekBucket) -> String {
    var lines: [String] = []
    lines.append("vkey stats diagnostic — \(ISO8601DateFormatter().string(from: Date()))")
    lines.append("storageDir: \(storageDir.path)")
    lines.append("counters.weekId: \(current.weekId)")
    lines.append("counters.wordsTotal: \(current.wordsTotal)")
    lines.append("counters.vnWordCounts.count: \(current.vnWordCounts.count)")
    lines.append("counters.enWordCounts.count: \(current.enWordCounts.count)")
    lines.append("currentWeekId(): \(WeekBucket.currentWeekId())")
    lines.append("--- files on disk ---")
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: storageDir, includingPropertiesForKeys: [.fileSizeKey]
    )) ?? []
    for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      var summary = "(decode failed)"
      if let data = try? Data(contentsOf: url) {
        if url.lastPathComponent == "current.json" {
          if let bucket = try? JSONDecoder.statsConfigured.decode(WeekBucket.self, from: data) {
            summary = "weekId=\(bucket.weekId), wordsTotal=\(bucket.wordsTotal), vnWords=\(bucket.vnWordCounts.count)"
          }
        } else if let s = try? JSONDecoder.statsConfigured.decode(UsageSummary.self, from: data) {
          summary = "weekId=\(s.weekId), wordsTotal=\(s.wordsTotal), vnWords=\(s.topVietnameseWords.count)"
        }
      }
      lines.append("  \(url.lastPathComponent) (\(size) bytes) — \(summary)")
    }
    return lines.joined(separator: "\n")
  }
}
