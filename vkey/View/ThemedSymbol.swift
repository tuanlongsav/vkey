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

  var body: some View {
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

    default:                                  return nil
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
