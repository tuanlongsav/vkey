//
//  Tools/export_sf_symbols.swift
//
//  Export tất cả SF Symbol vkey đang dùng ra PNG để designer có
//  template thiết kế bộ icon bitmap thay thế. Output đi vào
//  `Tools/icon-set-templates/<name>/`. Mỗi symbol có 3 size phù hợp
//  asset catalog macOS: 1x (32pt), 2x (64pt), 3x (96pt).
//
//  Cách chạy:
//
//      swift Tools/export_sf_symbols.swift
//
//  Output (ví dụ):
//      Tools/icon-set-templates/gear/gear-32.png
//      Tools/icon-set-templates/gear/gear-64.png
//      Tools/icon-set-templates/gear/gear-96.png
//
//  Sau khi designer làm bitmap thật (PDF vector preferred), drop vào
//  `vkey/Assets.xcassets/Icons3D/<name>.imageset/` để override
//  runtime SwiftUI effects trong `ThemedSymbol.swift`.

import AppKit
import Foundation

// Danh sách SF Symbol vkey 1.5.3 dùng. Khi UI thêm icon mới, thêm
// vào đây và chạy lại script. Comment đi kèm là context xuất hiện.
let symbols: [String] = [
  // Menu Bar
  "arrow.left.arrow.right.square",   // Chuyển đổi bộ gõ
  "keyboard",                        // Kiểu Telex
  "keyboard.badge.ellipsis",         // Kiểu VNI
  "gearshape",                       // Cài đặt
  "arrow.left.arrow.right.circle",   // Smart Switch toggle
  "checkmark.circle",                // Sửa lỗi chính tả toggle
  "text.cursor",                     // Macro toggle
  "cup.and.saucer",                  // Ủng hộ tác giả
  "info.circle",                     // Thông tin dự án
  "arrow.triangle.2.circlepath",     // Kiểm tra cập nhật
  "power",                           // Thoát

  // Menu bar state (sẽ KHÔNG thay đổi qua theme, nhưng vẫn export để
  // designer có context overall icon set)
  "gear.badge.questionmark",         // Untrusted state
  "lock.square",                     // Secure input state

  // Settings tabs
  "gear",                            // Tab Chung
  "text.badge.checkmark",            // Tab Chính tả
  "chart.bar.doc.horizontal",        // Tab Thống kê

  // Tab Chung
  "arrow.up.right.square",           // Tự khởi động
  "abc",                             // Kiểu gõ
  "character",                       // Phụ âm zwjf
  "sparkles",                        // Auto typo + Kích hoạt nhanh
  "macwindow.badge.plus",            // HUD toggle
  "textformat",                      // Kiểu đặt dấu
  "command",                         // Phím tắt

  // Tab Chính tả
  "text.justify.left",               // Kiểm tra trong câu
  "lightbulb",                       // Gợi ý
  "wand.and.stars",                  // Auto-apply gợi ý
  "arrow.uturn.backward",            // Auto-restore tiếng Anh
  "slider.horizontal.3",             // Chính sách khôi phục
  "character.book.closed",           // Từ điển tham chiếu
  "person.circle",                   // Từ điển cá nhân
  "pencil.and.outline",              // Quản lý từ điển cá nhân

  // Tab Macro
  "plus",                            // Thêm macro
  "trash",                           // Xoá
  "square.and.arrow.up",             // Xuất
  "square.and.arrow.down",           // Nhập

  // Tab Smart Switch
  "arrow.left.arrow.right.circle.fill", // Header SS
  "app.dashed",                      // App row placeholder
  "plus.circle",                     // Add quick preset
  "checkmark.circle.fill",           // Preset added marker
  "terminal",                        // Terminal preset
  "terminal.fill",                   // Terminal variant
  "curlybraces",                     // VS Code preset
  "hammer",                          // Xcode preset
  "hat.3",                           // (other preset)
  "magnifyingglass",                 // Spotlight preset
  "magnifyingglass.circle",          // Raycast preset

  // Tab Thống kê
  "chart.bar",                       // Stats toggle
  "arrow.triangle.merge",            // Run sync
  "shippingbox.and.arrow.backward",  // Auto backup on upgrade

  // Onboarding / Guide / Upgrade
  "1.circle.fill",
  "2.circle.fill",
  "3.circle.fill",
  "arrow.right",
  "checkmark",
  "exclamationmark.triangle.fill",
  "gear.badge",
  "gear.badge.checkmark",
  "arrow.clockwise",
]

let pointSizes: [(suffix: String, points: CGFloat)] = [
  ("32",  32),
  ("64",  64),
  ("96",  96),
]

let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  .appendingPathComponent("Tools/icon-set-templates")

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

var success = 0
var failed: [String] = []

for symbol in symbols {
  let symbolDir = outDir.appendingPathComponent(symbol)
  try? FileManager.default.createDirectory(at: symbolDir, withIntermediateDirectories: true)

  guard let baseImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else {
    failed.append(symbol)
    continue
  }

  for (suffix, pt) in pointSizes {
    let pixelSize = pt  // logical pt; we render at 2x retina implicitly via .preferredSize
    let config = NSImage.SymbolConfiguration(pointSize: pt, weight: .regular, scale: .large)
    let img = baseImage.withSymbolConfiguration(config) ?? baseImage

    // Render to bitmap at retina 2x.
    let scale: CGFloat = 2
    let pixels = NSSize(width: pixelSize * scale, height: pixelSize * scale)
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(pixels.width),
      pixelsHigh: Int(pixels.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bitmapFormat: [],
      bytesPerRow: 0,
      bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    img.draw(in: rect, from: NSRect(origin: .zero, size: img.size),
             operation: .sourceOver, fraction: 1.0,
             respectFlipped: true, hints: nil)

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
      failed.append("\(symbol):\(suffix)")
      continue
    }
    let outURL = symbolDir.appendingPathComponent("\(symbol)-\(suffix).png")
    do {
      try pngData.write(to: outURL)
    } catch {
      failed.append("\(symbol):\(suffix)")
      continue
    }
  }
  success += 1
}

print("\(success) symbols exported successfully.")
if !failed.isEmpty {
  print("Failed: \(failed.count) — \(failed.prefix(10).joined(separator: ", "))")
}
print("Output: \(outDir.path)")
