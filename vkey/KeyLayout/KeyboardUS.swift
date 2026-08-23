import Cocoa

/// Maps a physical macOS key code to the character that key occupies on a
/// US QWERTY layout. Physical key codes are stable across input sources, so this
/// also works for non-QWERTY layouts (QWERTZ, AZERTY, Dvorak…): the user types
/// using the QWERTY position regardless of the legend on the key cap. This is
/// the desired behavior for Telex/VNI, whose rules (s, f, r, x, j, w…) are
/// defined relative to the US QWERTY positions.
class KeyboardUS {
  private let keyMap: [Int64: (ascii: Character, shiftAscii: Character)]
  private let taskMap: [Int64: TaskKey]

  init() {
    // Initialize the key map with US keyboard layout
    keyMap = [
      // Numbers
      29: ("0", ")"),  // 0 key
      18: ("1", "!"),  // 1 key
      19: ("2", "@"),  // 2 key
      20: ("3", "#"),  // 3 key
      21: ("4", "$"),  // 4 key
      23: ("5", "%"),  // 5 key
      22: ("6", "^"),  // 6 key
      26: ("7", "&"),  // 7 key
      28: ("8", "*"),  // 8 key
      25: ("9", "("),  // 9 key
      // Letters
      0: ("a", "A"),  // A key
      11: ("b", "B"),  // B key
      8: ("c", "C"),  // C key
      2: ("d", "D"),  // D key
      14: ("e", "E"),  // E key
      3: ("f", "F"),  // F key
      5: ("g", "G"),  // G key
      4: ("h", "H"),  // H key
      34: ("i", "I"),  // I key
      38: ("j", "J"),  // J key
      40: ("k", "K"),  // K key
      37: ("l", "L"),  // L key
      46: ("m", "M"),  // M key
      45: ("n", "N"),  // N key
      31: ("o", "O"),  // O key
      35: ("p", "P"),  // P key
      12: ("q", "Q"),  // Q key
      15: ("r", "R"),  // R key
      1: ("s", "S"),  // S key
      17: ("t", "T"),  // T key
      32: ("u", "U"),  // U key
      9: ("v", "V"),  // V key
      13: ("w", "W"),  // W key
      7: ("x", "X"),  // X key
      16: ("y", "Y"),  // Y key
      6: ("z", "Z"),  // Z key
      // Punctuation and special characters
      50: ("`", "~"),  // Backquote key
      27: ("-", "_"),  // Minus key
      24: ("=", "+"),  // Equal key
      33: ("[", "{"),  // Left bracket key
      30: ("]", "}"),  // Right bracket key
      42: ("\\", "|"),  // Backslash key
      41: (";", ":"),  // Semicolon key
      39: ("'", "\""),  // Quote key
      43: (",", "<"),  // Comma key
      47: (".", ">"),  // Period key
      44: ("/", "?"),  // Slash key
      // Keypad numbers — Shift KHÔNG biến keypad thành ký hiệu trên macOS,
      // vẫn ra chữ số (khác hàng phím số phía trên).
      82: ("0", "0"),
      83: ("1", "1"),
      84: ("2", "2"),
      85: ("3", "3"),
      86: ("4", "4"),
      87: ("5", "5"),
      88: ("6", "6"),
      89: ("7", "7"),
      91: ("8", "8"),
      92: ("9", "9"),
      // Dấu câu trên bàn phím số. Không map thì phím đi qua nguyên trạng: app
      // chèn ký tự mà buffer vẫn giữ từ cũ → ký tự kế tiếp diff với
      // `lastTransformed` đã lệch → backspace ăn ngược vào chữ đã gõ. Map vào
      // keyMap là đủ: mọi ký tự này đều nằm trong `NewWordKeys` nên
      // `handleTextChar` tự `newWord()`.
      // Mã đối chiếu Carbon/HIToolbox Events.h (kVK_ANSI_Keypad*).
      65: (".", "."),  // 0x41 KeypadDecimal
      67: ("*", "*"),  // 0x43 KeypadMultiply
      69: ("+", "+"),  // 0x45 KeypadPlus
      75: ("/", "/"),  // 0x4B KeypadDivide
      78: ("-", "-"),  // 0x4E KeypadMinus
      81: ("=", "="),  // 0x51 KeypadEquals
    ]

    taskMap = [
      36: .Enter,  // 0x24 kVK_Return
      // 0x34: KHÔNG có trong Events.h — mã Enter của bàn phím PowerBook đời cũ,
      // thừa kế từ các bảng keycode cộng đồng. Giữ vì vô hại (chỉ `newWord()`),
      // nhưng nó KHÔNG phải Enter bàn phím số.
      52: .Enter,
      // Enter bàn phím số THẬT = 0x4C kVK_ANSI_KeypadEnter. Thiếu mã này thì
      // `mapTask`/`mapText` đều nil → phím đi qua nguyên trạng: app xuống dòng
      // mà buffer vẫn giữ "tiếng" → ký tự đầu dòng mới diff với
      // `lastTransformed` cũ → backspace phát NGƯỢC LÊN dòng trước, phá chữ.
      76: .Enter,
      48: .Tab,  // 0x30 kVK_Tab
      49: .Space,  // 0x31 kVK_Space
      51: .Delete,  // 0x33 kVK_Delete (backspace)
      53: .Escape,  // 0x35 kVK_Escape
      // Move
      115: .Home,  // 0x73 kVK_Home
      119: .End,  // 0x77 kVK_End
      // Page Up/Down dời con trỏ y như Home/End nên cũng phải cắt từ, không thì
      // buffer đứng lại ở vị trí cũ → ký tự gõ tiếp diff với `lastTransformed`
      // của chỗ cũ và backspace ăn vào chữ ở vị trí mới.
      //
      // KHÔNG mượn `.ArrowUp`/`.ArrowDown` (bản vá trước làm vậy): mũi tên lên/
      // xuống là ứng viên số một cho một xử lý riêng trong tương lai (điều
      // hướng HUD gợi ý / chọn candidate), và khi đó Page Up sẽ đi nhờ theo,
      // gây lỗi rất khó truy vì bảng keycode chẳng liên quan gì tới HUD.
      // `.Home`/`.End` là chỗ mượn ít rủi ro nhất: cùng nằm trong
      // `JumpTaskKeys` (xử lý y hệt: `newWord()` + huỷ chờ viết hoa), cùng
      // nghĩa "nhảy con trỏ một quãng lớn" — Page Up lùi về đầu, Page Down
      // tiến về cuối — và không phím nào trong hai phím này là ứng viên cho
      // xử lý đặc thù của bộ gõ.
      // Đúng bài thì `TaskKey` cần thêm `.PageUp`/`.PageDown`, nhưng việc đó
      // phải sửa CẢ `KeyLayout/Keys.swift` lẫn `InputProcessor.JumpTaskKeys` —
      // thêm case mà quên đưa vào `JumpTaskKeys` thì phím rơi hết nhánh
      // `handleTaskKey` và KHÔNG cắt từ nữa, tức tệ hơn hiện tại.
      116: .Home,  // 0x74 kVK_PageUp
      121: .End,  // 0x79 kVK_PageDown
      // Arrow keys
      123: .ArrowLeft,
      124: .ArrowRight,
      125: .ArrowDown,
      126: .ArrowUp,
      // Function keys
      122: .F1,
      120: .F2,
      99: .F3,
      118: .F4,
      96: .F5,
      97: .F6,
      98: .F7,
      100: .F8,
      101: .F9,
      109: .F10,
      103: .F11,
      111: .F12,
    ]
  }

  func mapText(keyCode: Int64, withShift shift: Bool) -> Character? {
    guard let key = keyMap[keyCode] else { return nil }
    return shift ? key.shiftAscii : key.ascii
  }

  func mapTask(keyCode: Int64) -> TaskKey? {
    guard let key = taskMap[keyCode] else { return nil }
    return key
  }

  func isNumberKey(keyCode: Int64) -> Bool {
    // Number keys: 0-9 and Keypad 0-9
    return [29, 18, 19, 20, 21, 23, 22, 26, 28, 25,
            82, 83, 84, 85, 86, 87, 88, 89, 91, 92].contains(keyCode)
  }

  /// Caps Lock chỉ ảnh hưởng phím chữ cái — số, keypad, dấu câu giữ nguyên.
  func isLetterKey(keyCode: Int64) -> Bool {
    guard let key = keyMap[keyCode] else { return false }
    return key.ascii.isLetter
  }
}
