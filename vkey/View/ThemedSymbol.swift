//
//  ThemedSymbol.swift
//  vkey
//
//  Wrapper hiển thị icon theo `Defaults[.appTheme]`. Thay cho
//  `Image(systemName:)` ở mọi nơi không phải là menu bar state flag /
//  AppIcon (giữ nguyên flag VN/US PNG và AppIcon mặc định).
//
//  Ba theme:
//
//  - `.default`: render SF Symbol gốc, không hiệu ứng.
//  - `.threeD` (default ở 1.5.4+): ưu tiên bitmap PDF ở
//    `Assets.xcassets/Icons3D/<name>` nếu có; nếu không, runtime
//    fallback: SF Symbol + 4-stop gradient + double shadow +
//    `.hierarchical` rendering — "bóng bẩy" 3D.
//  - `.emoji` (mới ở 1.5.6): thay SF Symbol bằng Unicode emoji
//    tương ứng (vd `gearshape` → ⚙️, `lightbulb` → 💡). Map ở
//    `Self.emojiFor(_:)` bên dưới. Nếu không có mapping, fallback
//    về SF Symbol gốc.
//
//  Đối với `Label(_, systemImage:)`, dùng extension
//  `Label(_, themedSymbol:)` thay vì wrap thủ công.
//

import AppKit
import Defaults
import SwiftUI

struct ThemedSymbol: View {
  let name: String
  @Default(.appTheme) private var theme
  // v2.3.2: read UI theme để áp dụng category color cho Liquid Glass.
  // LG menu items có mỗi icon 1 màu (per design `MenuItem icon color`).
  // Các theme khác (Tonal/Classic) inherit accent từ `.tint()` ở root.
  @Default(.uiTheme) private var uiTheme

  // v2.3.3: opt-in glass tile wrap. Set qua `.environment(\.useGlassTile, true)`
  // ở MenuContentView + Settings root. MenuBarLabel status icon + HUD KHÔNG
  // set → giữ flat SF Symbol (match macOS menu bar conventions).
  @Environment(\.useGlassTile) private var useGlassTile

  /// v2.3.3: SF Symbol name → `GlassTileColor` cho LG theme.
  /// Mapping match design `SpecSheets.jsx` (Icon system grouped by function).
  private static func liquidGlassTileColor(for name: String) -> GlassTileColor {
    switch name {
    // Brand / on-state
    case "keyboard", "keyboard.badge.ellipsis", "character.bubble.fill":
      return .red
    case "globe", "paintbrush", "paintpalette", "power":
      return .red
    // Suggestion / warning / lightbulb
    case "sparkles", "lightbulb", "lightbulb.fill", "rocket",
         "cup.and.saucer", "heart.fill":
      return .gold
    case "chart.bar", "chart.bar.doc.horizontal":
      return .gold
    // Smart Switch / language toggle / info
    case "arrow.left.arrow.right.square",
         "arrow.left.arrow.right.circle",
         "arrow.left.arrow.right.circle.fill",
         "app.dashed", "switch", "switch.2":
      return .blue
    case "info.circle", "text.cursor.ibeam":
      return .blue
    // Spell / check / success / refresh
    case "checkmark", "checkmark.circle", "checkmark.circle.fill",
         "text.badge.checkmark", "shield", "shield.fill":
      return .green
    case "arrow.triangle.2.circlepath", "arrow.clockwise", "tray":
      return .green
    // Macro / wand / text cursor (purple)
    case "text.cursor", "abc", "character", "textformat",
         "wand.and.stars", "wand.and.rays":
      return .purple
    // Destructive / lock / system (ink — dark)
    case "lock", "lock.square", "lock.fill",
         "nosign", "gear.badge.questionmark", "trash":
      return .ink
    // Settings / structural (gray)
    case "gear", "gearshape", "ellipsis", "arrow.right",
         "magnifyingglass", "plus.circle", "plus", "minus":
      return .gray
    default:
      return .gray
    }
  }

