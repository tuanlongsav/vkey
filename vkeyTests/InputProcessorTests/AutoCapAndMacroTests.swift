import XCTest
import Defaults
@testable import vkey

final class AutoCapitalizeTests: XCTestCase {
  func testAutoCapitalizeAfterEnterSwallowsLowercaseKeyEvent() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 36) // Enter
    let result = typeLetter(processor, code: 0) // a
    XCTAssertSwallowed(result, "Auto-capitalize must synthesize uppercase, not pass lowercase key")
    XCTAssertEqual(processor.transformed, "A")
  }

  func testAutoCapitalizeAfterPeriodAndSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 49) // space
    let result = typeLetter(processor, code: 7) // x
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "X")
  }

  func testAutoCapitalizeDoesNotCapitalizeImmediatelyAfterPeriodWithoutSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    let result = typeLetter(processor, code: 17) // t
    XCTAssertPassThrough(result, "No space after period → pass-through lowercase")
    XCTAssertEqual(processor.transformed, "t")
  }

  func testAutoCapitalizeDoesNotCapitalizeImmediatelyAfterExclamationWithoutSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 18, shift: true) // !
    let result = typeLetter(processor, code: 17) // t
    XCTAssertPassThrough(result)
    XCTAssertEqual(processor.transformed, "t")
  }

  func testAutoCapitalizeDoesNotCapitalizeImmediatelyAfterQuestionWithoutSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 44, shift: true) // ?
    let result = typeLetter(processor, code: 17) // t
    XCTAssertPassThrough(result)
    XCTAssertEqual(processor.transformed, "t")
  }

  func testAutoCapitalizeAfterExclamationAndSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 18, shift: true) // !
    typeKey(processor, code: 49) // space
    let result = typeLetter(processor, code: 7) // x
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "X")
  }

  func testAutoCapitalizeAfterQuestionAndSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 44, shift: true) // ?
    typeKey(processor, code: 49) // space
    let result = typeLetter(processor, code: 7) // x
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "X")
  }

  func testAutoCapitalizeAfterPeriodAndDoubleSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 49) // space
    typeKey(processor, code: 49) // second space
    let result = typeLetter(processor, code: 7) // x
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "X")
  }

  func testAutoCapitalizePreservesDecimalNumbers() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 20) // 3
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 18) // 1
    XCTAssertEqual(processor.transformed, "1")
    typeKey(processor, code: 21) // 4
    XCTAssertEqual(processor.transformed, "14")
  }

  func testAutoCapitalizePreservesAbbreviationWithoutSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 46) // m
    typeKey(processor, code: 15) // r
    typeKey(processor, code: 47) // .
    let result = typeLetter(processor, code: 1) // s (mr.smith)
    XCTAssertPassThrough(result, "No space after period → pass-through lowercase")
    XCTAssertEqual(processor.transformed, "s")
  }

  func testAutoCapitalizeAfterPeriodAndEnter() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 36) // Enter
    let result = typeLetter(processor, code: 17) // t
    XCTAssertSwallowed(result, "Enter after period still marks sentence start")
    XCTAssertEqual(processor.transformed, "T")
  }

  func testAutoCapitalizeVietnameseAfterPeriodAndSpace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()
    typeKey(processor, code: 47) // .
    typeKey(processor, code: 49) // space
    let result = typeLetter(processor, code: 9) // v
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "V")
  }

  func testAutoCapitalizePreservesDomainSegments() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }
    let processor = makeNotesProcessor()

    for code: UInt16 in [5, 31, 31, 5, 37, 14] { typeKey(processor, code: code) }
    XCTAssertEqual(processor.transformed, "google")

    typeKey(processor, code: 47) // .
    typeKey(processor, code: 8) // c
    XCTAssertEqual(processor.transformed, "c", "First letter after dot must stay lowercase")
    typeKey(processor, code: 31) // o
    typeKey(processor, code: 46) // m
    XCTAssertEqual(processor.transformed, "com")

    typeKey(processor, code: 47) // .
    typeKey(processor, code: 9) // v
    XCTAssertEqual(processor.transformed, "v", "Second dot segment must stay lowercase")
    typeKey(processor, code: 45) // n
    XCTAssertEqual(processor.transformed, "vn")
  }

  /// v4.23 (P4): nhánh auto-capitalize phải phát KẾT QUẢ ENGINE, không phát ký
  /// tự thô vừa viết hoa.
  ///
  /// Nhánh cũ gửi thẳng `[newChar]` với giả định "engine không bao giờ đụng ký
  /// tự ĐẦU của từ". Giả định đó SAI khi `allowedZWJF` tắt: Telex cổ điển biến
  /// `w` đứng một mình thành `ư`. Khi đó lệnh gửi đi là "W" trong khi bộ đệm
  /// tin rằng màn hình có "Ư" — mà event gốc đã bị nuốt (`return nil`) — nên
  /// mọi phím sau diff trên nền sai và cả từ hỏng.
  ///
  /// PHẠM VI: `sendTypedReplacement` là private và transport post CGEvent thật,
  /// nên test không đọc được chuỗi đã phát. Cái khoá được ở đây là ĐIỀU KIỆN
  /// TIÊN QUYẾT của lỗi (engine thật sự đổi ký tự đầu) cùng cặp
  /// `lastTransformed → transformed` mà nhánh mới lấy diff, và số học của diff
  /// đó khác hẳn ký tự thô.
  func testAutoCapitalizeEmitsEngineResultNotRawKey() throws {
    let savedZWJF = Defaults[.allowedZWJF]
    Defaults[.autoCapitalizeEnabled] = true
    Defaults[.allowedZWJF] = false
    defer {
      Defaults.reset(.autoCapitalizeEnabled)
      Defaults[.allowedZWJF] = savedZWJF
    }

    let processor = makeNotesProcessor()
    typeKey(processor, code: 36) // Enter → chờ viết hoa
    let result = typeLetter(processor, code: 13) // w
    XCTAssertSwallowed(result, "Auto-capitalize nuốt event gốc — vkey phải tự phát")

    XCTAssertEqual(processor.transformed, "Ư",
      "Telex cổ điển: 'W' đầu từ thành 'Ư' — engine ĐỤNG vào ký tự đầu")
    XCTAssertEqual(processor.lastTransformed, "",
      "Diff phải lấy từ trạng thái TRƯỚC push (rỗng ở đầu từ)")

    let (backspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: processor.lastTransformed, to: processor.transformed, usesNFC: true)
    XCTAssertEqual(backspaces, 0)
    XCTAssertEqual(diffChars, ["Ư"], "Phải phát 'Ư' — nhánh cũ phát 'W' và lệch đệm")
    XCTAssertNotEqual(diffChars, ["W"])
  }

  /// Shift kẹt sau chữ hoa tự tổng hợp không được viết hoa ký tự thứ hai,
  /// và cờ Shift trên event trả về app phải bị gỡ (Backspace khi đó mới xoá được).
  func testSpuriousShiftDoesNotCapitalizeSecondLetterOrStickToBackspace() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }

    let processor = makeNotesProcessor()
    processor.hardwareShiftDown = false
    typeKey(processor, code: 36) // Enter

    let first = typeLetter(processor, code: 9) // v
    XCTAssertSwallowed(first)
    XCTAssertEqual(processor.transformed, "V")

    let secondEvent = CGEvent(keyboardEventSource: nil, virtualKey: 34, keyDown: true)! // i
    secondEvent.flags = .maskShift
    let second = processor.handleEvent(event: secondEvent)
    XCTAssertPassThrough(second)
    XCTAssertFalse(secondEvent.flags.contains(.maskShift),
      "Shift kẹt phải được gỡ trước khi trả event về app")
    XCTAssertEqual(processor.transformed, "Vi",
      "Chỉ ký tự đầu câu được viết hoa")

    let backspace = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: true)!
    backspace.flags = .maskShift
    let deleted = processor.handleEvent(event: backspace)
    XCTAssertPassThrough(deleted, "Xoá một chữ Latin thô để app tự xử lý")
    XCTAssertFalse(backspace.flags.contains(.maskShift),
      "Backspace không được đi kèm Shift kẹt")
    XCTAssertEqual(processor.transformed, "V")
  }

  /// `applyUnicodePayload` phải đặt mã phím về đúng `KeyCode.unicodeOnly` bất
  /// kể constructor dựng event bằng mã nào, và chuỗi Unicode phải gắn được.
  ///
  /// Bản v4.32 của test này khoá mã phím vào 0xFF theo giả thuyết "Chromium
  /// chèn cả ký tự của mã phím". Phép đo 09/10/2026 bác bỏ giả thuyết đó và
  /// cho thấy 0xFF làm app bỏ CẢ event (xem `UnicodeOnlyKeyCodeTests` và
  /// `KeyCode.unicodeOnly`), nên test không khoá vào một con số nữa.
  func testUnicodeInjectionNormalisesTheKeyCodeAndKeepsTheString() throws {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: 34, keyDown: true)!  // i
    let units = Array("V".utf16).map { UniChar($0) }
    EventSimulator.applyUnicodePayload(event, units: units)
    XCTAssertEqual(
      event.getIntegerValueField(.keyboardEventKeycode),
      Int64(EventSimulator.KeyCode.unicodeOnly),
      "mọi đường gửi chữ phải dùng cùng một mã phím, không phải mã constructor")
    var length = 0
    var buffer = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(
      maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
    XCTAssertEqual(Array(buffer[0..<length]), units, "chuỗi Unicode phải còn nguyên trên event")
  }

  /// Từ không phải tiếng Việt không được dài hơn số phím đã gõ ở bất kỳ bước nào.
  func testNonVietnameseWordsNeverExceedKeyCount() throws {
    let engine = Telex()
    for word in ["google", "footer", "book", "tools", "scheme", "text", "look", "password"] {
      var buffer = WordBuffer()
      for (i, c) in word.enumerated() {
        buffer.push(char: c, engine: engine)
        XCTAssertLessThanOrEqual(
          buffer.transformed.count, i + 1,
          "'\(word)' sau '\(word.prefix(i + 1))' ra '\(buffer.transformed)'"
        )
      }
    }
  }

  /// Đối chứng P4: ca thường (engine không đụng ký tự đầu) phải cho ra ĐÚNG
  /// một ký tự như trước — công thức mới không được làm phình diff.
  func testAutoCapitalizeOrdinaryLetterStillEmitsSingleChar() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }

    let processor = makeNotesProcessor()
    typeKey(processor, code: 36) // Enter
    let result = typeLetter(processor, code: 9) // v
    XCTAssertSwallowed(result)
    XCTAssertEqual(processor.transformed, "V")

    let (backspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: processor.lastTransformed, to: processor.transformed, usesNFC: true)
    XCTAssertEqual(backspaces, 0)
    XCTAssertEqual(diffChars, ["V"])
  }

  // MARK: - Auto-capitalize helpers
  // CGEvent virtualKey codes below assume US keyboard layout (KeyboardUS).
  //
  // Never use XCTAssertNotNil / XCTAssertNil directly on `Unmanaged<CGEvent>?` —
  // XCTest bridges the value for failure messages and can SIGABRT the test host.

  private func XCTAssertPassThrough(
    _ result: Unmanaged<CGEvent>?,
    _ message: @autoclosure () -> String = "Expected CGEvent pass-through",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(result != nil, message(), file: file, line: line)
  }

  private func XCTAssertSwallowed(
    _ result: Unmanaged<CGEvent>?,
    _ message: @autoclosure () -> String = "Expected CGEvent to be swallowed",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(result == nil, message(), file: file, line: line)
  }

  private func makeNotesProcessor() -> InputProcessor {
    let processor = InputProcessor(method: .Telex)
    processor.changeActiveApp("com.apple.Notes")
    return processor
  }

  private func typeKey(
    _ processor: InputProcessor,
    code: UInt16,
    shift: Bool = false
  ) {
    _ = typeKeyReturning(processor, code: code, shift: shift)
  }

  @discardableResult
  private func typeKeyReturning(
    _ processor: InputProcessor,
    code: UInt16,
    shift: Bool = false
  ) -> Unmanaged<CGEvent>? {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
    event.flags = shift ? [.maskShift] : []
    return processor.handleEvent(event: event)
  }

  @discardableResult
  private func typeLetter(
    _ processor: InputProcessor,
    code: UInt16
  ) -> Unmanaged<CGEvent>? {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
    event.flags = []
    return processor.handleEvent(event: event)
  }

  /// v3.6: diff NFD không bao giờ được mở đầu bằng combining mark trần —
  /// nếu có, ranh giới lùi về đầu cụm grapheme (xoá + retype nguyên cụm).
}

