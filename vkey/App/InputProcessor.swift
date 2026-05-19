//
//  InputProcessor.swift
//  vkey
//
//  Created by KhanhIceTea on 24/02/2024.
//

import AppKit
import CoreGraphics
import Defaults
import Foundation

// MARK: - Spellcheck & Lexicon Core

enum LexiconSource: String {
  case embedded
  case updatePackage
  case user
}

protocol Lexicon {
  var version: Int { get }
  var source: LexiconSource { get }
  func contains(_ word: String) -> Bool
}

struct InMemoryLexicon: Lexicon {
  let version: Int
  let source: LexiconSource
  let words: Set<String>

  func contains(_ word: String) -> Bool {
    words.contains(word.normalizedDictionaryToken)
  }
}

struct SuggestionCandidate: Equatable {
  let word: String
  let score: Double
}

enum SpellDecision: Equatable {
  case keepVietnamese
  case restoreRawEnglish(String)
  case keepRaw
  case suggest([SuggestionCandidate])
}

private struct EmbeddedLexiconData {
  static let version = 1

  static let vietnameseWords: Set<String> = Set([
    "xin", "chào", "tất", "cả", "các", "bạn", "điểm", "phiên", "đầu", "tiền", "đỏ",
    "trước", "chứng", "khoán", "gì", "nghì", "trình", "định", "việt", "phương", "hoàng",
    "hoạc", "hoái", "thì", "gia", "giá", "giáng", "giữ", "giếng", "buốt", "hoà", "hòa",
    "khỏe", "khoẻ", "thuỷ", "thủy", "tiếng", "biết", "kiếm", "điện", "muốn", "buồng",
    "lướt", "mượn", "hương", "hoạch", "toàn", "khoang", "loan", "xoắn", "loắt", "luật",
    "xuân", "huệch", "tuềnh", "huynh", "quýt", "khuyên", "duyệt", "yến", "yêm", "tôi",
    "không", "đẹp", "được", "nam", "việt nam", "địa", "chỉ",
  ].map { $0.normalizedDictionaryToken })

  static let englishWords: Set<String> = Set([
    "of", "if", "see", "tee", "text", "expect", "choose", "business", "address", "email",
    "long", "example", "com", "view", "list", "about", "keep", "deep", "sleep", "risk",
    "desk", "disk", "boost", "cursor", "param", "career", "beer", "peer", "sax", "toto",
    "nurses", "horses",
  ])

  static let keepVietnameseWords: Set<String> = Set([
    "lisa", "maria", "para", "sara"
  ])

  static let legacyRestorePairs: [String: String] = [
    "ò": "of",
    "ì": "if",
    "sê": "see",
    "tê": "tee",
  ]
}