  /// v2.3.2: SF Symbol name → category color khi LG theme active.
  /// Mapping bám sát design `MenuBar.jsx`:
  ///   red — flag VN, brand, dangerous (Thoát)
  ///   blue — switch, info, statistics
  ///   green — check, refresh, spell-check
  ///   purple — wand/Macro
  ///   gold — paintbrush/Giao diện, lightbulb/Ủng hộ
  ///   gray — gear, keyboard, default
  /// Trả nil nếu icon không có category → inherit parent .tint().
  private static func liquidGlassCategoryColor(for name: String) -> Color? {
    switch name {
    case "arrow.left.arrow.right.square",
         "arrow.left.arrow.right.circle",
         "switch":
      return Color(hex: 0x2D89E5)  // blue — Smart Switch / language toggle
    case "checkmark.circle",
         "check.circle",
         "text.badge.checkmark":
      return Color(hex: 0x2BB673)  // green — spell check
    case "arrow.triangle.2.circlepath",
         "arrow.clockwise":
      return Color(hex: 0x2BB673)  // green — refresh/update
    case "text.cursor":
      return Color(hex: 0x8B5CF6)  // purple — Macro
    case "paintbrush", "paintpalette":
      return Color(hex: 0xF5C645)  // gold — theme picker
    case "cup.and.saucer", "heart.fill", "lightbulb":
      return Color(hex: 0xF5C645)  // gold — donate/support
    case "info.circle", "chart.bar.doc.horizontal":
      return Color(hex: 0x2D89E5)  // blue — info/stats
    case "power":
      return Color(hex: 0xE04434)  // red — Thoát (dangerous)
    case "gear", "gearshape":
      return Color(hex: 0x9CA3AF)  // gray — settings
    case "keyboard", "keyboard.badge.ellipsis":
      return Color(hex: 0x9CA3AF)  // gray — typing method
    case "character.bubble.fill":
      return Color(hex: 0xE04434)  // red — VI active
    case "globe":
      return Color(hex: 0xF5C645)  // gold — globe/language
    default:
      return nil
    }
  }

  /// Apply LG category color if available, else nil = inherit parent tint.
  private var liquidGlassTintOverride: Color? {
    guard uiTheme == .liquidGlass else { return nil }
    return Self.liquidGlassCategoryColor(for: name)
  }

  var body: some View {
    // v2.3.4: 4-cấp render priority — Tonal cũng wrap khi env opt-in,
    // dùng `TonalRowIcon` (flat sunken tile + red accent) thay vì
    // GlassTile (3D glass).
    //  (1) LG + useGlassTile=true → GlassTile (per design MenuBar.jsx)
    //  (2) Tonal + useGlassTile=true → TonalRowIcon (per design .row__icon)
    //  (3) LG only — không env (MenuBarLabel status icon) → flat SF Symbol
    //      với hierarchical category color (v2.3.2 behavior)
    //  (4) Tonal only / Classic → themedBody (appTheme-driven)
    if uiTheme == .liquidGlass && useGlassTile {
      GlassTile(color: Self.liquidGlassTileColor(for: name), size: 24) {
        Image(systemName: name)
          .font(.system(size: 13, weight: .regular))
      }
    } else if uiTheme == .tonal && useGlassTile {
      TonalRowIcon(size: 24) {
        Image(systemName: name)
          .font(.system(size: 13, weight: .regular))
      }
    } else {
      Group {
        themedBody
      }
      .modifier(LiquidGlassTintModifier(color: liquidGlassTintOverride))
    }
  }

  @ViewBuilder
  private var themedBody: some View {
    switch theme {
    case .default:
      Image(systemName: name)
    case .threeD:
      if NSImage(named: "Icons3D/\(name)") != nil {
        Image("Icons3D/\(name)")
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        // 4-stop gradient mô phỏng ball lighting + double shadow
        // (accent halo + black drop) cho cảm giác "nổi 3D".
        Image(systemName: name)
          .symbolRenderingMode(.hierarchical)
          .symbolVariant(.fill)
          .foregroundStyle(
            LinearGradient(
              stops: [
                .init(color: .accentColor,                      location: 0.0),
                .init(color: .accentColor.opacity(0.85),        location: 0.30),
                .init(color: .accentColor.opacity(0.55),        location: 0.70),
                .init(color: .accentColor.opacity(0.80),        location: 1.0),
              ],
              startPoint: .top, endPoint: .bottom
            )
          )
          .shadow(color: .accentColor.opacity(0.35), radius: 4, x: 0, y: 2)
          .shadow(color: .black.opacity(0.20),       radius: 1, x: 0, y: 0.5)
      }
    case .emoji:
      if let glyph = Self.emojiFor(name),
         let img = Self.emojiImage(for: glyph) {
        // KHÔNG dùng `.resizable()` để Image render ở natural size
        // (18pt) cố định trong mọi context. Tránh layout stretch khi
        // parent unconstrained (vd HStack header trong SmartSwitchView
        // làm icon phình to). Caller muốn size khác có thể wrap explicit
        // `.frame()` — nhưng default 18pt match approximate SF Symbol
        // body baseline.
        Image(nsImage: img)
      } else {
        // Fallback nếu thiếu mapping HOẶC render NSImage fail.
        Image(systemName: name)
      }
    }
  }

