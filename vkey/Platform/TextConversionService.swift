//
//  TextConversionService.swift
//  vkey
//
//  2.0 (B4): Text Conversion Tools — bộ menu biến đổi selected text qua
//  clipboard round-trip:
//   - Đổi case: lower / UPPER / Title Case / Sentence case
//   - Bỏ dấu: "Tiếng Việt" → "Tieng Viet"
//   - Chuyển kiểu gõ raw: text VN → ký tự Telex/VNI để paste sang nơi khác
//
//  Phương thức: Cmd+C → đọc clipboard → transform → set lại clipboard
//  → Cmd+V. Không cần AX selected-text grab (đỡ permission). User cần
//  highlight text trước khi gọi hotkey.
//

import AppKit
import Foundation

@MainActor
final class TextConversionService {
  static let shared = TextConversionService()

  private init() {}

  enum Operation: String, CaseIterable {
    case lower
    case upper
    case title
    case sentence
    case removeDiacritics
    case toTelexRaw
    case toVNIRaw

    var label: String {
      switch self {
      case .lower: return "chữ thường"
      case .upper: return "CHỮ HOA"
      case .title: return "Title Case"
      case .sentence: return "Sentence case"
      case .removeDiacritics: return "Bỏ dấu"
      case .toTelexRaw: return "Sang raw Telex"
      case .toVNIRaw: return "Sang raw VNI"
      }
    }

    var icon: String {
      switch self {
      case .lower: return "textformat.abc"
      case .upper: return "textformat.abc.dottedunderline"
      case .title: return "textformat"
      case .sentence: return "text.alignleft"
      case .removeDiacritics: return "character"
      case .toTelexRaw: return "keyboard.fill"
      case .toVNIRaw: return "number"
      }
    }
  }

  /// Mở context menu cho user chọn operation. `near` = location của
  /// mouse hoặc cursor — nil sẽ dùng mouse position hiện tại.
  func openMenu(near point: NSPoint?) {
    let menu = NSMenu(title: "Text Tools")
    for op in Operation.allCases {
      let item = NSMenuItem(
        title: op.label,
        action: #selector(handleMenuSelect(_:)),
        keyEquivalent: ""
      )
      item.target = self
      item.representedObject = op.rawValue
      item.image = NSImage(systemSymbolName: op.icon, accessibilityDescription: nil)
      menu.addItem(item)
    }

    let location = point ?? NSEvent.mouseLocation
    menu.popUp(positioning: nil, at: location, in: nil)
  }

  @objc private func handleMenuSelect(_ sender: NSMenuItem) {
    guard let raw = sender.representedObject as? String,
          let op = Operation(rawValue: raw)
    else { return }
    applyToSelection(operation: op)
  }