private struct LexiconUpdatePackage: Codable {
  let version: Int
  let vietnamese: [String]
  let english: [String]
  let keep: [String]
}

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

    var selectedVN = embeddedVN
    var selectedEN = embeddedEN
    var selectedKeep = embeddedKeep

    if channel == .hybrid,
      let package = loadUpdatePackage(),
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
        words: Set(package.english.map { $0.normalizedDictionaryToken })
      )
      selectedKeep = InMemoryLexicon(
        version: package.version,
        source: .updatePackage,
        words: Set(package.keep.map { $0.normalizedDictionaryToken })
      )
    }

    queue.sync(flags: .barrier) {
      self.vnLexicon = selectedVN
      self.enLexicon = selectedEN
      self.keepLexicon = selectedKeep
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

  func downloadAndUpdateLexicon(completion: ((Bool) -> Void)? = nil) {
    guard Defaults[.dictionaryGitHubUpdateEnabled] else {
      completion?(false)
      return
    }

    let url = URL(string: "https://raw.githubusercontent.com/tuanlongsav/vkey/main/lexicon-update.json")!
    URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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
    }.resume()
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

final class SuggestionService {
  static let shared = SuggestionService()

  private let lexiconManager: LexiconManager

  init(lexiconManager: LexiconManager = .shared) {
    self.lexiconManager = lexiconManager
  }

  func suggest(word: String, locale: String = "vi_VN", limit: Int = 5) -> [SuggestionCandidate] {
    let query = word.normalizedDictionaryToken
    guard !query.isEmpty, locale.lowercased().hasPrefix("vi"), limit > 0 else { return [] }

    let queryFolded = query.vietnameseFolded
    guard !queryFolded.isEmpty else { return [] }

    let candidates = lexiconManager.vietnameseWordsSnapshot()
      .map { candidate -> SuggestionCandidate in
        let foldedCandidate = candidate.vietnameseFolded
        let distance = Self.levenshtein(queryFolded, foldedCandidate)
        let prefixBonus: Double = queryFolded.first == foldedCandidate.first ? 0.12 : 0
        let suffixBonus: Double = queryFolded.last == foldedCandidate.last ? 0.08 : 0
        let lengthPenalty = abs(queryFolded.count - foldedCandidate.count) > 2 ? 0.08 : 0
        let baseScore = 1.0 / Double(distance + 1)
        let score = max(0, min(1, baseScore + prefixBonus + suffixBonus - lengthPenalty))
        return SuggestionCandidate(word: candidate, score: score)
      }
      .filter { $0.score >= 0.24 }
      .sorted {
        if abs($0.score - $1.score) > 0.0001 {
          return $0.score > $1.score
        }
        return $0.word < $1.word
      }

    return Array(candidates.prefix(limit))
  }

  private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
    let a = Array(lhs)
    let b = Array(rhs)
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }

    var previous = Array(0...b.count)
    var current = Array(repeating: 0, count: b.count + 1)

    for i in 1...a.count {
      current[0] = i
      for j in 1...b.count {
        let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
        let insertion = current[j - 1] + 1
        let deletion = previous[j] + 1
        current[j] = min(substitution, insertion, deletion)
      }
      swap(&previous, &current)
    }
    return previous[b.count]
  }
}

final class SpellDecisionEngine {
  static let shared = SpellDecisionEngine()

  private let lexiconManager: LexiconManager
  private let suggestionService: SuggestionService

  init(
    lexiconManager: LexiconManager = .shared,
    suggestionService: SuggestionService = .shared
  ) {
    self.lexiconManager = lexiconManager
    self.suggestionService = suggestionService
  }

  func evaluate(rawInput: String, transformed: String, needsRecovery: Bool) -> SpellDecision {
    guard Defaults[.spellCheckEnabled] else { return .keepVietnamese }
    guard !rawInput.isEmpty, !transformed.isEmpty else { return .keepVietnamese }

    let rawToken = rawInput.normalizedDictionaryToken
    let transformedToken = transformed.normalizedDictionaryToken
    guard !rawToken.isEmpty, !transformedToken.isEmpty else { return .keepRaw }

    if lexiconManager.shouldApplyLegacyRestore(transformed: transformed, rawInput: rawInput),
      Defaults[.englishAutoRestoreEnabled]
    {
      return .restoreRawEnglish(rawInput)
    }

    if lexiconManager.shouldKeepVietnamese(transformed) {
      return .keepVietnamese
    }

    let isVietnameseWord = lexiconManager.isVietnameseWord(transformed)
    if !needsRecovery && isVietnameseWord {
      return .keepVietnamese
    }

    let rawIsEnglish = lexiconManager.isEnglishWord(rawInput)
    if Defaults[.englishAutoRestoreEnabled] {
      if needsRecovery && rawIsEnglish {
        return .restoreRawEnglish(rawInput)
      }

      if Defaults[.restorePolicy] == .englishFirst, rawIsEnglish, !isVietnameseWord {
        return .restoreRawEnglish(rawInput)
      }
    }

    if needsRecovery {
      guard Defaults[.suggestionEnabled] else { return .keepRaw }
      let suggestions = suggestionService.suggest(word: transformed, locale: "vi_VN", limit: 5)
      return suggestions.isEmpty ? .keepRaw : .suggest(suggestions)
    }

    return .keepVietnamese
  }
}

