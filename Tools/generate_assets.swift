#!/usr/bin/env swift

//
// generate_assets.swift
//
// Sinh app icon "Vkey" + cờ VN/US cho menu bar + Cficon imageset cho UI.
// Chạy: swift Tools/generate_assets.swift
//
// Output:
//   vkey/Assets.xcassets/AppIcon.appiconset/icon-mac-*.png      (10 files)
//   vkey/Assets.xcassets/Cficon.imageset/icon-mac-128x128*.png  (2 files)
//   vkey/Assets.xcassets/vn-flag.imageset/vn-flag*.png          (3 files + Contents.json)
//   vkey/Assets.xcassets/us-flag.imageset/us-flag*.png          (3 files + Contents.json)
//
// Note: uses CGContext directly (not NSImage) so pixel size is exactly the
// requested size — NSImage on Retina causes 2× backing scale that breaks
// AppIcon validation.
//

import AppKit
import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// MARK: - Color helpers

extension CGColor {
  static func hex(_ hex: UInt32, alpha: CGFloat = 1.0) -> CGColor {
    CGColor(
      red: CGFloat((hex >> 16) & 0xFF) / 255.0,
      green: CGFloat((hex >> 8) & 0xFF) / 255.0,
      blue: CGFloat(hex & 0xFF) / 255.0,
      alpha: alpha
    )
  }
}

let vnRed = CGColor.hex(0xDA251D)
let vnRedLight = CGColor.hex(0xFF4033)
let vnYellow = CGColor.hex(0xFFFF00)
let usRed = CGColor.hex(0xB22234)
let usWhite = CGColor.hex(0xFFFFFF)
let usBlue = CGColor.hex(0x3C3B6E)

// MARK: - Paths

let fileManager = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let projectRoot = scriptURL.deletingLastPathComponent()
let assetsRoot = projectRoot
  .appendingPathComponent("vkey")
  .appendingPathComponent("Assets.xcassets")
let appIconDir = assetsRoot.appendingPathComponent("AppIcon.appiconset")
let cficonDir = assetsRoot.appendingPathComponent("Cficon.imageset")
let vnFlagDir = assetsRoot.appendingPathComponent("vn-flag.imageset")
let usFlagDir = assetsRoot.appendingPathComponent("us-flag.imageset")

// MARK: - Render at exact pixel size

func makeContext(width: Int, height: Int) -> CGContext {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  guard
    let ctx = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else {
    fatalError("Cannot create CGContext \(width)×\(height)")
  }
  return ctx
}

func savePNG(_ image: CGImage, to url: URL) throws {
  guard
    let dest = CGImageDestinationCreateWithURL(
      url as CFURL,
      UTType.png.identifier as CFString,
      1,
      nil
    )
  else {
    throw NSError(domain: "generate_assets", code: 1)
  }
  CGImageDestinationAddImage(dest, image, nil)
  if !CGImageDestinationFinalize(dest) {
    throw NSError(domain: "generate_assets", code: 2)
  }
}

func render(width: Int, height: Int, draw: (CGContext, CGSize) -> Void) -> CGImage {
  let ctx = makeContext(width: width, height: height)
  draw(ctx, CGSize(width: width, height: height))
  guard let img = ctx.makeImage() else {
    fatalError("makeImage failed")
  }
  return img
}

func resize(_ source: CGImage, to size: CGSize) -> CGImage {
  let ctx = makeContext(width: Int(size.width), height: Int(size.height))
  ctx.interpolationQuality = .high
  ctx.draw(source, in: CGRect(origin: .zero, size: size))
  return ctx.makeImage()!
}

// MARK: - App icon (red squircle + "Vkey" text)

func drawAppIcon(ctx: CGContext, size: CGSize) {
  let rect = CGRect(origin: .zero, size: size)
  let cornerRadius = size.width * 0.2237

  // Background with rounded corners
  let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
  ctx.addPath(path)
  ctx.setFillColor(vnRed)
  ctx.fillPath()

  // Vertical gradient highlight (top → lighter red)
  ctx.saveGState()
  ctx.addPath(path)
  ctx.clip()
  let cs = CGColorSpaceCreateDeviceRGB()
  let gradient = CGGradient(
    colorsSpace: cs,
    colors: [vnRedLight, vnRed] as CFArray,
    locations: [0, 1]
  )!
  ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size.height),
    end: CGPoint(x: 0, y: 0),
    options: []
  )
  ctx.restoreGState()

  // Text "Vkey" — Core Text for exact metric control
  let text = "Vkey"
  let fontSize = size.width * 0.40
  let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
  let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .kern: -fontSize * 0.025,
  ]
  let attrString = NSAttributedString(string: text, attributes: attrs)
  let line = CTLineCreateWithAttributedString(attrString)
  let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

  let textX = (size.width - bounds.width) / 2 - bounds.origin.x
  let textY = (size.height - bounds.height) / 2 - bounds.origin.y - size.width * 0.01

  // Drop shadow
  ctx.saveGState()
  ctx.setShadow(
    offset: CGSize(width: 0, height: -size.width * 0.012),
    blur: size.width * 0.02,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.30)
  )
  ctx.textPosition = CGPoint(x: textX, y: textY)
  CTLineDraw(line, ctx)
  ctx.restoreGState()
}

// MARK: - VN flag

