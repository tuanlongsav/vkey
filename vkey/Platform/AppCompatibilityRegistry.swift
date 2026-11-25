//
//  AppCompatibilityRegistry.swift
//  vkey
//
//  Nguồn sự thật duy nhất cho mọi bảng nhận diện app theo bundle ID:
//  chiến lược gửi phím, lưu trữ NFC/NFD, terminal, trình duyệt, overlay và
//  ứng dụng điều khiển máy từ xa.
//

import Defaults
import Foundation

/// Strategy for sending keyboard events to replace text.
enum SendingStrategy {
  /// Send all characters in a single batch event (fastest, may fail in some apps).
  case batch
  /// Send each character as individual key events (slowest, most compatible).
  case stepByStep
  /// Send as batch but with delays between backspaces (balanced approach).
  case hybrid(backspaceDelayMicroseconds: UInt32)
  /// v2.12: ghi thẳng giá trị ô text qua Accessibility API thay vì gửi event.
  /// Spotlight / omnibox có inline autocomplete nuốt/đảo synthetic backspace
  /// nên ghi AXValue nguyên tử, không đụng event pipeline.
  case axDirect
}

extension AppSendingMode {
  /// Chiến lược gửi tương ứng. `.paced` nghỉ lâu hơn mặc định (hybrid 800µs)
  /// để lựa chọn này khác hẳn "tự động" với app chưa có trong bảng.
  var strategy: SendingStrategy {
    switch self {
    case .fast: return .batch
    case .paced: return .hybrid(backspaceDelayMicroseconds: 2000)
    case .stepByStep: return .stepByStep
    }
  }
}

/// Configuration for per-app event sending strategies.
struct AppSendingConfig {
  /// Bundle ID prefix to match.
  let bundlePrefix: String
  /// Sending strategy for this app.
  let strategy: SendingStrategy
  /// Human-readable name for logging.
  let name: String
}

enum AppCompatibilityRegistry {

  // MARK: - Sending Strategies

  /// Per-app sending strategy configuration.
  /// Apps are checked in order — first match wins.
  /// Apps not listed fall back to `.hybrid(backspaceDelayMicroseconds: 800)`.
  static let appStrategies: [AppSendingConfig] = [
    AppSendingConfig(bundlePrefix: "com.microsoft.Word", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Word"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Excel", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Excel"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Powerpoint", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "PowerPoint"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Outlook", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Outlook"),
    AppSendingConfig(bundlePrefix: "com.microsoft.onenote.mac", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "OneNote"),

    AppSendingConfig(bundlePrefix: "com.apple.Terminal", strategy: .stepByStep, name: "Terminal"),
    AppSendingConfig(bundlePrefix: "com.googlecode.iterm2", strategy: .stepByStep, name: "iTerm2"),
    AppSendingConfig(bundlePrefix: "net.kovidgoyal.kitty", strategy: .stepByStep, name: "Kitty"),
    AppSendingConfig(bundlePrefix: "com.mitchellh.ghostty", strategy: .stepByStep, name: "Ghostty"),
    // Warp phát hành theo kênh: bundle ID thật là "dev.warp.Warp-Stable" (-Preview).
    AppSendingConfig(bundlePrefix: "dev.warp.Warp", strategy: .stepByStep, name: "Warp"),
    AppSendingConfig(bundlePrefix: "co.zeit.hyper", strategy: .stepByStep, name: "Hyper"),
    AppSendingConfig(bundlePrefix: "org.tabby", strategy: .stepByStep, name: "Tabby"),
    // Alacritty: giữ cả upstream "org.alacritty" và entry cũ "io.alacritty".
    AppSendingConfig(bundlePrefix: "org.alacritty", strategy: .stepByStep, name: "Alacritty"),
    AppSendingConfig(bundlePrefix: "io.alacritty", strategy: .stepByStep, name: "Alacritty (legacy id)"),
    AppSendingConfig(bundlePrefix: "com.github.wez.wezterm", strategy: .stepByStep, name: "WezTerm"),
    AppSendingConfig(bundlePrefix: "com.raphaelamorim.rio", strategy: .stepByStep, name: "Rio"),
    // Termius: giữ entry DMG (trước) + prefix rút gọn cho bản App Store.
    AppSendingConfig(bundlePrefix: "com.termius-dmg.mac", strategy: .stepByStep, name: "Termius"),
    AppSendingConfig(bundlePrefix: "com.termius", strategy: .stepByStep, name: "Termius"),

    // Electron / chat / custom text-engine apps
    AppSendingConfig(bundlePrefix: "com.anthropic.claudefordesktop", strategy: .stepByStep, name: "Claude"),
    AppSendingConfig(bundlePrefix: "com.vng.zalo", strategy: .stepByStep, name: "Zalo"),
    AppSendingConfig(bundlePrefix: "com.tinyspeck.slackmacgap", strategy: .stepByStep, name: "Slack"),
    AppSendingConfig(bundlePrefix: "com.hnc.Discord", strategy: .stepByStep, name: "Discord"),
    AppSendingConfig(bundlePrefix: "com.facebook.archon", strategy: .stepByStep, name: "Messenger"),
    AppSendingConfig(bundlePrefix: "com.htl.plume", strategy: .stepByStep, name: "Plume"),
    // WhatsApp bản Electron (bản MAS Catalyst "net.whatsapp.WhatsApp" giữ mặc định .hybrid).
    AppSendingConfig(bundlePrefix: "desktop.WhatsApp", strategy: .stepByStep, name: "WhatsApp"),
    AppSendingConfig(bundlePrefix: "com.viber.osx", strategy: .stepByStep, name: "Viber"),
    AppSendingConfig(bundlePrefix: "ru.keepcoder.Telegram", strategy: .stepByStep, name: "Telegram"),
    AppSendingConfig(bundlePrefix: "com.apple.dock", strategy: .stepByStep, name: "Launchpad/Dock"),

    // AX-direct (inline autocomplete nuốt/đảo synthetic backspace)
    AppSendingConfig(bundlePrefix: "com.apple.Spotlight", strategy: .axDirect, name: "Spotlight"),
    AppSendingConfig(bundlePrefix: "com.apple.systemuiserver", strategy: .axDirect, name: "SystemUIServer"),
  ]