private extension String {
  var normalizedDictionaryToken: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  var vietnameseFolded: String {
    let prepared = replacingOccurrences(of: "đ", with: "d")
      .replacingOccurrences(of: "Đ", with: "d")
    return prepared.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
  }
}

// MARK: - WordBuffer

/// WordBuffer manages the Vietnamese word state during typing.
/// It tracks the current word being typed, handles push/pop operations,
/// and manages recovery mode with a snapshot stack for multi-step rollback.
struct WordBuffer {

  struct Snapshot {
    let wordState: TiengVietState
    let keys: [Character]
    let transformed: String
    let stopProcessing: Bool
  }

  var keys: [Character] = []
  var stopProcessing = false
  var lastTransformed = ""
  var transformed = ""

  var previousWordState: TiengVietState?
  var wordState = TiengVietState.empty

  /// Last valid snapshot for single-step rollback out of recovery mode.
  var lastValidSnapshot: Snapshot?

  private static let impossible2LetterPrefixes: Set<String> = [
    "bl", "cl", "fl", "gl", "pl", "sl", "vl",
    "br", "cr", "dr", "fr", "gr", "pr", "wr",
    "st", "sm", "sn", "sp", "sc", "sk", "sw",
    "tw", "dw", "sh", "ps", "pn", "ts", "kn", "kr",
    "bb", "cc", "ff", "gg", "hh", "jj", "kk", "ll",
    "mm", "nn", "pp", "qq", "rr", "ss", "tt", "vv",
    "xx", "zz"
  ]

  private static let impossible3LetterPrefixes: Set<String> = [
    "str", "thr", "phr", "chr", "sch", "scr", "spr"
  ]

  func isImpossibleCluster(_ keys: [Character], engine: TypingMethod) -> Bool {
    guard !keys.isEmpty else { return false }
    
    // Rule 1: First letter cannot be f, j, z (or w for VNI) if allowed-zwjf is disabled
    if !Defaults[.allowedZWJF], let firstChar = keys.first {
      let lowerFirst = firstChar.lowercased()
      if lowerFirst == "f" || lowerFirst == "j" || lowerFirst == "z" {
        return true
      }
      
      // VNI specific: starting letter cannot be w
      if engine is VNI, lowerFirst == "w" {
        return true
      }
    }
    
    // Rule 2: Impossible 2-letter prefixes
    if keys.count >= 2 {
      let prefix2 = String(keys.prefix(2)).lowercased()
      if Self.impossible2LetterPrefixes.contains(prefix2) {
        return true
      }
    }
    
    // Rule 3: Impossible 3-letter prefixes
    if keys.count >= 3 {
      let prefix3 = String(keys.prefix(3)).lowercased()
      if Self.impossible3LetterPrefixes.contains(prefix3) {
        return true
      }
    }
    
    return false
  }

  // MARK: - Word Lifecycle

  mutating func newWord(storePrevious: Bool = false) {
    previousWordState = nil
    if !wordState.isBlank {
      if storePrevious {
        previousWordState = wordState
      }
      wordState = .empty
    }

    keys = []
    lastValidSnapshot = nil
    stopProcessing = false
    lastTransformed = ""
    transformed = ""
  }

  // MARK: - Pop (Backspace)

  mutating func pop(engine: TypingMethod) -> (Int, [Character]) {
    lastTransformed = transformed

    // Single-step rollback: if we are in recovery and it was caused by the LATEST keystroke
    if stopProcessing, let valid = lastValidSnapshot, keys.count == valid.keys.count + 1 {
      wordState = valid.wordState
      keys = valid.keys
      transformed = valid.transformed
      stopProcessing = valid.stopProcessing
      lastValidSnapshot = nil

      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: lastTransformed, to: transformed)

      if numBackspaces == 1 && diffChars.isEmpty {
        return (0, [])
      }

      return (numBackspaces, diffChars)
    }

    // Normal pop: restore previous word on empty buffer
    if wordState.isBlank, let prev = previousWordState {
      wordState = prev
      previousWordState = nil
      keys = Array(wordState.chuKhongDau)
      transformed = wordState.transformed
      lastTransformed = transformed
      stopProcessing = false
      lastValidSnapshot = nil
      return (0, [])  // Let OS handle the backspace that brought us here
    }

