//
//  MarketingSnapshotExporter.swift
//  vkey
//
//  Xuất PNG marketing từ SwiftUI thật — không cần quyền Ghi màn hình.
//  Chạy: vkey --export-marketing=/path/to/images
//

import AppKit
import Defaults
import SwiftUI

enum MarketingSnapshotExporter {

  /// `--export-marketing` hoặc `--export-marketing=/path`
  static var isRequested: Bool {
    ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--export-marketing") }
  }

  private static var outputDirectory: URL {
    if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--export-marketing=") }) {
      return URL(fileURLWithPath: String(arg.dropFirst("--export-marketing=".count)), isDirectory: true)
    }
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    return cwd.appendingPathComponent("images", isDirectory: true)
  }

  @MainActor
  static func run(appDelegate: AppDelegate) {
    let out = outputDirectory
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

    // Theme Tonal + dark appearance — khớp README hiện tại.
    Defaults[.uiTheme] = .tonal
    Defaults[.appearanceMode] = .dark
    NSApp.appearance = NSAppearance(named: .darkAqua)

    appDelegate.isTrusted = true
    appDelegate.appState.typingMethod = .Telex
    appDelegate.appState.enabled = true

    let scale: CGFloat = 2.0
    let settingsSize = CGSize(width: 860, height: 640)

    exportMenuPanel(appDelegate: appDelegate, scale: scale, to: out)
    exportSettingsTabs(appDelegate: appDelegate, size: settingsSize, scale: scale, to: out)
    exportToggleHUD(scale: scale, to: out)
    exportPredictionHUD(scale: scale, to: out)

    if ProcessInfo.processInfo.arguments.contains("--export-marketing-carousel") {
      runCarousel(appDelegate: appDelegate, on: secondaryDisplay())
    } else {
      NSApp.terminate(nil)
    }
  }

  // MARK: - Exports

  @MainActor
  private static func exportMenuPanel(appDelegate: AppDelegate, scale: CGFloat, to out: URL) {
    let view = VKMenuPanel(appDelegate: appDelegate)
      .frame(width: 292)
      .padding(16)
      .background(Color(white: 0.96))
    snapshotHosting(view, size: CGSize(width: 292, height: 520), scale: scale,
                    file: out.appendingPathComponent("menubar-menu.png"))
  }

  @MainActor
  private static func exportSettingsTabs(
    appDelegate: AppDelegate,
    size: CGSize,
    scale: CGFloat,
    to out: URL
  ) {
    let tabs: [(VKTab, String)] = [
      (.general, "general-settings.png"),
      (.smart, "smart-switch-settings.png"),
      (.macro, "macro-settings.png"),
      (.spell, "spellcheck-settings.png"),
      (.stats, "statistics-settings.png"),
      (.theme, "theme-settings.png"),
    ]
    for (tab, filename) in tabs {
      UserDefaults.standard.set(tab.rawValue, forKey: "vk-settings-tab")
      let view = VKSettingsView()
        .environmentObject(appDelegate.appState)
        .frame(width: size.width, height: size.height)
      snapshotHosting(view, size: size, scale: scale, file: out.appendingPathComponent(filename))
    }
  }

  @MainActor
  private static func exportToggleHUD(scale: CGFloat, to out: URL) {
    for (enabled, name) in [(true, "hud-toggle-vi.png"), (false, "hud-toggle-en.png")] {
      ToggleHUDWindow.shared.show(isEnabled: enabled, duration: 60)
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
      if let img = snapshotFrontPanel(named: "ToggleHUD") {
        savePNG(img, scale: scale, to: out.appendingPathComponent(name))
      }
      ToggleHUDWindow.shared.hideImmediately()
    }
    // README / social — một ảnh đại diện HUD
    if let vi = NSImage(contentsOf: out.appendingPathComponent("hud-toggle-vi.png")) {
      savePNG(vi, scale: 1, to: out.appendingPathComponent("hud-toggle.png"))
    }
  }

  @MainActor
  private static func exportPredictionHUD(scale: CGFloat, to out: URL) {
    let fontSize = Defaults[.predictionHUDFontSize]
    let bg = Double(Defaults[.hudOpacityPercent])
    let sample = "anh chị"
    let contentSize = CGSize(width: 220, height: 44)
    let view = PredictionHUDView(
      prediction: sample,
      fontSize: fontSize,
      backgroundStrength: bg,
      contentSize: contentSize
    )
    .padding(24)
    .background(Color(white: 0.96))
    renderPNG(view, size: CGSize(width: 320, height: 100), scale: scale,
              file: out.appendingPathComponent("hud-prediction.png"))
  }

  // MARK: - Carousel (tuỳ chọn quay clip trên màn phụ)

  @MainActor
  private static func runCarousel(appDelegate: AppDelegate, on display: NSScreen?) {
    let screen = display ?? NSScreen.main!
    let frame = screen.visibleFrame

    let window = NSWindow(
      contentRect: frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false,
      screen: screen
    )
    window.backgroundColor = NSColor(white: 0.97, alpha: 1)
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.isOpaque = true

    let tabs = VKTab.allCases
    var index = 0
    let host = NSHostingController(
      rootView: carouselPage(appDelegate: appDelegate, tab: tabs[0])
        .frame(width: 860, height: 640)
    )
    window.contentViewController = host
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
      Task { @MainActor in
        index = (index + 1) % tabs.count
        if index == 0 {
          timer.invalidate()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
          }
          return
        }
        UserDefaults.standard.set(tabs[index].rawValue, forKey: "vk-settings-tab")
        host.rootView = carouselPage(appDelegate: appDelegate, tab: tabs[index])
          .frame(width: 860, height: 640)
      }
    }
  }

  @MainActor
  private static func carouselPage(appDelegate: AppDelegate, tab: VKTab) -> some View {
    VStack(spacing: 24) {
      HStack(spacing: 16) {
        VKMenuPanel(appDelegate: appDelegate)
        Spacer()
      }
      VKSettingsView()
        .environmentObject(appDelegate.appState)
    }
    .padding(40)
    .background(Color(white: 0.97))
    .onAppear {
      UserDefaults.standard.set(tab.rawValue, forKey: "vk-settings-tab")
    }
  }

  private static func secondaryDisplay() -> NSScreen? {
    let screens = NSScreen.screens
    if screens.count >= 2 {
      return screens.first(where: { $0 != NSScreen.main }) ?? screens[1]
    }
    return screens.first
  }

  // MARK: - Render helpers

  /// Snapshot qua NSWindow — ImageRenderer không vẽ đủ ScrollView / NSViewRepresentable.
  @MainActor
  private static func snapshotHosting<V: View>(
    _ view: V,
    size: CGSize,
    scale: CGFloat,
    file: URL
  ) {
    let host = NSHostingController(rootView: view)
    let pixelW = size.width * scale
    let pixelH = size.height * scale
    host.view.frame = NSRect(x: 0, y: 0, width: pixelW, height: pixelH)
    host.view.setBoundsSize(NSSize(width: pixelW, height: pixelH))

    let window = NSWindow(
      contentRect: NSRect(x: -10000, y: -10000, width: pixelW, height: pixelH),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.backgroundColor = NSColor(white: 0.96, alpha: 1)
    window.contentViewController = host
    window.setContentSize(NSSize(width: pixelW, height: pixelH))
    window.orderFrontRegardless()

    for _ in 0..<6 {
      host.view.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
    }

    guard let rep = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds) else {
      fputs("MarketingSnapshot: snapshot failed \(file.lastPathComponent)\n", stderr)
      window.orderOut(nil)
      return
    }
    host.view.cacheDisplay(in: host.view.bounds, to: rep)
    if let png = rep.representation(using: .png, properties: [:]) {
      try? png.write(to: file)
      print("MarketingSnapshot: \(file.path)")
    }
    window.orderOut(nil)
  }

  @MainActor
  private static func renderPNG<V: View>(
    _ view: V,
    size: CGSize,
    scale: CGFloat,
    file: URL
  ) {
    let renderer = ImageRenderer(
      content: view.frame(width: size.width, height: size.height)
    )
    renderer.scale = scale
    guard let cg = renderer.cgImage else {
      fputs("MarketingSnapshot: render failed \(file.lastPathComponent)\n", stderr)
      return
    }
    savePNG(NSImage(cgImage: cg, size: NSSize(width: size.width, height: size.height)), scale: 1, to: file)
    print("MarketingSnapshot: \(file.path)")
  }

  @MainActor
  private static func snapshotFrontPanel(named hint: String) -> NSImage? {
    for w in NSApp.windows {
      guard w.isVisible, w.className.contains("Panel") || w.level == .floating else { continue }
      guard let view = w.contentView else { continue }
      view.layoutSubtreeIfNeeded()
      let bounds = view.bounds
      guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { continue }
      view.cacheDisplay(in: bounds, to: rep)
      let img = NSImage(size: bounds.size)
      img.addRepresentation(rep)
      return img
    }
    return nil
  }

  private static func savePNG(_ image: NSImage, scale: CGFloat, to url: URL) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: url)
  }
}
