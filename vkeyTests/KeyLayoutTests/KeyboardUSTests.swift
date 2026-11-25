import XCTest
@testable import vkey

// MARK: - ===========================================
// MARK: - KeyboardUS Layout Tests
// MARK: - ===========================================

/// Tests for the US keyboard layout key-code → character mapping.
/// Guards against regressions when adding new layout support (QWERTZ/AZERTY).
final class KeyboardUSTests: XCTestCase {

  func testLetterMappingLowercase() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapText(keyCode: 0, withShift: false), "a")
    XCTAssertEqual(layout.mapText(keyCode: 6, withShift: false), "z")
    XCTAssertEqual(layout.mapText(keyCode: 16, withShift: false), "y")
    XCTAssertEqual(layout.mapText(keyCode: 38, withShift: false), "j")
  }

  func testLetterMappingShifted() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapText(keyCode: 0, withShift: true), "A")
    XCTAssertEqual(layout.mapText(keyCode: 6, withShift: true), "Z")
  }

  func testNumberRowMapping() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapText(keyCode: 18, withShift: false), "1")
    XCTAssertEqual(layout.mapText(keyCode: 18, withShift: true), "!")
    XCTAssertEqual(layout.mapText(keyCode: 29, withShift: false), "0")
    XCTAssertEqual(layout.mapText(keyCode: 29, withShift: true), ")")
  }

  func testPunctuationMapping() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapText(keyCode: 41, withShift: false), ";")
    XCTAssertEqual(layout.mapText(keyCode: 41, withShift: true), ":")
    XCTAssertEqual(layout.mapText(keyCode: 47, withShift: false), ".")
    XCTAssertEqual(layout.mapText(keyCode: 47, withShift: true), ">")
  }

  func testUnknownKeyCodeReturnsNil() throws {
    let layout = KeyboardUS()
    XCTAssertNil(layout.mapText(keyCode: 9999, withShift: false))
  }

  func testTaskKeyMapping() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapTask(keyCode: 36), .Enter)
    XCTAssertEqual(layout.mapTask(keyCode: 48), .Tab)
    XCTAssertEqual(layout.mapTask(keyCode: 49), .Space)
    XCTAssertEqual(layout.mapTask(keyCode: 51), .Delete)
    XCTAssertEqual(layout.mapTask(keyCode: 53), .Escape)
    XCTAssertEqual(layout.mapTask(keyCode: 123), .ArrowLeft)
    XCTAssertEqual(layout.mapTask(keyCode: 126), .ArrowUp)
    XCTAssertEqual(layout.mapTask(keyCode: 122), .F1)
    XCTAssertNil(layout.mapTask(keyCode: 0))
  }

  /// v4.23 (F4): Enter của BÀN PHÍM SỐ là 0x4C = 76 (`kVK_ANSI_KeypadEnter`)
  /// và trước đây KHÔNG có trong `taskMap` — `mapTask` lẫn `mapText` đều nil
  /// nên phím đi qua nguyên trạng: app xuống dòng mà bộ đệm vẫn giữ từ cũ, ký
  /// tự đầu dòng mới diff với `lastTransformed` của dòng trước → backspace phát
  /// NGƯỢC LÊN dòng trên. Mã 52 (0x34) từng được coi là "Enter bàn phím số"
  /// nhưng nó không có trong Events.h (Enter của PowerBook đời cũ) — giữ nhưng
  /// KHÔNG thay thế được 76.
  func testKeypadEnterMapsToEnterTaskKey() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapTask(keyCode: 76), .Enter,
      "0x4C kVK_ANSI_KeypadEnter phải cắt từ như Enter thường")
    XCTAssertNil(layout.mapText(keyCode: 76, withShift: false),
      "Enter bàn phím số không được map thành ký tự văn bản")
    // Hai mã Enter cũ vẫn nguyên vẹn.
    XCTAssertEqual(layout.mapTask(keyCode: 36), .Enter)
    XCTAssertEqual(layout.mapTask(keyCode: 52), .Enter)
  }

  /// v4.23 (F4) + v4.24: Page Up/Down (0x74 = 116, 0x79 = 121) dời con trỏ y hệt
  /// Home/End nên cũng phải cắt từ. `TaskKey` chưa có case riêng nên phải MƯỢN
  /// một case của nhóm `JumpTaskKeys` (cả nhóm chạy đúng một nhánh: `newWord()`
  /// + `resetSentenceCapitalizeState()`).
  ///
  /// KỲ VỌNG ĐÃ SỬA: v4.23 mượn `.ArrowUp`/`.ArrowDown` → nay `.Home`/`.End`.
  /// Mũi tên lên/xuống là ứng viên số một cho một xử lý riêng trong tương lai
  /// (điều hướng HUD gợi ý / chọn candidate); khi đó Page Up sẽ đi nhờ theo và
  /// gây lỗi rất khó truy vì bảng keycode chẳng liên quan gì tới HUD.
  /// `.Home`/`.End` cùng nghĩa "nhảy con trỏ một quãng lớn" (Page Up lùi về đầu,
  /// Page Down tiến về cuối) và không phím nào trong hai là ứng viên cho xử lý
  /// đặc thù của bộ gõ. Vẫn là MƯỢN — fix đúng bài phải thêm `.PageUp`/`.PageDown`
  /// vào `KeyLayout/Keys.swift` VÀ `InputProcessor.JumpTaskKeys` cùng lúc.
  func testPageUpDownMapToJumpTaskKeys() throws {
    let layout = KeyboardUS()
    XCTAssertEqual(layout.mapTask(keyCode: 116), .Home, "PageUp phải cắt từ")
    XCTAssertEqual(layout.mapTask(keyCode: 121), .End, "PageDown phải cắt từ")
    XCTAssertNotEqual(layout.mapTask(keyCode: 116), .ArrowUp,
      "KHÔNG mượn mũi tên: xử lý riêng cho .ArrowUp sau này sẽ tóm nhầm Page Up")
    XCTAssertNotEqual(layout.mapTask(keyCode: 121), .ArrowDown)
    // Điều kiện SỐNG CÒN của việc mượn: case được mượn phải nằm trong
    // `JumpTaskKeys`. Rơi khỏi danh sách đó là phím trượt hết mọi nhánh của
    // `handleTaskKey` và KHÔNG cắt từ nữa — tệ hơn cả trước khi map.
    for key in [TaskKey.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight] {
      XCTAssertTrue(InputProcessor.JumpTaskKeys.contains(key),
        "\(key) phải nằm trong JumpTaskKeys thì việc map mới có tác dụng")
    }
    // Home/End (đã có từ trước) không được đụng.
    XCTAssertEqual(layout.mapTask(keyCode: 115), .Home)
    XCTAssertEqual(layout.mapTask(keyCode: 119), .End)
  }

  /// v4.23 (F4): dấu câu trên bàn phím số. Không map thì phím đi qua nguyên
  /// trạng — app chèn ký tự trong khi bộ đệm vẫn giữ từ cũ → ký tự kế tiếp diff
  /// với `lastTransformed` đã lệch → backspace ăn ngược vào chữ đã gõ. Map vào
  /// `keyMap` là đủ vì mọi ký tự này đều nằm trong `NewWordKeys`.
  /// Keypad KHÔNG có biến thể shift trên macOS → hai chiều phải giống nhau.
  func testKeypadPunctuationMapsToCharacters() throws {
    let layout = KeyboardUS()
    let expected: [(Int64, Character)] = [
      (65, "."), (67, "*"), (69, "+"), (75, "/"), (78, "-"), (81, "="),
    ]
    for (code, want) in expected {
      XCTAssertEqual(layout.mapText(keyCode: code, withShift: false), want,
        "keypad \(code) phải ra '\(want)'")
      XCTAssertEqual(layout.mapText(keyCode: code, withShift: true), want,
        "keypad \(code) + Shift vẫn ra '\(want)' (keypad không có shift-variant)")
      XCTAssertNil(layout.mapTask(keyCode: code),
        "keypad \(code) là ký tự văn bản, không phải task key")
    }
    // Đối chứng: chữ số bàn phím số vẫn như cũ (VNI dùng chúng làm phím dấu).
    XCTAssertEqual(layout.mapText(keyCode: 82, withShift: false), "0")
    XCTAssertEqual(layout.mapText(keyCode: 92, withShift: false), "9")
  }

  func testIsNumberKey() throws {
    let layout = KeyboardUS()
    XCTAssertTrue(layout.isNumberKey(keyCode: 18)) // 1
    XCTAssertTrue(layout.isNumberKey(keyCode: 29)) // 0
    XCTAssertFalse(layout.isNumberKey(keyCode: 0)) // A
    XCTAssertFalse(layout.isNumberKey(keyCode: 49)) // Space
    
    // Keypad numbers
    XCTAssertTrue(layout.isNumberKey(keyCode: 83)) // Keypad 1
    XCTAssertTrue(layout.isNumberKey(keyCode: 82)) // Keypad 0
    XCTAssertEqual(layout.mapText(keyCode: 83, withShift: false), "1")
    // Shift + keypad vẫn ra chữ số trên macOS (không ra ký hiệu như hàng số)
    XCTAssertEqual(layout.mapText(keyCode: 83, withShift: true), "1")

    // isLetterKey: chỉ phím chữ cái (Caps Lock chỉ tác động nhóm này)
    XCTAssertTrue(layout.isLetterKey(keyCode: 0))   // A
    XCTAssertFalse(layout.isLetterKey(keyCode: 18)) // 1
    XCTAssertFalse(layout.isLetterKey(keyCode: 83)) // Keypad 1
    XCTAssertFalse(layout.isLetterKey(keyCode: 43)) // Comma
    XCTAssertFalse(layout.isLetterKey(keyCode: 49)) // Space
  }

  func testNumericKeypadVNI() throws {
    let processor = InputProcessor(method: .VNI)
    processor.newWord()
    
    // Simulate typing "a" (keycode 0)
    let eventA = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    _ = processor.handleEvent(event: eventA)
    XCTAssertEqual(processor.transformed, "a")
    
    // Simulate typing Keypad 1 (keycode 83)
    let eventKeypad1 = CGEvent(keyboardEventSource: nil, virtualKey: 83, keyDown: true)!
    _ = processor.handleEvent(event: eventKeypad1)
    XCTAssertEqual(processor.transformed, "á")
  }

  func testCapsLockAndShiftInteraction() throws {
    let processor = InputProcessor(method: .Telex)
    processor.newWord()
    
    // Case 1: Shift OFF, Caps Lock OFF -> lowercase "a"
    let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    event1.flags = []
    _ = processor.handleEvent(event: event1)
    XCTAssertEqual(processor.transformed, "a")
    processor.newWord()
    
    // Case 2: Shift ON, Caps Lock OFF -> uppercase "A"
    let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    event2.flags = [.maskShift]
    _ = processor.handleEvent(event: event2)
    XCTAssertEqual(processor.transformed, "A")
    processor.newWord()
    
    // Case 3: Shift OFF, Caps Lock ON -> uppercase "A"
    let event3 = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    event3.flags = [.maskAlphaShift]
    _ = processor.handleEvent(event: event3)
    XCTAssertEqual(processor.transformed, "A")
    processor.newWord()
    
    // Case 4: Shift ON, Caps Lock ON -> lowercase "a" (inversion)
    let event4 = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    event4.flags = [.maskShift, .maskAlphaShift]
    _ = processor.handleEvent(event: event4)
    XCTAssertEqual(processor.transformed, "a")
  }

  func testMeaningfulVietnamesePhraseFilter() {
    XCTAssertTrue(UsageStatistics.isMeaningfulVietnamesePhrase(["công", "ty"]))
    XCTAssertTrue(UsageStatistics.isMeaningfulVietnamesePhrase(["xin", "chào"]))
    XCTAssertFalse(UsageStatistics.isMeaningfulVietnamesePhrase(["hello", "world"]))
    XCTAssertFalse(UsageStatistics.isMeaningfulVietnamesePhrase(["asdf", "ghjk"]))
  }

}