    // Normal pop: remove last character
    wordState = engine.pop(state: wordState)
    keys = Array(wordState.chuKhongDau)
    
    if isImpossibleCluster(keys, engine: engine) {
      stopProcessing = true
    } else {
      stopProcessing = wordState.needsRecovery
    }

    if stopProcessing {
      transformed = String(keys)
    } else {
      transformed = wordState.transformed
    }

    lastValidSnapshot = nil

    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If it's a simple 1-char deletion, let the OS handle it
    if numBackspaces == 1 && diffChars.isEmpty {
      return (0, [])
    }

    return (numBackspaces, diffChars)
  }

  // MARK: - Push (New Character)

  mutating func push(char: Character, engine: TypingMethod) {
    // Save current state before mutation
    let snapshot = Snapshot(
      wordState: wordState,
      keys: keys,
      transformed: transformed,
      stopProcessing: stopProcessing
    )

    keys.append(char)
    lastTransformed = transformed

    if stopProcessing {
      transformed.append(char)
      wordState = wordState.push(char)
      return
    }

    // Doubled Tone Mark Preservation: if raw keys contains consecutive doubled tone marks, preserve it raw
    let keysStr = String(keys).lowercased()
    let doubledTones = ["ss", "ff", "rr", "xx", "jj"]
    if doubledTones.contains(where: { keysStr.contains($0) }) {
      stopProcessing = true
      transformed = String(keys)
      wordState = wordState.push(char)
      
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    // Check if newly formed keys are an impossible cluster
    if isImpossibleCluster(keys, engine: engine) {
      stopProcessing = true
      transformed = String(keys)
      wordState = wordState.push(char)
      
      // Save snapshot for rollback if we just entered recovery/stopProcessing
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
      return
    }

    let result = engine.push(char: char, state: wordState)
    wordState = result.state

    // Check if we need to recover original input (invalid Vietnamese syllable)
    if wordState.needsRecovery {
      stopProcessing = true
      // Use keys array which contains ALL typed characters (including tone marks like 's', 'f' etc.)
      transformed = String(keys)

      // If we JUST entered recovery mode, save the snapshot for rollback
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
    } else {
      transformed = wordState.transformed
      // Clear snapshot when we're in valid state — no rollback needed
      lastValidSnapshot = nil
    }

    if engine.shouldStopProcessing(keyStr: String(keys)) {
      stopProcessing = true
      if transformed.count == lastTransformed.count {
        transformed.append(char)
        wordState = wordState.push(char)
      }
    }
  }
}

// MARK: - TransformationTracker

/// TransformationTracker monitors for repeated transformation failures
/// and auto-switches the sending strategy when a pattern is detected.
/// This helps apps where the default strategy doesn't work reliably.
struct TransformationTracker {

  /// Current sending strategy for the active app
  var currentStrategy: SendingStrategy = .batch
  private var consecutiveFailures = 0
  private var consecutiveHighRiskTransforms = 0

  // MARK: - Strategy Management

  mutating func resetForApp(_ bundleId: String) {
    currentStrategy = EventSimulator.getStrategy(for: bundleId)
    consecutiveFailures = 0
    consecutiveHighRiskTransforms = 0
  }

  /// Detect transformation failures based on event creation status and
  /// repeated high-risk transforms on apps that are known to be sensitive.
  mutating func detectFailure(
    telemetry: EventSendTelemetry,
    appLikelySensitive: Bool
  ) -> Bool {
    guard telemetry.attemptedTransform else {
      consecutiveHighRiskTransforms = max(0, consecutiveHighRiskTransforms - 1)
      return false
    }

    if telemetry.createdEvents {
      consecutiveFailures = max(0, consecutiveFailures - 1)
    } else {
      consecutiveFailures += 1
    }

    let isHighRisk = appLikelySensitive
      && !telemetry.usedAsyncQueue
      && telemetry.touchedCharacters >= 3
    if isHighRisk {
      consecutiveHighRiskTransforms += 1
    } else {
      consecutiveHighRiskTransforms = max(0, consecutiveHighRiskTransforms - 1)
    }

    return consecutiveFailures >= 2 || consecutiveHighRiskTransforms >= 3
  }