  /// Bản đã giải mã của `Defaults[.appSendingModes]` — tra ở mỗi lần thay chữ.
  private static let userSendingModes =
    DefaultsDerivedCache<[String: AppSendingMode]>(.appSendingModes) {
      Defaults[.appSendingModes]
    }

  /// Cách gửi phím người dùng tự chọn cho `bundleId`, nếu có.
  static func userSendingMode(for bundleId: String) -> AppSendingMode? {
    userSendingModes.value[bundleId]
  }

  static func getStrategy(for bundleId: String) -> SendingStrategy {
    resolveStrategy(for: bundleId, userMode: userSendingMode(for: bundleId))
  }

  /// Lựa chọn của người dùng thắng bảng dựng sẵn — TRỪ app đi `.axDirect`.
  static func resolveStrategy(for bundleId: String, userMode: AppSendingMode?) -> SendingStrategy {
    let builtIn = builtInStrategy(for: bundleId)
    if case .axDirect = builtIn { return builtIn }
    return userMode?.strategy ?? builtIn
  }

  static func builtInStrategy(for bundleId: String) -> SendingStrategy {
    return appStrategies.first(where: { bundleId.hasPrefix($0.bundlePrefix) })?.strategy
      ?? .hybrid(backspaceDelayMicroseconds: 800)
  }

  /// App giữ nhịp nghỉ của chiến lược gốc cả ở transform 1 ký tự (bs<=1 && diff<=1).
  static func keepsCushionOnSmallDiffs(
    bundleId: String, userMode: AppSendingMode? = nil
  ) -> Bool {
    if let userMode { return userMode != .fast }
    let id = bundleId.lowercased()
    return id.hasPrefix("com.htl.plume")
      || id.hasPrefix("com.facebook.archon")
  }

  // MARK: - Terminals & Overlays

  /// App terminal: lời nhắc mật khẩu (`sudo`, `ssh`) không lộ qua AX subrole
  /// secure nên `SecureInputMonitor` vẫn đứng ngoài khi terminal giữ secure input.
  static let terminalBundlePrefixes: [String] = [
    "com.apple.Terminal", "com.googlecode.iterm2", "net.kovidgoyal.kitty",
    "com.mitchellh.ghostty", "dev.warp.Warp", "co.zeit.hyper", "org.tabby",
    "org.alacritty", "io.alacritty", "com.github.wez.wezterm", "com.raphaelamorim.rio",
    "com.termius",
  ]

