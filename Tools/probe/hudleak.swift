// hudleak — đo rò shared memory / KVO của AppKit khi HUD bị dựng lại.
//
// Công cụ ĐO, không phải mã sản phẩm. Mô phỏng đúng cách vkey vẽ HUD đoán từ:
// NSPanel sống lâu + NSHostingController + SwiftUI + NSVisualEffectView
// `.behindWindow` có `maskImage` bo tròn, rồi lặp N lần "hiện HUD" theo từng
// kiểu và in độ tăng của đúng ba con số đã đo trên máy thật (v4.28, 9 ngày,
// 551 MB): vùng "shared memory" 16 KB, `NSKeyValueDependencyContext`,
// `NSKeyValueDependency` — tỉ lệ 1 : 2 : 4 mỗi lần dựng lại.
//
// Build:  swiftc -parse-as-library -O Tools/probe/hudleak.swift -o /tmp/hudleak
// Chạy:   /tmp/hudleak <kiểu> [số lần, mặc định 300]
//
//   rebuild     kiểu v4.28: NSHostingController MỚI mỗi lần, mask vẽ lại mỗi layout
//   reuse       kiểu sau bản vá: một controller, chỉ thay `rootView`, mask cache
//   reuse-hide  như `reuse` nhưng ẩn/hiện panel mỗi lần (orderOut/orderFront)
//   hosting     dựng lại NSHostingController nhưng view KHÔNG có lớp blur
//   blur        chỉ gắn/gỡ NSVisualEffectView (không SwiftUI) mỗi lần
//
// Số đếm lấy bằng chính `vmmap --summary` và `heap` trên tiến trình này — cùng
// nguồn với phép đo trên máy thật, không tự suy diễn.

import AppKit
import SwiftUI

// MARK: - HUD mô phỏng

final class ProbeBackdropView: NSVisualEffectView {
  var cachesMask = false
  private var appliedRadius: CGFloat?

  override func layout() {
    super.layout()
    let radius = max(1, min(bounds.width, bounds.height) / 2)
    if cachesMask, radius == appliedRadius { return }
    appliedRadius = radius
    maskImage = Self.roundedMask(radius)
  }

  static func roundedMask(_ r: CGFloat) -> NSImage {
    let edge = r * 2 + 1
    let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
      return true
    }
    image.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
    image.resizingMode = .stretch
    return image
  }

  static func make(cachesMask: Bool) -> ProbeBackdropView {
    let view = ProbeBackdropView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    view.wantsLayer = true
    view.cachesMask = cachesMask
    return view
  }
}

struct ProbeBackdrop: NSViewRepresentable {
  let cachesMask: Bool

  func makeNSView(context: Context) -> ProbeBackdropView {
    ProbeBackdropView.make(cachesMask: cachesMask)
  }

  func updateNSView(_ view: ProbeBackdropView, context: Context) {
    view.needsLayout = true
  }
}

struct ProbeHUD: View {
  let text: String
  let withBlur: Bool
  let cachesMask: Bool

  var body: some View {
    HStack(spacing: 6) {
      Text("→").font(.system(size: 16, weight: .heavy, design: .rounded))
      Text(text).font(.system(size: 16, weight: .semibold))
      Text("·").font(.system(size: 16))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background {
      if withBlur {
        ProbeBackdrop(cachesMask: cachesMask)
      }
    }
    .compositingGroup()
    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    .padding(24)
  }
}

// MARK: - Đo

struct Counts {
  var sharedRegions = -1
  var dependencies = -1
  var contexts = -1
}

func run(_ tool: String, _ arguments: [String]) -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: tool)
  process.arguments = arguments
  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = Pipe()
  do {
    try process.run()
  } catch {
    return ""
  }
  // Đọc hết TRƯỚC khi chờ — output của `heap` lớn hơn bộ đệm pipe.
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  return String(decoding: data, as: UTF8.self)
}