  /// Auto-switches to step-by-step mode if failures are detected.
  mutating func autoSwitchIfNeeded(activeApp: String) {
    guard Defaults[.autoSwitchStrategy] else { return }

    // Don't auto-switch if already using step-by-step
    if case .stepByStep = currentStrategy { return }

    // Switch to step-by-step for this session
    #if DEBUG
    let appName = EventSimulator.getAppName(for: activeApp)
    print("[vkey] Auto-switched from \(currentStrategy) to step-by-step mode for \(appName) due to failures")
    #endif

    currentStrategy = .stepByStep
  }
}

// MARK: - InputProcessor

class InputProcessor {
  static let FixAutocompleteApps = [
    // Chromium-based
    "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta",
    "org.chromium.Chromium",
    "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
    "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary",
    "com.vivaldi.Vivaldi", "com.vivaldi.Vivaldi.snapshot",
    "ru.yandex.desktop.yandex-browser", "com.naver.Whale",

    // Opera
    "com.opera.Opera", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
    "com.operasoftware.OperaAir", "com.opera.OperaNext",

    // Firefox-based
    "org.mozilla.firefox", "org.mozilla.nightly", "org.torproject.torbrowser", "org.librewolf.LibreWolf",
    "app.zen-browser.zen",

    // Safari & WebKit-based
    "com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.apple.Safari.TechnologyPreview",
    "com.kagi.kagimacOS", "com.duckduckgo.mac", "com.duckduckgo.macos.browser",

    // Arc & Others
    "company.thebrowser.Browser", "company.thebrowser.Arc", "company.thebrowser.dia",
    "com.sigmaos.sigmaos", "com.sigmaos.sigmaos.macos",
    "com.pushplaylabs.sidekick", "com.firstversionist.polypane",
    "ai.perplexity.comet", "com.electron.min",

    // Office & Legacy
    "com.microsoft.Excel", "com.microsoft.Office.Excel", "com.microsoft.edge", "com.microsoft.Edge",
  ]
  static let NewWordKeys = "`!@#$%^&*()-=[]\\;',./~_+{}|:\"<>?"
  static let NewWordTaskKeys: [TaskKey] = [.Enter, .Space, .Tab]
  static let JumpTaskKeys: [TaskKey] = [.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight]

  public var engine: TypingMethod
  public var typingMethod: TypingMethods
  public var keyLayout = KeyboardUS()
  public var activeApp = ""
  public private(set) var lastSuggestions: [SuggestionCandidate] = []

  private let spellDecisionEngine = SpellDecisionEngine.shared

  /// Word buffer manages the current word state
  var wordBuffer = WordBuffer()

  /// Transformation tracker manages per-app strategy and failure detection
  var strategyTracker = TransformationTracker()

  /// Track pasteboard change count to detect external paste operations
  private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount

  // MARK: - Convenience accessors (preserve existing API for tests)

  public var keys: [Character] {
    get { wordBuffer.keys }
    set { wordBuffer.keys = newValue }
  }

  public var stopProcessing: Bool {
    get { wordBuffer.stopProcessing }
    set { wordBuffer.stopProcessing = newValue }
  }

  public var lastTransformed: String {
    get { wordBuffer.lastTransformed }
    set { wordBuffer.lastTransformed = newValue }
  }

  public var transformed: String {
    get { wordBuffer.transformed }
    set { wordBuffer.transformed = newValue }
  }

  public var previousWordState: TiengVietState? {
    get { wordBuffer.previousWordState }
    set { wordBuffer.previousWordState = newValue }
  }

  public var wordState: TiengVietState {
    get { wordBuffer.wordState }
    set { wordBuffer.wordState = newValue }
  }

  // MARK: - Init & Configuration

