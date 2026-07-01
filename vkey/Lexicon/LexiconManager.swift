//
//  LexiconManager.swift
//  vkey
//
//  Manages the embedded + remote-update lexicons and exposes thread-safe
//  lookups for the spell engine. Extracted from InputProcessor.swift in
//  1.5.0 (Phase 3 split).
//

import AppKit
import Defaults
import Foundation

final class LexiconManager {
  static let shared = LexiconManager()

  private let queue = DispatchQueue(label: "dev.longht.vkey.lexicon", attributes: .concurrent)
  private var vnLexicon: InMemoryLexicon
  private var enLexicon: InMemoryLexicon
  private var keepLexicon: InMemoryLexicon

  private let updatePackageURL: URL

  init(updatePackageURL: URL? = nil) {
    let embeddedVN = InMemoryLexicon(
      version: EmbeddedLexiconData.version,
      source: .embedded,
      words: EmbeddedLexiconData.vietnameseWords
    )
    let embeddedEN = InMemoryLexicon(
      version: EmbeddedLexiconData.version,
      source: .embedded,
      words: EmbeddedLexiconData.englishWords
    )
    let embeddedKeep = InMemoryLexicon(
      version: EmbeddedLexiconData.version,
      source: .embedded,
      words: EmbeddedLexiconData.keepVietnameseWords
    )

    self.vnLexicon = embeddedVN
    self.enLexicon = embeddedEN
    self.keepLexicon = embeddedKeep

    if let updatePackageURL {
      self.updatePackageURL = updatePackageURL
    } else {
      let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      let dir = appSupport?.appendingPathComponent("vkey/lexicon", isDirectory: true)
      try? FileManager.default.createDirectory(
        at: dir ?? URL(fileURLWithPath: "/tmp"),
        withIntermediateDirectories: true,
        attributes: nil
      )
      self.updatePackageURL = (dir ?? URL(fileURLWithPath: "/tmp")).appendingPathComponent("lexicon-update.json")
    }

    reload()
  }

  func reload() {
    reload(completion: nil)
  }