func drawVNFlag(ctx: CGContext, size: CGSize) {
  // Rounded-corner clip for a softer menu bar look
  let radius = min(size.width, size.height) * 0.15
  let clipPath = CGPath(
    roundedRect: CGRect(origin: .zero, size: size),
    cornerWidth: radius, cornerHeight: radius, transform: nil
  )
  ctx.addPath(clipPath)
  ctx.clip()

  ctx.setFillColor(vnRed)
  ctx.fill(CGRect(origin: .zero, size: size))

  // 5-pointed star, height = 0.78 × min dimension — large enough to be obvious
  let starHeight = min(size.width, size.height) * 0.78
  let cx = size.width / 2
  let cy = size.height / 2
  let outerR = starHeight / 2
  let innerR = outerR * 0.382  // golden ratio

  let path = CGMutablePath()
  for i in 0..<10 {
    let angle = CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 5
    let r = (i % 2 == 0) ? outerR : innerR
    let p = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
  }
  path.closeSubpath()

  ctx.addPath(path)
  ctx.setFillColor(vnYellow)
  ctx.fillPath()
}

// MARK: - US flag

func drawUSFlag(ctx: CGContext, size: CGSize) {
  // Rounded-corner clip
  let radius = min(size.width, size.height) * 0.15
  let clipPath = CGPath(
    roundedRect: CGRect(origin: .zero, size: size),
    cornerWidth: radius, cornerHeight: radius, transform: nil
  )
  ctx.addPath(clipPath)
  ctx.clip()

  ctx.setFillColor(usWhite)
  ctx.fill(CGRect(origin: .zero, size: size))

  // 13 stripes, 7 red (rows 0,2,4,6,8,10,12 from top)
  let stripeH = size.height / 13.0
  ctx.setFillColor(usRed)
  for i in 0..<13 where i % 2 == 0 {
    let y = size.height - stripeH * CGFloat(i + 1)
    ctx.fill(CGRect(x: 0, y: y, width: size.width, height: stripeH))
  }

  // Canton: 7 stripes tall, 0.4 × width wide
  let cantonH = stripeH * 7
  let cantonW = size.width * 0.4
  let cantonRect = CGRect(x: 0, y: size.height - cantonH, width: cantonW, height: cantonH)
  ctx.setFillColor(usBlue)
  ctx.fill(cantonRect)

  // Simplified 5×4 grid of white dots (50 stars unreadable at 22px)
  let cols = 5, rows = 4
  let starDia = min(cantonW / CGFloat(cols + 1), cantonH / CGFloat(rows + 1)) * 0.6
  let xs = cantonW / CGFloat(cols)
  let ys = cantonH / CGFloat(rows)
  ctx.setFillColor(usWhite)
  for r in 0..<rows {
    for c in 0..<cols {
      let x = xs * (CGFloat(c) + 0.5) - starDia / 2
      let y = cantonRect.minY + ys * (CGFloat(r) + 0.5) - starDia / 2
      ctx.fillEllipse(in: CGRect(x: x, y: y, width: starDia, height: starDia))
    }
  }
}

// MARK: - Writers

func writeAppIcon() throws {
  let master = render(width: 1024, height: 1024, draw: drawAppIcon)
  let sizes: [(String, Int)] = [
    ("icon-mac-16x16.png", 16),
    ("icon-mac-16x16@2x.png", 32),
    ("icon-mac-32x32.png", 32),
    ("icon-mac-32x32@2x.png", 64),
    ("icon-mac-128x128.png", 128),
    ("icon-mac-128x128@2x.png", 256),
    ("icon-mac-256x256.png", 256),
    ("icon-mac-256x256@2x.png", 512),
    ("icon-mac-512x512.png", 512),
    ("icon-mac-512x512@2x.png", 1024),
  ]
  for (name, px) in sizes {
    let img = resize(master, to: CGSize(width: px, height: px))
    try savePNG(img, to: appIconDir.appendingPathComponent(name))
    print("  AppIcon/\(name) \(px)×\(px)")
  }

  // Cficon imageset: reuse 128 + 256 (same as @1x/@2x of mac 128 slot)
  try savePNG(resize(master, to: CGSize(width: 128, height: 128)),
              to: cficonDir.appendingPathComponent("icon-mac-128x128.png"))
  try savePNG(resize(master, to: CGSize(width: 256, height: 256)),
              to: cficonDir.appendingPathComponent("icon-mac-128x128@2x.png"))
  print("  Cficon/* 128, 256")
}

func writeFlag(dir: URL, name: String, base: CGSize, drawer: (CGContext, CGSize) -> Void) throws {
  try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

  let s3 = CGSize(width: base.width * 3, height: base.height * 3)
  let master = render(width: Int(s3.width), height: Int(s3.height), draw: drawer)
  try savePNG(master, to: dir.appendingPathComponent("\(name)@3x.png"))
  try savePNG(resize(master, to: CGSize(width: base.width * 2, height: base.height * 2)),
              to: dir.appendingPathComponent("\(name)@2x.png"))
  try savePNG(resize(master, to: base), to: dir.appendingPathComponent("\(name).png"))

  let contents = """
    {
      "images" : [
        { "filename" : "\(name).png", "idiom" : "universal", "scale" : "1x" },
        { "filename" : "\(name)@2x.png", "idiom" : "universal", "scale" : "2x" },
        { "filename" : "\(name)@3x.png", "idiom" : "universal", "scale" : "3x" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
  try contents.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
  print("  \(dir.lastPathComponent) @1x=\(Int(base.width))×\(Int(base.height))")
}

// MARK: - Main

do {
  print("== Generating assets ==")
  try writeAppIcon()
  // Rectangular base — softer/wider look, both flags same height to align on menu bar.
  try writeFlag(dir: vnFlagDir, name: "vn-flag", base: CGSize(width: 24, height: 16), drawer: drawVNFlag)
  try writeFlag(dir: usFlagDir, name: "us-flag", base: CGSize(width: 22, height: 14), drawer: drawUSFlag)
  print("✓ done")
} catch {
  fputs("error: \(error)\n", stderr)
  exit(1)
}