  init(method: TypingMethods) {
    typingMethod = method
    engine = typingMethod == .Telex ? Telex() : VNI()
    LexiconManager.shared.reload(channel: Defaults[.dictionaryUpdateChannel])
  }

  public func changeTypingMethod(newMethod: TypingMethods) {
    typingMethod = newMethod
    engine = typingMethod == .Telex ? Telex() : VNI()
    newWord()
  }

  public func changeActiveApp(_ app: String) {
    activeApp = app
    strategyTracker.resetForApp(app)
  }

  // MARK: - Word Operations (delegate to WordBuffer)

  public func newWord(storePrevious: Bool = false) {
    wordBuffer.newWord(storePrevious: storePrevious)
  }

  public func pop() -> (Int, [Character]) {
    return wordBuffer.pop(engine: engine)
  }

  public func push(char: Character) {
    wordBuffer.push(char: char, engine: engine)
  }

  // MARK: - Main Input Handler

  public func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let shifted = flags.contains(.maskShift) || (!keyLayout.isNumberKey(keyCode: keyCode) && flags.contains(.maskAlphaShift))

    // Handle modifier keys (Cmd, Ctrl, Alt) - clear word buffer
    if flags.contains(.maskCommand) || flags.contains(.maskControl)
      || flags.contains(.maskAlternate)
    {
      newWord()
      return Unmanaged.passUnretained(event)
    }

    // Detect if a paste operation occurred (pasteboard changed externally)
    let currentPasteboardCount = NSPasteboard.general.changeCount
    if currentPasteboardCount != lastPasteboardChangeCount {
      lastPasteboardChangeCount = currentPasteboardCount
      newWord()
    }

    // Dispatch based on key type
    if let taskKey = keyLayout.mapTask(keyCode: keyCode) {
      return handleTaskKey(taskKey, event: event)
    } else if let newChar = keyLayout.mapText(keyCode: keyCode, withShift: shifted) {
      return handleTextChar(newChar, event: event)
    }