  static func isTerminalApp(_ bundleId: String?) -> Bool {
    guard let bundleId else { return false }
    return terminalBundlePrefixes.contains { bundleId.hasPrefix($0) }
  }

  /// Overlay luôn-chạy mà `eventTargetUnixProcessID` có thể trả PID app nền trên macOS 26.
  static let overlayBundleIds: [String] = [
    "com.apple.Spotlight",
    "com.apple.systemuiserver",
    "com.apple.dock",
  ]

  static func isOverlayBundle(_ bundleId: String) -> Bool {
    overlayBundleIds.contains { bundleId == $0 || bundleId.hasPrefix($0) }
  }

  // MARK: - Browsers & NFC Storage Classification

  /// Danh sách tiền tố bundle trình duyệt (Chromium, Firefox, WebKit, Arc…).
  static let browserBundlePrefixes: [String] = [
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

    // Edge (Excel cố tình KHÔNG nằm ở đây)
    "com.microsoft.edge", "com.microsoft.Edge",
  ]

  static func isBrowserApp(bundleId: String) -> Bool {
    browserBundlePrefixes.contains { bundleId.hasPrefix($0) }
  }

  /// Native text editors / CAD lưu grapheme NFC.
  private static let nfcNativeEditorBundlePrefixes: [String] = [
    "com.sublimetext.",
    "com.barebones.bbedit",
    "com.macromates.TextMate",
    "org.vim.MacVim",
    "net.shinyfrog.bear",
    "pro.writer.mac",
    "net.nemetschek.vectorworks",
    "net.vectorworks.",
  ]

  /// Microsoft Office native (KHÔNG gồm Edge Chromium).
  private static let officeNativeBundles: Set<String> = [
    "com.microsoft.Word",
    "com.microsoft.Excel",
    "com.microsoft.Powerpoint",
    "com.microsoft.Outlook",
    "com.microsoft.onenote.mac",
    "com.microsoft.Office.Word",
    "com.microsoft.Office.Excel",
  ]

  static func usesNFCGraphemeStorage(bundleId: String) -> Bool {
    if bundleId.isEmpty { return true }  // fallback safe (Apple native)
    if bundleId.hasPrefix("com.apple.") { return true }
    for prefix in nfcNativeEditorBundlePrefixes {
      if bundleId.hasPrefix(prefix) { return true }
    }
    if officeNativeBundles.contains(bundleId) { return true }
    if bundleId.hasPrefix("com.apple.iWork.") { return true }
    let lower = bundleId.lowercased()
    if lower.hasPrefix("com.google.gemini") { return true }
    if lower.hasPrefix("ru.keepcoder.telegram") { return true }
    if lower == "com.openai.chat" { return true }
    if lower.hasPrefix("com.htl.plume") { return true }
    return false
  }

  // MARK: - Canonical App Bundle & Remote Desktop Viewers

  /// Quy tiến trình phụ (SandboxBroker, openAndSavePanelService, WebKit.WebContent)
  /// về bundle ID app cha đang ở trước.
  static func canonicalAppBundle(focused: String, frontmost: String?) -> String {
    guard let frontmost, !frontmost.isEmpty else { return focused }
    if focused.hasPrefix(frontmost + ".") { return frontmost }
    if focused == "com.apple.appkit.xpc.openAndSavePanelService" { return frontmost }
    if focused.hasPrefix("com.apple.WebKit.") { return frontmost }
    return focused
  }

  /// App ĐIỀU KHIỂN MÁY TỪ XA: chuyển phím vật lý sang máy kia qua mạng.
  /// Máy ảo (Parallels, VMware, UTM) cố ý KHÔNG nằm trong danh sách này.
  static let remoteDesktopViewerBundles: Set<String> = [
    "com.apple.ScreenSharing",
    "com.apple.ScreenContinuity",
    "com.philandro.anydesk",
    "com.carriez.rustdesk",
    "com.teamviewer.TeamViewer",
    "com.microsoft.rdc.macos",
    "com.realvnc.vncviewer",
    "com.citrix.receiver.icaviewer.mac",
  ]
}