  /// Áp dụng operation lên selection hiện tại của target app.
  /// Quy trình: Cmd+C → đợi clipboard → transform → set clipboard → Cmd+V.
  func applyToSelection(operation: Operation) {
    let pasteboard = NSPasteboard.general
    let originalChangeCount = pasteboard.changeCount
    let previousPasteboardItems = Self.snapshotPasteboard(pasteboard)

    // 1. Send Cmd+C để copy selection vào clipboard.
    sendCmdC()

    // 2. Đợi clipboard cập nhật (max 0.5s).
    let deadline = Date().addingTimeInterval(0.5)
    while pasteboard.changeCount == originalChangeCount && Date() < deadline {
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
    guard pasteboard.changeCount != originalChangeCount,
          let original = pasteboard.string(forType: .string),
          !original.isEmpty
    else {
      Self.restorePasteboard(pasteboard, items: previousPasteboardItems)
      NSSound.beep()
      return
    }

    // 3. Apply transform.
    let transformed = transform(original, operation: operation)

    // 4. Set lại clipboard và paste.
    pasteboard.clearContents()
    pasteboard.setString(transformed, forType: .string)
    let transformedChangeCount = pasteboard.changeCount

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      Self.sendCmdV()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        if pasteboard.changeCount == transformedChangeCount {
          Self.restorePasteboard(pasteboard, items: previousPasteboardItems)
        }
      }
    }
  }

  // MARK: - Transforms

  func transform(_ text: String, operation: Operation) -> String {
    switch operation {
    case .lower:
      return text.lowercased()
    case .upper:
      return text.uppercased()
    case .title:
      return titleCase(text)
    case .sentence:
      return sentenceCase(text)
    case .removeDiacritics:
      return removeDiacritics(text)
    case .toTelexRaw:
      return toTelexRaw(text)
    case .toVNIRaw:
      return toVNIRaw(text)
    }
  }

  private func titleCase(_ text: String) -> String {
    let parts = text.split(
      separator: " ",
      omittingEmptySubsequences: false
    )
    return parts.map { word -> String in
      guard let first = word.first else { return String(word) }
      return String(first).uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")
  }

  private func sentenceCase(_ text: String) -> String {
    var result = ""
    var capitalizeNext = true
    for ch in text {
      if capitalizeNext, ch.isLetter {
        result.append(Character(String(ch).uppercased()))
        capitalizeNext = false
      } else {
        result.append(Character(String(ch).lowercased()))
      }
      if ch == "." || ch == "!" || ch == "?" || ch == "\n" {
        capitalizeNext = true
      }
    }
    return result
  }

  private func removeDiacritics(_ text: String) -> String {
    // applyingTransform handles most diacritics. Special-case đ/Đ vì
    // stripDiacritics không chuyển — đó là consonant, không phải diacritic.
    let stripped = text.applyingTransform(.stripDiacritics, reverse: false) ?? text
    return stripped
      .replacingOccurrences(of: "đ", with: "d")
      .replacingOccurrences(of: "Đ", with: "D")
  }

  /// Chuyển text Việt thành raw Telex (vd "tiếng" → "tieengs").
  /// Thuật toán: với mỗi ký tự có dấu, tách thành base + tone-key + diacritic-key.
  private func toTelexRaw(_ text: String) -> String {
    var result = ""
    for ch in text {
      result.append(decomposeTelex(ch))
    }
    return result
  }

  /// Chuyển text Việt thành raw VNI (vd "tiếng" → "tieng61s").
  /// VNI: tone digits 1-5 sau base, diacritic 6/7/8/9 sau base.
  private func toVNIRaw(_ text: String) -> String {
    var result = ""
    for ch in text {
      result.append(decomposeVNI(ch))
    }
    return result
  }

  private func decomposeTelex(_ ch: Character) -> String {
    let map = Self.telexDecompositionMap
    return map[ch] ?? String(ch)
  }

  private func decomposeVNI(_ ch: Character) -> String {
    let map = Self.vniDecompositionMap
    return map[ch] ?? String(ch)
  }

  // MARK: - Decomposition tables

  /// Telex decomposition: ký tự có dấu → chuỗi phím gõ Telex tương ứng.
  /// Tone keys: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng.
  /// Diacritic: aw=ă, aa=â, ee=ê, oo=ô, ow=ơ, uw=ư, dd=đ.
  static let telexDecompositionMap: [Character: String] = {
    var m: [Character: String] = [:]
    // Vowels with tone marks
    let bases: [(base: String, withMu: String?, mu: String?)] = [
      ("a", nil, nil),
      ("ă", "aw", "aw"),
      ("â", "aa", "aa"),
      ("e", nil, nil),
      ("ê", "ee", "ee"),
      ("i", nil, nil),
      ("o", nil, nil),
      ("ô", "oo", "oo"),
      ("ơ", "ow", "ow"),
      ("u", nil, nil),
      ("ư", "uw", "uw"),
      ("y", nil, nil),
    ]
    let toneKeys: [(diacritic: String, key: String)] = [
      ("", ""),      // bằng
      ("\u{0301}", "s"), // sắc
      ("\u{0300}", "f"), // huyền
      ("\u{0309}", "r"), // hỏi
      ("\u{0303}", "x"), // ngã
      ("\u{0323}", "j"), // nặng
    ]
    for (base, withMu, _) in bases {
      let baseSeq = withMu ?? base
      for (combining, key) in toneKeys {
        let composed = (base + combining).precomposedStringWithCanonicalMapping
        if let ch = composed.first, composed.count == 1 {
          m[ch] = baseSeq + key
          // uppercase
          let upper = String(ch).uppercased()
          if let uCh = upper.first {
            m[uCh] = baseSeq.uppercased() + key
          }
        }
      }
    }
    // đ / Đ
    m["đ"] = "dd"
    m["Đ"] = "DD"
    return m
  }()

  /// VNI decomposition: ký tự có dấu → base + digit.
  /// Tones: 1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng.
  /// Diacritic: 6=â/ê/ô, 7=ơ/ư, 8=ă, 9=đ.
  static let vniDecompositionMap: [Character: String] = {
    var m: [Character: String] = [:]
    let bases: [(base: String, muDigit: String?)] = [
      ("a", nil),
      ("ă", "a8"),
      ("â", "a6"),
      ("e", nil),
      ("ê", "e6"),
      ("i", nil),
      ("o", nil),
      ("ô", "o6"),
      ("ơ", "o7"),
      ("u", nil),
      ("ư", "u7"),
      ("y", nil),
    ]
    let toneCombining: [(c: String, d: String)] = [
      ("", ""),
      ("\u{0301}", "1"),
      ("\u{0300}", "2"),
      ("\u{0309}", "3"),
      ("\u{0303}", "4"),
      ("\u{0323}", "5"),
    ]
    for (base, muDigit) in bases {
      let baseSeq = muDigit ?? base
      for (combining, digit) in toneCombining {
        let composed = (base + combining).precomposedStringWithCanonicalMapping
        if let ch = composed.first, composed.count == 1 {
          m[ch] = baseSeq + digit
          let upper = String(ch).uppercased()
          if let uCh = upper.first {
            m[uCh] = baseSeq.uppercased() + digit
          }
        }
      }
    }
    m["đ"] = "d9"
    m["Đ"] = "D9"
    return m
  }()

  // MARK: - Keystroke injection

  private func sendCmdC() {
    Self.sendKey(virtualKey: 0x08, withCommand: true)  // 0x08 = 'c'
  }

  static func sendCmdV() {
    sendKey(virtualKey: 0x09, withCommand: true)  // 0x09 = 'v'
  }

  static func sendKey(virtualKey: CGKeyCode, withCommand: Bool) {
    let source = CGEventSource(stateID: .combinedSessionState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
    let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
    if withCommand {
      down?.flags = .maskCommand
      up?.flags = .maskCommand
    }
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
  }

  private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
    guard let items = pasteboard.pasteboardItems else { return [] }
    return items.map { item in
      let copy = NSPasteboardItem()
      for type in item.types {
        if let data = item.data(forType: type) {
          copy.setData(data, forType: type)
        } else if let string = item.string(forType: type) {
          copy.setString(string, forType: type)
        }
      }
      return copy
    }
  }

  private static func restorePasteboard(
    _ pasteboard: NSPasteboard,
    items: [NSPasteboardItem]
  ) {
    pasteboard.clearContents()
    if !items.isEmpty {
      pasteboard.writeObjects(items)
    }
  }
}