    return Unmanaged.passUnretained(event)
  }

  // MARK: - Private Event Handlers

  private func handleTaskKey(_ taskKey: TaskKey, event: CGEvent) -> Unmanaged<CGEvent>? {
    if InputProcessor.NewWordTaskKeys.contains(taskKey) {
      // Only expand macros on Space — Tab/Enter often have form-submission semantics
      // we don't want to swallow.
      if taskKey == .Space, expandMacroIfMatch(endingChar: " ") {
        newWord(storePrevious: true)
        return nil
      }

      if taskKey == .Space, applySpellDecisionOnCommit(endingChar: " ", swallowEndingChar: true) {
        newWord(storePrevious: true)
        return nil
      }
      newWord(storePrevious: true)
    } else if taskKey == .Escape {
      let orig = String(wordBuffer.keys)
      let currentTransformed = wordBuffer.transformed
      if !wordBuffer.wordState.isBlank && currentTransformed != orig {
        let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: currentTransformed, to: orig)
        let telemetry = EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
        newWord()
        return nil // swallow ESC event
      }
      newWord()
    } else if taskKey == .Delete {
      let (numBackspaces, diffChars) = pop()
      if numBackspaces > 0 || !diffChars.isEmpty {
        let telemetry = EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
        return nil
      }
    } else if InputProcessor.JumpTaskKeys.contains(taskKey) {
      newWord()
    }
    return Unmanaged.passUnretained(event)
  }

  private func handleTextChar(_ newChar: Character, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Check if this is a word-ending character (punctuation, etc.) BEFORE processing
    if let _ = InputProcessor.NewWordKeys.firstIndex(of: newChar) {
      if expandMacroIfMatch(endingChar: newChar) {
        newWord(storePrevious: true)
        return nil
      }
      _ = applySpellDecisionOnCommit(endingChar: newChar, swallowEndingChar: false)
      newWord(storePrevious: true)
      return Unmanaged.passUnretained(event)
    }

    push(char: newChar)
    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If the only change is the new character itself, let it pass through
    if let firstDiffChar = diffChars.first,
      diffChars.count == 1 && firstDiffChar == newChar && numBackspaces == 0
    {
      return Unmanaged.passUnretained(event)
    }

    if isFixAutocompleteApp() {
      // For autocomplete-capable apps (browsers, etc.), use select-and-replace
      // instead of backspace-and-type. Shift+Left naturally extends any existing
      // inline autocomplete selection, so the typed replacement covers both the
      // autocomplete text and the characters being modified.
      let telemetry = EventSimulator.sendSelectAndReplace(
        selectLeftCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: true)
    } else {
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: false)
    }
    return nil
  }

  // MARK: - Helpers

  private func observeTelemetry(_ telemetry: EventSendTelemetry, appLikelySensitive: Bool) {
    if strategyTracker.detectFailure(
      telemetry: telemetry,
      appLikelySensitive: appLikelySensitive
    ) {
      strategyTracker.autoSwitchIfNeeded(activeApp: activeApp)
    }
  }

  /// Applies spell/restore/suggestion rules when a word commit key is pressed.
  /// - Parameters:
  ///   - endingChar: Commit key character (space or punctuation).
  ///   - swallowEndingChar: True when commit key should be emitted by vkey.
  /// - Returns: True when a replacement was sent.
  @discardableResult
  private func applySpellDecisionOnCommit(
    endingChar: Character,
    swallowEndingChar: Bool
  ) -> Bool {
    let rawInput = String(wordBuffer.keys)
    let current = wordBuffer.transformed
    guard !rawInput.isEmpty, !current.isEmpty else {
      lastSuggestions = []
      return false
    }

    guard Defaults[.spellCheckInSentenceEnabled] else {
      lastSuggestions = []
      return false
    }

    let decision = spellDecisionEngine.evaluate(
      rawInput: rawInput,
      transformed: current,
      needsRecovery: wordBuffer.wordState.needsRecovery || wordBuffer.stopProcessing
    )

    switch decision {
    case .keepVietnamese, .keepRaw:
      lastSuggestions = []
      return false

    case .restoreRawEnglish(let restoredWord):
      lastSuggestions = []
      let target = swallowEndingChar ? restoredWord + String(endingChar) : restoredWord
      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: current, to: target)
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      return true

    case .suggest(let suggestions):
      lastSuggestions = suggestions
      guard
        Defaults[.autoApplyHighConfidenceSuggestion],
        let top = suggestions.first,
        top.score >= 0.88
      else {
        return false
      }

      let target = swallowEndingChar ? top.word + String(endingChar) : top.word
      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(from: current, to: target)
      let telemetry = EventSimulator.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
      return true
    }
  }

  func isFixAutocompleteApp() -> Bool {
    if Focused.isComboBoxOrSearchField() {
      return true
    }
    return InputProcessor.FixAutocompleteApps.contains { app in
      return activeApp.hasPrefix(app)
    }
  }

  static func macroReplacement(
    for current: String,
    endingChar: Character,
    macros: [Macro]
  ) -> (backspaceCount: Int, diffChars: [Character])? {
    guard !current.isEmpty else { return nil }
    guard
      let macro = macros.first(where: {
        !$0.from.isEmpty && !$0.to.isEmpty && $0.from == current
      })
    else {
      return nil
    }

    return (current.count, Array(macro.to + String(endingChar)))
  }

  /// Expands the current word using the user's macro table if it matches.
  /// When a match is found, replaces the on-screen word with the expansion plus
  /// the word-ending character, then returns true so the caller can swallow the
  /// original ending key. Returns false (no side effects) when no macro matches.
  private func expandMacroIfMatch(endingChar: Character) -> Bool {
    let current = wordBuffer.transformed
    guard
      let replacement = Self.macroReplacement(
        for: current,
        endingChar: endingChar,
        macros: Defaults[.macros]
      )
    else {
      return false
    }

    let telemetry = EventSimulator.sendReplacement(
      backspaceCount: replacement.backspaceCount,
      diffChars: replacement.diffChars,
      strategy: strategyTracker.currentStrategy
    )
    observeTelemetry(telemetry, appLikelySensitive: isFixAutocompleteApp())
    return true
  }
}