final class MacroReplacementTests: SpellResetTestCase {
  // MARK: - Macro Replacement Tests

  func testMacroReplacementWithSpace() throws {
    let macros = [Macro(from: "dc", to: "địa chỉ")]
    let replacement = InputProcessor.macroReplacement(
      for: "dc",
      endingChar: " ",
      macros: macros,
      usesNFC: true
    )

    XCTAssertEqual(replacement?.backspaceCount, 2)
    XCTAssertEqual(String(replacement?.diffChars ?? []), "địa chỉ ")
  }

  func testMacroReplacementWithPunctuation() throws {
    let macros = [Macro(from: "email", to: "long@example.com")]
    let replacement = InputProcessor.macroReplacement(
      for: "email",
      endingChar: ".",
      macros: macros,
      usesNFC: true
    )

    XCTAssertEqual(replacement?.backspaceCount, 5)
    XCTAssertEqual(String(replacement?.diffChars ?? []), "long@example.com.")
  }

  func testMacroReplacementNoMatch() throws {
    let macros = [Macro(from: "dc", to: "địa chỉ")]

    XCTAssertNil(InputProcessor.macroReplacement(
        for: "dt", endingChar: " ", macros: macros, usesNFC: true))
  }

  func testMacroReplacementIgnoresEmptyCurrentAndFields() throws {
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "",
        endingChar: " ",
        macros: [Macro(from: "dc", to: "địa chỉ")],
        usesNFC: true
      )
    )
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "dc",
        endingChar: " ",
        macros: [Macro(from: "", to: "địa chỉ")],
        usesNFC: true
      )
    )
    XCTAssertNil(
      InputProcessor.macroReplacement(
        for: "dc",
        endingChar: " ",
        macros: [Macro(from: "dc", to: "")],
        usesNFC: true
      )
    )
  }

  /// Macro phải dùng CHUNG trục diff với mọi path thay-thế khác: grapheme cho
  /// field NFC, scalar NFD cho field NFD (Chromium/Electron/Slack). Trigger có
  /// dấu là chỗ hai trục lệch nhau — "tớ" là 2 grapheme nhưng 4 scalar NFD
  /// (t + o + ◌̛ + ◌́). Dùng số đếm của trục sai thì field NFD xoá thiếu và sót
  /// ký tự rơi lại trước phần macro bung ra.
  func testMacroReplacementFollowsFieldAxis() throws {
    let macros = [Macro(from: "tớ", to: "tôi")]

    // Diff chung giữ nguyên tiền tố chung "t" thay vì xoá trọn từ.
    let nfc = InputProcessor.macroReplacement(
      for: "tớ", endingChar: " ", macros: macros, usesNFC: true)
    XCTAssertEqual(nfc?.backspaceCount, 1, "Field NFC: grapheme, chung tiền tố 't'")
    XCTAssertEqual(String(nfc?.diffChars ?? []), "ôi ")

    let nfd = InputProcessor.macroReplacement(
      for: "tớ", endingChar: " ", macros: macros, usesNFC: false)
    XCTAssertEqual(nfd?.backspaceCount, 3, "Field NFD: scalar o+◌̛+◌́ sau tiền tố 't'")

    // Mô phỏng field NFD, KHÔNG chuẩn hoá kết quả — để sai lệch dạng lộ ra.
    func replayNFDField(_ r: (backspaceCount: Int, diffChars: [Character])?) -> String {
      var field = Array("tớ".decomposedStringWithCanonicalMapping.unicodeScalars)
      guard let r else { return String(String.UnicodeScalarView(field)) }
      field.removeLast(min(r.backspaceCount, field.count))
      // Field NFD nhận đúng dạng mà sendReplacement sẽ phát ra.
      let emitted = EventSimulator.emittedCharacters(
        r.diffChars, normalizeToNFC: r.backspaceCount == nfc?.backspaceCount)
      field.append(contentsOf: String(emitted).unicodeScalars)
      return String(String.UnicodeScalarView(field))
    }

    XCTAssertEqual(
      replayNFDField(nfd), "tôi ".decomposedStringWithCanonicalMapping,
      "Trục NFD dựng lại đúng 'tôi ' ở dạng NFD của field")
    XCTAssertEqual(
      replayNFDField(nfc).precomposedStringWithCanonicalMapping, "tơôi ",
      "Trục NFC áp lên field NFD xoá thiếu 1 scalar → sót 'ơ' (bug đã vá)")
  }

  /// Trigger ASCII (đại đa số macro) phải giữ nguyên hành vi trên cả hai trục —
  /// grapheme và scalar bằng nhau nên diff không đổi.
  func testMacroReplacementIdenticalForASCIITrigger() throws {
    let macros = [Macro(from: "dc", to: "địa chỉ")]
    for usesNFC in [true, false] {
      let r = InputProcessor.macroReplacement(
        for: "dc", endingChar: " ", macros: macros, usesNFC: usesNFC)
      XCTAssertEqual(r?.backspaceCount, 2, "Trigger ASCII: xoá 2 dù trục nào")
      XCTAssertEqual(String(r?.diffChars ?? []), "địa chỉ ")
    }
  }

  func testCommitReplacementTargetIncludesEndingWhenCallerSwallowsIt() throws {
    XCTAssertEqual(
      InputProcessor.commitReplacementTarget(
        word: "of",
        endingChar: " ",
        includeEndingChar: true
      ),
      "of "
    )
    XCTAssertEqual(
      InputProcessor.commitReplacementTarget(
        word: "of",
        endingChar: ".",
        includeEndingChar: true
      ),
      "of."
    )
    XCTAssertEqual(
      InputProcessor.commitReplacementTarget(
        word: "of",
        endingChar: ".",
        includeEndingChar: false
      ),
      "of"
    )
  }

}