func measure() -> Counts {
  let pid = String(ProcessInfo.processInfo.processIdentifier)
  var counts = Counts()
  for line in run("/usr/bin/vmmap", ["--summary", pid]).split(separator: "\n")
  where line.hasPrefix("shared memory") {
    counts.sharedRegions = Int(line.split(separator: " ").last ?? "") ?? -1
  }
  for line in run("/usr/bin/heap", [pid]).split(separator: "\n") {
    let fields = line.split(separator: " ", omittingEmptySubsequences: true)
    guard fields.count > 3, let count = Int(fields[0]) else { continue }
    if fields[3] == "NSKeyValueDependency" { counts.dependencies = count }
    if fields[3] == "NSKeyValueDependencyContext" { counts.contexts = count }
  }
  return counts
}

// MARK: - Lặp

@MainActor
final class Probe {
  let mode: String
  let panel: NSPanel
  private var reused: NSHostingController<ProbeHUD>?
  private let blurHost = NSView()

  init(mode: String) {
    self.mode = mode
    panel = NSPanel(
      contentRect: NSRect(x: 40, y: 40, width: 260, height: 90),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    if mode == "blur" {
      panel.contentView = blurHost
    }
    panel.orderFrontRegardless()
  }

  /// Một lần "hiện HUD" — đúng các bước `PredictionHUDWindow.show` làm.
  func show(_ index: Int) {
    let text = "từ gợi ý \(index % 37)"
    let size = NSSize(width: 220 + CGFloat(index % 5) * 12, height: 90)
    switch mode {
    case "rebuild", "hosting":
      let controller = NSHostingController(
        rootView: ProbeHUD(text: text, withBlur: mode == "rebuild", cachesMask: false))
      controller.sizingOptions = []
      controller.view.wantsLayer = true
      controller.view.layer?.backgroundColor = NSColor.clear.cgColor
      panel.contentViewController = controller
      controller.view.setFrameSize(size)
    case "reuse", "reuse-hide":
      let view = ProbeHUD(text: text, withBlur: true, cachesMask: true)
      if let controller = reused {
        controller.rootView = view
        controller.view.setFrameSize(size)
      } else {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = []
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = controller
        controller.view.setFrameSize(size)
        reused = controller
      }
    case "blur":
      blurHost.subviews.forEach { $0.removeFromSuperview() }
      let blur = ProbeBackdropView.make(cachesMask: false)
      blur.frame = NSRect(x: 24, y: 24, width: size.width - 48, height: size.height - 48)
      blurHost.addSubview(blur)
    default:
      fatalError("kiểu không hợp lệ: \(mode)")
    }
    panel.setContentSize(size)
    panel.orderFrontRegardless()
    pump()
    if mode == "reuse-hide" {
      panel.orderOut(nil)
      pump()
    }
  }

  /// Cho run loop chạy để AppKit layout + CoreAnimation commit thật sự xảy ra.
  func pump() {
    panel.displayIfNeeded()
    CATransaction.flush()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
  }
}

@main
struct HUDLeakProbe {
  @MainActor
  static func main() {
    let arguments = CommandLine.arguments
    let modes = ["rebuild", "reuse", "reuse-hide", "hosting", "blur"]
    guard arguments.count > 1, modes.contains(arguments[1]) else {
      print("dùng: hudleak <\(modes.joined(separator: "|"))> [số lần]")
      exit(2)
    }
    let mode = arguments[1]
    let iterations = arguments.count > 2 ? max(1, Int(arguments[2]) ?? 300) : 300

    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.finishLaunching()
    let probe = Probe(mode: mode)

    // Hâm nóng: loại chi phí một lần (font, class KVO, cache CoreUI) khỏi phép đo.
    for index in 0..<20 { probe.show(index) }
    let before = measure()
    for index in 0..<iterations { probe.show(index) }
    let after = measure()

    func delta(_ a: Int, _ b: Int) -> String {
      a < 0 || b < 0 ? "n/a" : String(b - a)
    }
    print(
      "mode=\(mode) n=\(iterations)"
        + " shm+=\(delta(before.sharedRegions, after.sharedRegions))"
        + " ctx+=\(delta(before.contexts, after.contexts))"
        + " dep+=\(delta(before.dependencies, after.dependencies))"
        + " (shm \(before.sharedRegions)→\(after.sharedRegions),"
        + " ctx \(before.contexts)→\(after.contexts),"
        + " dep \(before.dependencies)→\(after.dependencies))"
    )
  }
}
