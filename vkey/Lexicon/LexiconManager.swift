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

    reload(channel: Defaults[.dictionaryUpdateChannel])
  }

  func reload(channel: DictionaryUpdateChannel) {
    reload(channel: channel, completion: nil)
  }

  func reload(channel: DictionaryUpdateChannel, completion: (() -> Void)?) {
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

      if channel == .hybrid,
        let package = self.loadUpdatePackage(),
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
    reload(channel: Defaults[.dictionaryUpdateChannel])
  }

  private func loadUpdatePackage() -> LexiconUpdatePackage? {
    guard FileManager.default.fileExists(atPath: updatePackageURL.path) else { return nil }
    do {
      let data = try Data(contentsOf: updatePackageURL)
      return try JSONDecoder().decode(LexiconUpdatePackage.self, from: data)
    } catch {
      return nil
    }
  }

  /// Endpoint shared by `downloadAndUpdateLexicon` and
  /// `checkAndPromptForDictionaryUpdate`. Defined once with a `guard let` so
  /// neither call site needs a force-unwrap.
  private static let lexiconUpdateEndpoint =
    "https://api.github.com/repos/tuanlongsav/vkey/contents/lexicon-update.json"

  /// In-flight task. Cancelled in `applicationWillTerminate` (via
  /// `cancelInFlightDownloads`) so the app can exit cleanly without the
  /// completion handler touching a deallocated `self`.
  private var inFlightDictionaryTask: URLSessionDataTask?

  func cancelInFlightDownloads() {
    inFlightDictionaryTask?.cancel()
    inFlightDictionaryTask = nil
  }

  func downloadAndUpdateLexicon(completion: ((Bool) -> Void)? = nil) {
    guard Defaults[.dictionaryUpdateChannel] == .hybrid else {
      completion?(false)
      return
    }
    guard Defaults[.dictionaryGitHubUpdateEnabled] else {
      completion?(false)
      return
    }

    guard let url = URL(string: Self.lexiconUpdateEndpoint) else {
      completion?(false)
      return
    }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

    let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self,
            error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let data = data else {
        completion?(false)
        return
      }

      do {
        let package = try JSONDecoder().decode(LexiconUpdatePackage.self, from: data)
        let currentVersion = self.snapshotVersions().vn

        if package.version > currentVersion {
          try self.setUpdatePackageData(data)
          completion?(true)
        } else {
          completion?(false)
        }
      } catch {
        completion?(false)
      }
    }
    inFlightDictionaryTask = task
    task.resume()
  }

  func checkAndPromptForDictionaryUpdate(force: Bool = false) {
    guard Defaults[.dictionaryUpdateChannel] == .hybrid else { return }
    guard Defaults[.dictionaryGitHubUpdateEnabled] else { return }

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
    request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

    let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self,
            error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let data = data else {
        return
      }
      
      do {
        let package = try JSONDecoder().decode(LexiconUpdatePackage.self, from: data)
        let currentVersion = self.snapshotVersions().vn
        
        if package.version > currentVersion {
          DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Cập nhật từ điển tiếng Việt"
            alert.informativeText = "Có phiên bản từ điển mới (phiên bản \(package.version)) có sẵn trên GitHub. Bạn có muốn cập nhật ngay không?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Cập nhật")
            alert.addButton(withTitle: "Để sau")
            
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
              do {
                try self.setUpdatePackageData(data)
                
                let successAlert = NSAlert()
                successAlert.messageText = "Thành công"
                successAlert.informativeText = "Đã cập nhật từ điển tiếng Việt lên phiên bản \(package.version) thành công!"
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "OK")
                successAlert.runModal()
              } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Lỗi"
                errorAlert.informativeText = "Không thể lưu tệp từ điển mới. Vui lòng thử lại sau."
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
              }
            }
          }
        }
      } catch {
        // Silent error
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

  func snapshotVersions() -> (vn: Int, en: Int, keep: Int) {
    queue.sync { (vnLexicon.version, enLexicon.version, keepLexicon.version) }
  }

  func snapshotSources() -> (vn: LexiconSource, en: LexiconSource, keep: LexiconSource) {
    queue.sync { (vnLexicon.source, enLexicon.source, keepLexicon.source) }
  }
}