// MARK: - ===========================================
// MARK: - v4.23 — Macro bung được sau khi auto-capitalize viết hoa trigger
// MARK: - ===========================================
final class MacroCaseInsensitiveV423Tests: XCTestCase {

  /// P7 — auto-capitalize viết hoa chữ đầu câu TRƯỚC khi macro được tra, mà
  /// toàn bộ macro seed sẵn đều chữ thường và CẢ HAI tính năng đều bật mặc
  /// định. Ở đầu mỗi câu/dòng "vn" đã thành "Vn", `"vn" != "Vn"` nên macro
  /// không bao giờ bung: ra "Vn " thay vì "Việt Nam ". Giữa câu thì bung bình
  /// thường — nên lỗi chỉ lộ ở đầu câu và rất dễ bị bỏ qua.
  func testP7_MacroExpandsWhenTriggerWasAutoCapitalized() throws {
    let macros = [Macro(from: "vn", to: "Việt Nam")]
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "vn", endingChar: " ", macros: macros),
      "Việt Nam ", "chữ thường: bung như trước")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Vn", endingChar: " ", macros: macros),
      "Việt Nam ", "đầu câu (auto-capitalize) cũng phải bung")
  }

  /// P7 — KỲ VỌNG ĐÃ SỬA (v4.24). Bản gốc khoá `"VN"` → `"VIỆT NAM "`, tức khoá
  /// đúng cái HỒI QUY (R4): nó là hệ quả của khớp-bỏ-qua-hoa/thường cộng với
  /// `matchCase` viết HOA TOÀN BỘ, và nó nuốt mọi viết tắt người Việt gõ HOA CÓ
  /// CHỦ Ý. Kỳ vọng cũ → mới: `"VIỆT NAM "` thành `nil`.
  ///
  /// Lỗi P7 cần vá chỉ đòi biến thể hoa-CHỮ-ĐẦU (thứ auto-capitalize thật sự tạo
  /// ra ở đầu câu), nên khớp thu hẹp về đúng `autoCapitalizedVariant`. Muốn
  /// all-caps bung thì khai macro all-caps riêng — nhánh khớp CHÍNH XÁC phục vụ
  /// đúng việc đó (`testP7_ExactCaseMacroWinsOverCaseInsensitiveMatch`).
  func testP7_AllCapsTriggerDoesNotExpand() throws {
    let macros = [Macro(from: "vn", to: "Việt Nam")]
    XCTAssertNil(
      InputProcessor.macroTarget(for: "VN", endingChar: " ", macros: macros),
      "ALL-CAPS là viết tắt có chủ ý, không phải trigger bị auto-capitalize")
    // Đối chứng đi kèm: biến thể hoa-CHỮ-ĐẦU vẫn bung, và `matchCase` vẫn lo
    // phần bung cho nó — nửa fix gốc của P7 không được mất theo.
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Vn", endingChar: " ", macros: macros),
      "Việt Nam ")
  }

  /// R4 [chiều HỒI QUY] — đo trên ĐÚNG bảng macro mà user thật có
  /// (`DefaultMacros.allDefaults`, seed sẵn cho mọi máy mới). Khớp
  /// bỏ-qua-hoa/thường biến mọi viết tắt gõ HOA thành macro: "PM " (giờ chiều /
  /// Project Manager) → "± ", "VN " → "VIỆT NAM ", "HN " → "HÀ NỘI ",
  /// "CTY " → "CÔNG TY ", "ARR " → "→", "DEG " → "°". Trước v4.23 chúng đi qua
  /// nguyên vẹn — đây là chữ BIẾN MẤT khỏi văn bản người dùng, không phải tính
  /// năng.
  func testR4_AllCapsAbbreviationsPassThroughUnexpanded() throws {
    let macros = DefaultMacros.allDefaults
    for trigger in ["PM", "VN", "HN", "SG", "CTY", "ARR", "DEG", "GTE"] {
      XCTAssertNil(
        InputProcessor.macroTarget(for: trigger, endingChar: " ", macros: macros),
        "\(trigger) gõ HOA là viết tắt có chủ ý — không được bung macro")
    }
  }

  /// R4 [chiều FIX GỐC] — nửa còn lại của P7 phải sống: biến thể hoa-CHỮ-ĐẦU
  /// (đầu câu, sau khi auto-capitalize viết hoa trigger) vẫn bung, chữ thường
  /// giữa câu vẫn bung. Cộng thêm ranh giới của chính `autoCapitalizedVariant`,
  /// vì đó là chỗ duy nhất quyết định "biến thể nào được nhận".
  func testR4_AutoCapitalizedVariantStillExpands() throws {
    let macros = DefaultMacros.allDefaults
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "vn", endingChar: " ", macros: macros),
      "Việt Nam ", "giữa câu (chữ thường) — đường vốn đã chạy")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Vn", endingChar: " ", macros: macros),
      "Việt Nam ", "đầu câu (auto-capitalize) — chính là lỗi P7 đã vá")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Hn", endingChar: " ", macros: macros), "Hà Nội ")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Cty", endingChar: " ", macros: macros), "Công ty ")
    // Phần bung không có chữ cái thì `matchCase` không đụng được gì.
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "Pm", endingChar: " ", macros: macros), "± ")

    // Ranh giới: CHỈ viết hoa chữ đầu, và chỉ khi trigger mở đầu bằng chữ thường.
    XCTAssertEqual(InputProcessor.autoCapitalizedVariant(of: "vn"), "Vn")
    XCTAssertEqual(InputProcessor.autoCapitalizedVariant(of: "tphcm"), "Tphcm")
    XCTAssertNil(InputProcessor.autoCapitalizedVariant(of: "VN"),
      "trigger đã viết hoa thì auto-capitalize không tạo ra được biến thể nào")
    XCTAssertNil(InputProcessor.autoCapitalizedVariant(of: ""))
  }

  /// P7 — khớp CHÍNH XÁC phải được thử TRƯỚC. Người dùng có quyền khai hai
  /// macro chỉ khác hoa/thường; mỗi cái phải giữ phần bung riêng của mình.
  func testP7_ExactCaseMacroWinsOverCaseInsensitiveMatch() throws {
    let macros = [
      Macro(from: "vn", to: "Việt Nam"),
      Macro(from: "VN", to: "Vietnam Ltd"),
    ]
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "VN", endingChar: " ", macros: macros),
      "Vietnam Ltd ", "khớp chính xác thắng, KHÔNG được matchCase thành ALL-CAPS")
    XCTAssertEqual(
      InputProcessor.macroTarget(for: "vn", endingChar: " ", macros: macros),
      "Việt Nam ")
  }

  /// Đối chứng P7: không có macro nào khớp thì vẫn trả nil (không được vì nới
  /// hoa/thường mà bung nhầm), và macro rỗng bị bỏ qua như cũ.
  func testP7_NoMatchAndEmptyMacrosStillReturnNil() throws {
    let macros = [Macro(from: "vn", to: "Việt Nam")]
    XCTAssertNil(InputProcessor.macroTarget(for: "vni", endingChar: " ", macros: macros))
    XCTAssertNil(InputProcessor.macroTarget(for: "", endingChar: " ", macros: macros))
    XCTAssertNil(InputProcessor.macroTarget(
      for: "vn", endingChar: " ", macros: [Macro(from: "vn", to: "")]))
  }
}