  // MARK: - Emoji → NSImage rendering (1.5.7+)

  /// Cache emoji glyph → NSImage để tránh redraw mỗi lần. Key bao gồm
  /// `pointSize` để các kích thước khác nhau không đụng nhau.
  private static let emojiImageCache = NSCache<NSString, NSImage>()

  /// Render Unicode emoji glyph thành NSImage để dùng làm icon.
  ///
  /// **Vì sao cần thế?** SwiftUI `Text` view khi đặt vào Label's icon
  /// slot bị NSMenuExtra translate nhầm thành NSMenuItem.title — kết
  /// quả: title biến mất, chỉ thấy emoji. NSImage thì map clean vào
  /// NSMenuItem.image slot, title gốc giữ nguyên.
  ///
  /// `pointSize=18` cân bằng giữa các context: hơi lớn hơn body
  /// baseline (~13pt) cho dễ nhìn nhưng không quá to phá layout khi
  /// parent unconstrained (vd Smart Switch tab header với HStack
  /// không có frame). Nếu sau này cần emoji to hơn cho onboarding,
  /// caller có thể truyền pointSize lớn hơn — nhưng phải kèm
  /// `.frame(width:height:)` để giới hạn rendering.
  private static func emojiImage(for emoji: String, pointSize: CGFloat = 18) -> NSImage? {
    let cacheKey = "\(emoji)_\(Int(pointSize))" as NSString
    if let cached = emojiImageCache.object(forKey: cacheKey) {
      return cached
    }

    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: pointSize)
    ]
    let attrStr = NSAttributedString(string: emoji, attributes: attrs)
    let textSize = attrStr.size()
    // Pad nhỏ để emoji có outline / shadow không bị crop.
    let imgSize = NSSize(
      width: ceil(textSize.width) + 2,
      height: ceil(textSize.height) + 2
    )

    let img = NSImage(size: imgSize, flipped: false) { _ in
      attrStr.draw(at: NSPoint(x: 1, y: 1))
      return true
    }
    // KHÔNG template — emoji phải giữ màu thật, không bị tint mono.
    img.isTemplate = false

    emojiImageCache.setObject(img, forKey: cacheKey)
    return img
  }

  /// Map SF Symbol name → Unicode emoji glyph. Bao phủ ~60 symbol vkey
  /// đang dùng. Nếu thiếu mapping, caller nhận `nil` và fallback về
  /// `Image(systemName:)` gốc.
  static func emojiFor(_ name: String) -> String? {
    switch name {
    // Menu Bar
    case "arrow.left.arrow.right.square":     return "🔄"
    case "keyboard":                          return "⌨️"
    case "keyboard.badge.ellipsis":           return "⌨️"
    case "gearshape":                         return "⚙️"
    case "arrow.left.arrow.right.circle":     return "🔁"
    case "arrow.left.arrow.right.circle.fill":return "🔁"
    case "checkmark.circle":                  return "✅"
    case "checkmark.circle.fill":             return "✅"
    case "text.cursor":                       return "📝"
    case "cup.and.saucer":                    return "☕"
    case "info.circle":                       return "ℹ️"
    case "arrow.triangle.2.circlepath":       return "🔄"
    case "power":                             return "🔌"

    // Menu bar state (sẽ không thực sự render qua ThemedSymbol nhưng
    // map sẵn cho an toàn nếu có nơi nào đó dùng nhầm)
    case "gear.badge.questionmark":           return "⚙️"
    case "lock.square":                       return "🔒"

    // Settings tabs
    case "gear":                              return "⚙️"
    case "text.badge.checkmark":              return "✅"
    case "chart.bar.doc.horizontal":          return "📊"

    // Tab Chung
    case "arrow.up.right.square":             return "🚀"
    case "abc":                               return "🔤"
    case "character":                         return "🔠"
    case "sparkles":                          return "✨"
    case "macwindow.badge.plus":              return "🪟"
    case "textformat":                        return "🅰️"
    case "command":                           return "⌘"

    // Tab Chính tả
    case "text.justify.left":                 return "📃"
    case "lightbulb":                         return "💡"
    case "lightbulb.fill":                    return "💡"
    case "wand.and.stars":                    return "🪄"
    case "arrow.uturn.backward":              return "↩️"
    case "slider.horizontal.3":               return "🎚️"
    case "character.book.closed":             return "📖"
    case "person.circle":                     return "👤"
    case "person.crop.circle.badge.checkmark":return "👤"
    case "pencil.and.outline":                return "✏️"
    case "book":                              return "📚"
    case "arrow.down.circle":                 return "⬇️"

    // Tab Macro
    case "plus":                              return "➕"
    case "trash":                             return "🗑️"
    case "square.and.arrow.up":               return "📤"
    case "square.and.arrow.down":             return "📥"

    // Tab Smart Switch
    case "app.dashed":                        return "📱"
    case "plus.circle":                       return "➕"
    case "terminal":                          return "💻"
    case "terminal.fill":                     return "💻"
    case "curlybraces":                       return "🔧"
    case "hammer":                            return "🔨"
    case "hat.3":                             return "🎩"
    case "magnifyingglass":                   return "🔍"
    case "magnifyingglass.circle":            return "🔍"

    // Tab Thống kê
    case "chart.bar":                         return "📊"
    case "arrow.triangle.merge":              return "🔀"
    case "shippingbox.and.arrow.backward":    return "📦"

    // Onboarding / Guide / Upgrade
    case "1.circle.fill":                     return "1️⃣"
    case "2.circle.fill":                     return "2️⃣"
    case "3.circle.fill":                     return "3️⃣"
    case "arrow.right":                       return "➡️"
    case "checkmark":                         return "✓"
    case "exclamationmark.triangle.fill":     return "⚠️"
    case "gear.badge":                        return "⚙️"
    case "gear.badge.checkmark":              return "✅"
    case "arrow.clockwise":                   return "🔄"

    // Theme picker submenu
    case "paintbrush":                        return "🎨"
    case "circle":                            return "⚪"
    case "cube":                              return "🧊"

    // Additional Views & HUD Symbols
    case "arrow.up.and.down":                 return "↕️"
    case "envelope.fill":                     return "✉️"
    case "tray.full":                         return "📥"
    case "rectangle.stack.badge.plus":        return "🗂️"
    case "list.bullet":                       return "📋"
    case "stethoscope":                       return "🩺"
    case "tray":                              return "📥"
    case "person.fill":                       return "👤"
    case "lock.fill":                         return "🔒"
    case "nosign":                            return "🚫"

    // 1.8.2: Menu bar state + HUD icons
    case "gear.badge.questionmark":           return "⚙️"
    case "lock.square":                       return "🔒"
    case "character.bubble.fill":             return "💬"
    case "keyboard":                          return "⌨️"

    default:                                  return nil
    }
  }
}

/// v2.3.2: ViewModifier applying explicit foregroundStyle when LG theme
/// has a per-category color for this icon. Khi `color = nil`, identity —
/// để theme khác (Tonal/Classic) giữ `.tint()` inheritance bình thường.
/// Override symbolRenderingMode to `.hierarchical` để LG icons có gradient
/// nhẹ thay vì flat fill — match design `.tile` look (sphere lighting).
private struct LiquidGlassTintModifier: ViewModifier {
  let color: Color?

  func body(content: Content) -> some View {
    if let color {
      content
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(color)
    } else {
      content
    }
  }
}

extension Label where Title == Text, Icon == ThemedSymbol {
  /// Drop-in thay cho `Label(_, systemImage:)`. Icon render qua
  /// `ThemedSymbol` để tự đổi theo `Defaults[.appTheme]`.
  init(_ title: String, themedSymbol name: String) {
    self.init {
      Text(title)
    } icon: {
      ThemedSymbol(name: name)
    }
  }
}