  func reload(completion: (() -> Void)?) {
    let performReload = { [weak self] in
      guard let self = self else { return }

      // Load base syllables from NSDataAsset (compiled in Assets.xcassets)
      var vnWords: Set<String> = []
      if let asset = NSDataAsset(name: "syllables"),
         let raw = String(data: asset.data, encoding: .utf8) {
        let list = raw.components(separatedBy: "\n")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
          .filter { !$0.isEmpty }
        vnWords = Set(list)
      } else {
        // Fallback to embedded list if asset load fails
        vnWords = EmbeddedLexiconData.vietnameseWords
      }

      let embeddedVN = InMemoryLexicon(
        version: EmbeddedLexiconData.version,
        source: .embedded,
        words: vnWords
      )
      let embeddedEN = InMemoryLexicon(
        version: EmbeddedLexiconData.version,
        source: .embedded,
        words: EmbeddedLexiconData.englishWords
      )
      let embeddedKeep = InMemoryLexicon(
        version: EmbeddedLexiconData.version,
        source: .embedded,
        words: EmbeddedLexiconData.keepVietnameseWords
      )

      var selectedVN = embeddedVN
      var selectedEN = embeddedEN
      var selectedKeep = embeddedKeep

      // 1.5.0: also load the bilingual maps if the package carries them.
      var packageForBilingual: LexiconUpdatePackage?

      if let package = self.loadUpdatePackage(),
        package.version > EmbeddedLexiconData.version
      {
        selectedVN = InMemoryLexicon(
          version: package.version,
          source: .updatePackage,
          words: Set(package.vietnamese.map { $0.normalizedDictionaryToken })
        )
        selectedEN = InMemoryLexicon(
          version: package.version,
          source: .updatePackage,
          words: Set(package.english.map { $0.normalizedDictionaryToken }).union(EmbeddedLexiconData.englishWords)
        )
        selectedKeep = InMemoryLexicon(
          version: package.version,
          source: .updatePackage,
          words: Set(package.keep.map { $0.normalizedDictionaryToken }).union(EmbeddedLexiconData.keepVietnameseWords)
        )
        packageForBilingual = package
      }

      self.queue.sync(flags: .barrier) {
        self.vnLexicon = selectedVN
        self.enLexicon = selectedEN
        self.keepLexicon = selectedKeep
      }

      // EnVnReference is loaded outside the lexicon queue because it has its
      // own (effectively read-mostly) state and we never share its data with
      // the synchronous lookups in `isVietnameseWord` / `isEnglishWord`.
      EnVnReference.shared.load(
        en2vn: packageForBilingual?.enVnMapping,
        vn2en: packageForBilingual?.vnEnMapping
      )

      completion?()
    }

    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      performReload()
    } else {
      DispatchQueue.global(qos: .userInitiated).async {
        performReload()
      }
    }
  }

  func setUpdatePackageData(_ data: Data) throws {
    let dir = updatePackageURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: dir,
      withIntermediateDirectories: true,
      attributes: nil
    )
    try data.write(to: updatePackageURL, options: .atomic)
    reload()
  }

  private func loadUpdatePackage() -> LexiconUpdatePackage? {
    // File đã lưu KHÔNG được tin mù: mọi lần load đều phải qua cùng cổng kiểm tra
    // (size + cấu trúc + chữ ký) như đường tải mạng. Nếu không, ai ghi được file
    // này (vd vị trí world-writable, hoặc gói cũ chưa ký sau khi bật L1) sẽ bypass
    // hoàn toàn L1/L4. Gói không đạt → trả nil → reload rơi về lexicon embedded.
    guard FileManager.default.fileExists(atPath: updatePackageURL.path),
          let data = try? Data(contentsOf: updatePackageURL)
    else { return nil }
    return validatedPackage(data)
  }

  /// Endpoint shared by `downloadAndUpdateLexicon` and
  /// `checkAndPromptForDictionaryUpdate`.
  ///
  /// 1.6.2+: chuyển từ GitHub Contents API (`api.github.com/repos/.../contents/...`)
  /// sang `raw.githubusercontent.com` để:
  /// - **Bỏ giới hạn 1 MB** của Contents API (raw returns base64 cho file lớn).
  ///   Quan trọng khi dictionary mở rộng lên hàng chục nghìn entries.
  /// - **Không bị rate limit 60/h** của API anonymous (raw không count).
  /// - **CDN cache 300s** thay vì 60s → nhanh hơn cho user.
  /// - **Đơn giản hơn**: không cần Accept header đặc biệt.
  private static let lexiconUpdateEndpoint =
    "https://raw.githubusercontent.com/tuanlongsav/vkey/main/lexicon-update.json"

  /// L2: kích thước tối đa của gói từ điển tải về (defense-in-depth chống
  /// endpoint bị chiếm trả body khổng lồ → OOM). ~25 MB dư cho hàng chục nghìn entry.
  private static let maxLexiconPackageBytes = 25 * 1024 * 1024

  /// L1: Ed25519 public key (base64) để verify gói ĐÃ KÝ. RỖNG = tắt verify
  /// (hành vi hiện tại, không phá kênh update đang chạy). Xem hướng dẫn bật ở
  /// `LexiconSignatureVerifier`.
  private static let lexiconPublicKeyBase64 = ""

  /// Cổng kiểm tra an toàn CHUNG cho 1 gói từ điển — dùng cho CẢ đường tải mạng
  /// và đường load file đã lưu: cap kích thước (L2), decode, giới hạn cấu trúc
  /// (L4), và verify chữ ký khi đã cấu hình key (L1). Trả `nil` nếu gói không đạt.
  private func validatedPackage(_ data: Data) -> LexiconUpdatePackage? {
    guard data.count <= Self.maxLexiconPackageBytes,
          let package = try? JSONDecoder().decode(LexiconUpdatePackage.self, from: data),
          (try? package.validated()) != nil,
          LexiconSignatureVerifier.verify(package: package, publicKeyBase64: Self.lexiconPublicKeyBase64)
    else { return nil }
    return package
  }

  /// Như `validatedPackage` nhưng thêm early-reject theo `Content-Length` để khỏi
  /// buffer nguyên body khổng lồ (chỉ đường tải mạng mới có header này).
  private func validatedDownloadedPackage(_ data: Data, expectedContentLength: Int64) -> LexiconUpdatePackage? {
    if expectedContentLength > Int64(Self.maxLexiconPackageBytes) { return nil }
    return validatedPackage(data)
  }

  /// In-flight task. Cancelled in `applicationWillTerminate` (via
  /// `cancelInFlightDownloads`) so the app can exit cleanly without the
  /// completion handler touching a deallocated `self`.
  private var inFlightDictionaryTask: URLSessionDataTask?

  func cancelInFlightDownloads() {
    inFlightDictionaryTask?.cancel()
    inFlightDictionaryTask = nil
  }

  func downloadAndUpdateLexicon(completion: ((Bool) -> Void)? = nil) {
    guard let url = URL(string: Self.lexiconUpdateEndpoint) else {
      completion?(false)
      return
    }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    // 1.6.2+: raw.githubusercontent.com trả text/plain trực tiếp, không cần
    // Accept header tùy chỉnh.

    let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self,
            error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let data = data else {
        completion?(false)
        return
      }

      guard let package = self.validatedDownloadedPackage(
              data, expectedContentLength: httpResponse.expectedContentLength)
      else {
        completion?(false)
        return
      }
      let currentVersion = self.snapshotVersions().vn
      if package.version > currentVersion {
        do {
          try self.setUpdatePackageData(data)
          completion?(true)
        } catch {
          completion?(false)
        }
      } else {
        completion?(false)
      }
    }
    inFlightDictionaryTask = task
    task.resume()
  }

  /// Auto-check & auto-apply dictionary update from GitHub.
  /// - Auto-throttled to once per 24h (unless `force = true`).
  /// - Khi phát hiện version mới: tự tải + apply im lặng, không hỏi user.
  ///   Reasoning: hành vi "có bản mới, cài không?" gây phiền cho user phổ
  ///   thông; cập nhật từ điển là idempotent + không destructive nên auto.
  /// - Lỗi mạng / decode: silent.
  func checkAndPromptForDictionaryUpdate(force: Bool = false) {
    if !force {
      if let lastCheck = Defaults[.lastDictionaryCheckDate] {
        let oneDayAgo = Date().addingTimeInterval(-86400) // 24 hours
        if lastCheck > oneDayAgo {
          return
        }
      }
    }

    Defaults[.lastDictionaryCheckDate] = Date()

    guard let url = URL(string: Self.lexiconUpdateEndpoint) else {
      return
    }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    // 1.6.2+: raw.githubusercontent.com trả text/plain trực tiếp, không cần
    // Accept header tùy chỉnh.

    let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self,
            error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let data = data else {
        return
      }

      guard let package = self.validatedDownloadedPackage(
              data, expectedContentLength: httpResponse.expectedContentLength)
      else {
        // Gói không đạt (quá lớn / hỏng / sai chữ ký) → bỏ qua, thử lại lần sau.
        return
      }
      let currentVersion = self.snapshotVersions().vn
      if package.version > currentVersion {
        // Apply im lặng. Nếu ghi file lỗi (rất hiếm — full disk / perm),
        // bỏ qua; lần check kế tiếp 24h sau sẽ thử lại.
        try? self.setUpdatePackageData(data)
      }
    }
    inFlightDictionaryTask = task
    task.resume()
  }

  func isVietnameseWord(_ word: String) -> Bool {
    let token = word.normalizedDictionaryToken
    if token.isEmpty { return false }

    if Defaults[.personalDictionaryEnabled] {
      let denied = Set(Defaults[.userDenyWords].map { $0.normalizedDictionaryToken })
      if denied.contains(token) {
        return false
      }

      let allowed = Set(Defaults[.userAllowWords].map { $0.normalizedDictionaryToken })
      if allowed.contains(token) {
        return true
      }
    }

    return queue.sync { vnLexicon.contains(token) }
  }

  func isEnglishWord(_ word: String) -> Bool {
    let token = word.normalizedDictionaryToken
    guard !token.isEmpty else { return false }
    return queue.sync { enLexicon.contains(token) }
  }

  func shouldKeepVietnamese(_ word: String) -> Bool {
    let token = word.normalizedDictionaryToken
    if token.isEmpty { return false }

    if Defaults[.personalDictionaryEnabled] {
      let userKeep = Set(Defaults[.userKeepWords].map { $0.normalizedDictionaryToken })
      if userKeep.contains(token) {
        return true
      }
    }
    return queue.sync { keepLexicon.contains(token) }
  }

  func shouldApplyLegacyRestore(transformed: String, rawInput: String) -> Bool {
    guard let expectedRaw = EmbeddedLexiconData.legacyRestorePairs[transformed.lowercased()] else {
      return false
    }
    return expectedRaw == rawInput.normalizedDictionaryToken
  }

  func vietnameseWordsSnapshot() -> [String] {
    queue.sync { Array(vnLexicon.words) }
  }

  /// 1.7.10: snapshot từ điển EN trong bộ nhớ — dùng cho UI count + diag.
  func englishWordsSnapshot() -> [String] {
    queue.sync { Array(enLexicon.words) }
  }

  /// 1.7.10: list HẸP cho instant-raw-restore tại typing time. Chỉ dùng
  /// `EmbeddedLexiconData.englishWords` (126 từ hand-curated cho cases
  /// thường conflict telex như "off", "ass", "of") + `userAllowWords`.
  /// KHÔNG dùng package EN (~9826 từ) để tránh collision với telex stems
  /// ngắn (`cos`/`the`/`tie`/`hop`/`thee` → "có"/"thế"/"tiếng"/"họp"/"thế").
  /// Spell decision tại commit-time vẫn dùng `isEnglishWord(_)` full list.
  func isInstantRestoreEnglish(_ word: String) -> Bool {
    let token = word.normalizedDictionaryToken
    guard !token.isEmpty else { return false }
    if Defaults[.personalDictionaryEnabled] {
      let allowed = Set(Defaults[.userAllowWords].map { $0.normalizedDictionaryToken })
      if allowed.contains(token) { return true }
    }
    return EmbeddedLexiconData.englishWords.contains(token)
  }

  func snapshotVersions() -> (vn: Int, en: Int, keep: Int) {
    queue.sync { (vnLexicon.version, enLexicon.version, keepLexicon.version) }
  }

  func snapshotSources() -> (vn: LexiconSource, en: LexiconSource, keep: LexiconSource) {
    queue.sync { (vnLexicon.source, enLexicon.source, keepLexicon.source) }
  }
}
