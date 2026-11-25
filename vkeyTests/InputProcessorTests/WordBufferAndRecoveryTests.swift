import XCTest
import Defaults
@testable import vkey

// MARK: - ===========================================
// MARK: - WordBuffer Tests
// MARK: - ===========================================

/// Tests for the WordBuffer struct that manages the word state during typing.
/// Covers push/pop/newWord lifecycle, recovery rollback, and previous-word restore.
final class WordBufferTests: XCTestCase {

  private func telexEngine() -> TypingMethod { Telex() }

  /// New buffer is blank and not in recovery.
  func testNewBufferIsEmpty() throws {
    let buffer = WordBuffer()
    XCTAssertTrue(buffer.keys.isEmpty)
    XCTAssertTrue(buffer.wordState.isBlank)
    XCTAssertEqual(buffer.transformed, "")
    XCTAssertFalse(buffer.stopProcessing)
    XCTAssertNil(buffer.previousWordState)
  }

  /// push accumulates raw keys and updates transformed.
  func testPushAccumulatesKeysAndTransforms() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chaof" {
      buffer.push(char: char, engine: engine)
    }
    XCTAssertEqual(String(buffer.keys), "chaof")
    XCTAssertEqual(buffer.transformed, "chào")
    XCTAssertFalse(buffer.stopProcessing)
  }

  /// newWord clears all state but keeps engine reusable.
  func testNewWordClearsState() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chaof" { buffer.push(char: char, engine: engine) }
    XCTAssertEqual(buffer.transformed, "chào")

    buffer.newWord()
    XCTAssertTrue(buffer.keys.isEmpty)
    XCTAssertEqual(buffer.transformed, "")
    XCTAssertNil(buffer.previousWordState)
    XCTAssertFalse(buffer.stopProcessing)
  }

  /// newWord(storePrevious: true) preserves the prior word so backspace can restore it.
  func testNewWordStoresPrevious() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chaof" { buffer.push(char: char, engine: engine) }
    let prior = buffer.transformed

    buffer.newWord(storePrevious: true)
    XCTAssertNotNil(buffer.previousWordState, "previousWordState should be retained")
    XCTAssertEqual(buffer.previousWordState?.transformed, prior)
  }

  /// pop on empty buffer with a previous word restores that word.
  func testPopRestoresPreviousWord() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chaof" { buffer.push(char: char, engine: engine) }
    buffer.newWord(storePrevious: true)

    let (backspaces, diff) = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(backspaces, 0, "OS handles the backspace that triggered restore")
    XCTAssertTrue(diff.isEmpty)
    XCTAssertEqual(buffer.transformed, "chào")
    XCTAssertNil(buffer.previousWordState, "previousWordState consumed on restore")
  }

  /// Single-step rollback: after recovery, a backspace returns to the last valid state.
  func testRecoveryRollbackUndoesRecovery() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "hoof" { buffer.push(char: char, engine: engine) }
    XCTAssertEqual(buffer.transformed, "hồ")
    XCTAssertFalse(buffer.stopProcessing)

    // Typing 'z' triggers recovery (invalid Vietnamese syllable continuation).
    buffer.push(char: "z", engine: engine)
    XCTAssertTrue(buffer.stopProcessing)
    XCTAssertEqual(buffer.transformed, "hoofz")

    // First pop should rollback the recovery, restoring "hồ".
    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertFalse(buffer.stopProcessing)
    XCTAssertEqual(buffer.transformed, "hồ")
  }

  /// Pop without prior recovery removes the last character normally.
  func testPopRemovesLastChar() throws {
    var buffer = WordBuffer()
    let engine = telexEngine()
    for char in "chao" { buffer.push(char: char, engine: engine) }
    XCTAssertEqual(buffer.transformed, "chao")

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "cha")
    XCTAssertEqual(String(buffer.keys), "cha")
  }
}


// MARK: - ===========================================
// MARK: - v4.23 — Backspace / replay ở tầng WordBuffer
// MARK: - ===========================================
final class WordBufferReplayV423Tests: XCTestCase {

  private var savedZWJF = true
  private var savedAutoTypo = true
  private var savedNewStyle = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedAutoTypo = Defaults[.autoTypoCorrection]
    savedNewStyle = Defaults[.newStyleTonePlacement]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    // Chốt cấu hình mặc định: kỳ vọng dưới đây đo ở đúng cấu hình này. Bộ test
    // KHÔNG chạy song song nên phải tự pin thay vì tin vào thứ tự lớp.
    Defaults[.allowedZWJF] = true
    Defaults[.autoTypoCorrection] = true
    Defaults[.newStyleTonePlacement] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.autoTypoCorrection] = savedAutoTypo
    Defaults[.newStyleTonePlacement] = savedNewStyle
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  /// P2 — Backspace ngay sau khi commit một từ phải replay CHUỖI PHÍM GỐC.
  ///
  /// `TiengVietState.chuKhongDau` KHÔNG chứa phím dấu (`withTone`/`withMu`/
  /// `withGachD` không push ký tự nào), nên dựng lại `keys` từ nó — cách cũ —
  /// khiến mọi backspace kế tiếp replay một chuỗi phím đã MẤT SẠCH DẤU:
  /// "chào" → "cha", "tiếng" → "tien", "đường" → "duon", kèm cả cụm bị xoá và
  /// gõ lại. `previousKeys` giữ đúng những phím user đã bấm.
  func testP2_BackspaceAfterCommitReplaysOriginalKeys() throws {
    let engine = Telex()
    // (phím, chữ đã commit, keys sau BS#1, chữ sau BS#2)
    let cases: [(String, String, String, String)] = [
      ("chaof", "chào", "chaof", "chao"),
      ("tieengs", "tiếng", "tieengs", "tiêng"),
      ("dduwowngf", "đường", "dduwowngf", "đương"),
    ]

    for (keys, committed, wantKeys, afterSecondBS) in cases {
      var buffer = WordBuffer()
      for c in keys { buffer.push(char: c, engine: engine) }
      XCTAssertEqual(buffer.transformed, committed, "Sanity: '\(keys)' phải ra '\(committed)'")

      // Space commit từ (đường `newWord(storePrevious: true)` của handleTextChar).
      buffer.newWord(storePrevious: true)

      // BS#1: xoá dấu cách → khôi phục từ vừa commit vào bộ đệm.
      _ = buffer.pop(engine: engine, usesNFC: true)
      XCTAssertEqual(buffer.transformed, committed)
      XCTAssertEqual(String(buffer.keys), wantKeys,
        "'\(keys)': replay phải giữ CẢ phím dấu, không chỉ chuKhongDau")

      // BS#2: bỏ một phím — kết quả phải khớp đường Backspace không qua commit.
      _ = buffer.pop(engine: engine, usesNFC: true)
      XCTAssertEqual(buffer.transformed, afterSecondBS,
        "'\(keys)': bỏ 1 phím phải ra '\(afterSecondBS)'")
    }
  }

  /// P2 — pin hành vi CŨ để thấy rõ nó sai ở đâu, và khoá luôn nhánh fallback.
  ///
  /// `previousKeys` rỗng (ai đó gán thẳng `previousWordState` mà không qua
  /// `newWord(storePrevious:)`) thì `pop` quay về đúng công thức cũ. Fallback
  /// đó phải TỒN TẠI để không phá call site lạ, nhưng kết quả của nó chính là
  /// bug: chuỗi phím mất dấu.
  func testP2_EmptyPreviousKeysFallsBackToToneLessReplay() throws {
    let engine = Telex()
    var buffer = WordBuffer()
    for c in "chaof" { buffer.push(char: c, engine: engine) }
    buffer.newWord(storePrevious: true)
    buffer.previousKeys = []   // ép đi nhánh fallback = công thức CŨ

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(String(buffer.keys), "chao",
      "Fallback dựng keys từ chuKhongDau — phím dấu 'f' biến mất")
    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "cha",
      "Đây là kết quả SAI của hành vi cũ, giữ lại để đối chiếu")
  }

  /// P3 — `reconstructState` phải reset `ddToggleStage`.
  ///
  /// Vòng replay cũ ghi vào một biến CỤC BỘ nên `self.ddToggleStage` giữ nguyên
  /// giá trị của từ TRƯỚC khi backspace: "vcdd" → "vcđ" (stage = 1), Backspace
  /// đưa màn hình về "vcd" mà stage vẫn 1 → gõ 'd' lại KHÔNG toggle được nữa
  /// (ra "vcdd"), và mọi 'd' sau đó cũng vậy cho tới hết từ.
  func testP3_ReconstructStateResetsDdToggleStage() throws {
    let engine = Telex()
    var buffer = WordBuffer()
    for c in "vcdd" { buffer.push(char: c, engine: engine) }
    XCTAssertEqual(buffer.transformed, "vcđ", "anywhere-dd: 'vcdd' → 'vcđ'")
    XCTAssertEqual(buffer.ddToggleStage, 1)

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "vcd")
    XCTAssertEqual(buffer.ddToggleStage, 0,
      "Sau replay, stage phải khớp MÀN HÌNH ('vcd' — chưa toggle)")

    buffer.push(char: "d", engine: engine)
    XCTAssertEqual(buffer.transformed, "vcđ",
      "Gõ 'd' lại phải toggle được; hành vi cũ kẹt ở 'vcdd'")
  }

  /// P6 — "kr" đã gỡ khỏi `impossible2LetterPrefixes`.
  ///
  /// Nó vừa nằm ở đó vừa nằm trong `TiengViet.PhuAmGhep` và
  /// `TiengVietValidator.ValidInitials` như phụ âm đầu tiếng Việt HỢP LỆ —
  /// mâu thuẫn trực tiếp. `isImpossibleCluster` chạy TRƯỚC validator (và trước
  /// cả Free Mark) nên "kroong" bị khoá raw ngay ở phím 'r' → ra "kroong" thay
  /// vì "Krông" (Krông Pắc, Krông Ana, Krông Bông).
  func testP6_KrPrefixNoLongerBlocksVietnamesePlaceNames() throws {
    let engine = Telex()

    func typed(_ keys: String) -> String {
      var b = WordBuffer()
      for c in keys { b.push(char: c, engine: engine) }
      return b.transformed
    }

    XCTAssertEqual(typed("kroong"), "krông", "Krông — tên địa danh Tây Nguyên")
    // Đối chứng: từ tiếng Anh mở đầu "kr" vẫn được validator/lexicon giữ raw,
    // chỉ là khoá muộn hơn 1 phím.
    XCTAssertEqual(typed("krill"), "krill")
    XCTAssertEqual(typed("kraft"), "kraft")
    // Đối chứng cho `testGoNhanhEngineInnovations` (dòng "kr initials"):
    // "krong" không có phím mũ nên vẫn ra "krong" như trước.
    XCTAssertEqual(typed("krong"), "krong")
  }
}


final class InputProcessorRecoveryTests: SpellResetTestCase {
  func testBugTesst() throws {
    let inputProcessor = InputProcessor(method: .Telex)
    inputProcessor.push(char: "t")
    inputProcessor.push(char: "e")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.transformed, "té")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.transformed, "tes")
    XCTAssertTrue(inputProcessor.stopProcessing)
    inputProcessor.push(char: "t")
    XCTAssertEqual(inputProcessor.transformed, "test")
  }

  func testBugTesstBackspace() throws {
    let inputProcessor = InputProcessor(method: .Telex)
    inputProcessor.push(char: "t")
    inputProcessor.push(char: "e")
    inputProcessor.push(char: "s")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.transformed, "tes")
    XCTAssertTrue(inputProcessor.stopProcessing)
    inputProcessor.push(char: "t")
    XCTAssertEqual(inputProcessor.transformed, "test")
    
    // Backspace from "test"
    let _ = inputProcessor.pop(usesNFC: inputProcessor.usesNFCForFocusedField())
    XCTAssertEqual(inputProcessor.transformed, "tes")
    XCTAssertTrue(inputProcessor.stopProcessing)
  }

  // MARK: - InputProcessor Recovery Rollback Tests

  func testInputProcessorRecoveryRollback() throws {
    let inputProcessor = InputProcessor(method: .Telex)

    // Type "hồ" (hoof)
    inputProcessor.push(char: "h")
    inputProcessor.push(char: "o")
    inputProcessor.push(char: "o")
    inputProcessor.push(char: "f")
    XCTAssertEqual(inputProcessor.transformed, "hồ")
    XCTAssertFalse(inputProcessor.stopProcessing)

    // Type "z" -> triggers recovery
    inputProcessor.push(char: "z")
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "hoofz")

    // Backspace
    let (numBackspaces, diffChars) = inputProcessor.pop(usesNFC: inputProcessor.usesNFCForFocusedField())

    // "hoofz" and "hồ" share "h"
    // "hoofz" is ["h", "o", "o", "f", "z"] (5 chars)
    // "hồ" is ["h", "ồ"] (2 chars)
    // Common prefix "h" (1 char)
    // Backspaces: 5 - 1 = 4
    XCTAssertEqual(numBackspaces, 4, "numBackspaces should be 4")
    XCTAssertEqual(String(diffChars), "ồ", "diffChars should be ồ")
    XCTAssertEqual(inputProcessor.transformed, "hồ", "transformed should be hồ")
    XCTAssertFalse(inputProcessor.stopProcessing, "stopProcessing should be false")
  }

  func testImpossibleConsonantClustersTelex() throws {
    let oldAllowed = Defaults[.allowedZWJF]
    Defaults[.allowedZWJF] = false
    defer { Defaults[.allowedZWJF] = oldAllowed }

    // 1. Double letter impossible prefixes (e.g. street, plural, class, block)
    XCTAssertEqual(transform_text_telex(for: "street"), "street")
    XCTAssertEqual(transform_text_telex(for: "plural"), "plural")
    XCTAssertEqual(transform_text_telex(for: "clear"), "clear")
    XCTAssertEqual(transform_text_telex(for: "block"), "block")
    XCTAssertEqual(transform_text_telex(for: "fly"), "fly")
    XCTAssertEqual(transform_text_telex(for: "green"), "green")

    // 2. Letters f, j, z starting a word (e.g. fast, jail, zone)
    XCTAssertEqual(transform_text_telex(for: "fast"), "fast")
    XCTAssertEqual(transform_text_telex(for: "jail"), "jail")
    XCTAssertEqual(transform_text_telex(for: "zone"), "zone")

    // 3. Normal Telex words are processed fine (e.g. ddieemr -> điểm, song -> song)
    XCTAssertEqual(transform_text_telex(for: "song"), "song")
    XCTAssertEqual(transform_text_telex(for: "ddieemr"), "điểm")
  }

  func testImpossibleConsonantClustersVni() throws {
    let oldAllowed = Defaults[.allowedZWJF]
    Defaults[.allowedZWJF] = false
    defer { Defaults[.allowedZWJF] = oldAllowed }

    // 1. Double letter impossible prefixes in VNI
    XCTAssertEqual(transform_text_vni(for: "street"), "street")
    XCTAssertEqual(transform_text_vni(for: "plural"), "plural")
    XCTAssertEqual(transform_text_vni(for: "clear"), "clear")

    // 2. Starting letter 'w' is bypassed in VNI (w is impossible in VNI)
    XCTAssertEqual(transform_text_vni(for: "word"), "word")

    // 3. Normal VNI words work fine (e.g. d9ie6m3 -> điểm)
    XCTAssertEqual(transform_text_vni(for: "d9ie6m3"), "điểm")
  }

  func testImpossibleConsonantClusterRollback() throws {
    let inputProcessor = InputProcessor(method: .Telex)
    
    // Type "s" -> valid Vietnamese consonant prefix so far
    inputProcessor.push(char: "s")
    XCTAssertFalse(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "s")
    
    // Type "t" -> "st" becomes an impossible consonant prefix! It enters recovery/bypass
    inputProcessor.push(char: "t")
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "st")
    
    // Type "r" -> still in recovery/bypass
    inputProcessor.push(char: "r")
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "str")
    
    // Press backspace -> rolls back to "st", still in recovery/bypass
    let (bs1, diff1) = inputProcessor.pop(usesNFC: inputProcessor.usesNFCForFocusedField())
    XCTAssertEqual(bs1, 0)
    XCTAssertEqual(diff1, [])
    XCTAssertTrue(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "st")
    
    // Press backspace again -> rolls back to "s", which is valid, so recovery disarms!
    let (bs2, diff2) = inputProcessor.pop(usesNFC: inputProcessor.usesNFCForFocusedField())
    XCTAssertEqual(bs2, 0)
    XCTAssertEqual(diff2, [])
    XCTAssertFalse(inputProcessor.stopProcessing)
    XCTAssertEqual(inputProcessor.transformed, "s")
  }
}

// MARK: - ===========================================
// MARK: - Commit-Time Replacement vs previousWordState
// MARK: - ===========================================

/// Mọi đường commit tự THAY chữ trên màn hình (macro bung, spell auto-correct)
/// đều để lại `wordState` giữ chữ user gõ chứ không phải chữ đang hiển thị.
/// Lưu state lệch đó làm `previousWordState` là bug: `WordBuffer.pop` (nhánh
/// `keys.isEmpty`) dựng nó ngược vào buffer khi user Backspace ngay sau đó, nên
/// mọi diff kế tiếp được tính trên đoạn text KHÔNG có trên màn hình → phá chữ.
final class CommitReplacementPreviousWordStateTests: XCTestCase {

  private var savedSpell = true
  private var savedRestore = true
  private var savedEnVn = true

  override func setUp() {
    super.setUp()
    savedSpell = Defaults[.spellCheckEnabled]
    savedRestore = Defaults[.englishAutoRestoreEnabled]
    savedEnVn = Defaults[.useEnVnReference]
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    // "arm"/"usa" KHÔNG nằm trong danh sách EN nhúng sẵn — chỉ có trong gói từ
    // điển tải về ~/Library/Application Support/vkey/lexicon. Máy chưa tải gói
    // (cài mới) thì "ẢM"/"ÚA" là từ Việt hợp lệ và không có gì để khôi phục,
    // nên test đỏ theo máy chứ không theo code. Nạp thẳng hai từ vào bảng
    // tham chiếu Anh-Việt (đường `useEnVnReference` của nhánh viết tắt).
    Defaults[.useEnVnReference] = true
    EnVnReference.shared.load(en2vn: ["arm": ["cánh tay"], "usa": ["Hoa Kỳ"]], vn2en: nil)
  }

  override func tearDown() {
    Defaults[.spellCheckEnabled] = savedSpell
    Defaults[.englishAutoRestoreEnabled] = savedRestore
    Defaults[.useEnVnReference] = savedEnVn
    // Trả bảng tham chiếu về đúng nội dung gói từ điển của máy (reload chạy
    // đồng bộ khi đang test).
    LexiconManager.shared.reload()
    super.tearDown()
  }

  /// Gõ "ARM": Telex coi R giữa hai phụ âm là dấu hỏi → "ẢM". Ở phím kết từ,
  /// spell decision nhận ra initialism tiếng Anh và gõ lại "ARM" lên màn hình
  /// (`.restoreRawEnglish`). Sau bước đó màn hình là "ARM" còn `wordState` vẫn
  /// là "ẢM" — đúng kiểu lệch đã vá ở macro, nên KHÔNG được lưu previous.
  func testEnglishRestoreCommitDoesNotStoreStaleWordState() throws {
    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in "ARM" { p.push(char: c) }
    XCTAssertEqual(p.transformed, "ẢM", "Telex: R giữa các phụ âm = dấu hỏi")

    XCTAssertTrue(
      p.applySpellDecisionAndAdvance(endingChar: " ", swallowEndingChar: true),
      "Spell decision phải restore 'ARM' — vkey tự gửi thay thế")
    XCTAssertNil(
      p.previousWordState,
      "Màn hình đang là 'ARM' còn wordState giữ 'ẢM' — lưu lại là dựng chữ cũ")

    // Backspace ngay sau đó chỉ xoá dấu cách (OS tự xử lý, trả về 0/rỗng) và
    // buffer phải TRỐNG, không được hồi sinh "ẢM".
    let (backspaces, diffChars) = p.pop(usesNFC: true)
    XCTAssertEqual(backspaces, 0)
    XCTAssertTrue(diffChars.isEmpty)
    XCTAssertEqual(p.transformed, "", "Buffer phải trống sau Backspace")
    XCTAssertTrue(p.wordState.isBlank)
  }

  /// Nhánh `.suggest` (thay từ gõ bằng từ trong từ điển) thoát cùng một cửa
  /// `return true`, nên dùng chung bảo đảm: hễ `applySpellDecisionAndAdvance`
  /// báo đã thay chữ thì không có `previousWordState` nào được giữ lại.
  func testAnyAppliedSpellReplacementLeavesNoPreviousWordState() throws {
    for word in ["ARM", "USA"] {
      let p = InputProcessor(method: .Telex)
      p.newWord()
      for c in word { p.push(char: c) }
      guard p.applySpellDecisionAndAdvance(endingChar: " ", swallowEndingChar: true) else {
        XCTFail("'\(word)' phải đi qua đường thay chữ ở commit")
        continue
      }
      XCTAssertNil(p.previousWordState, "'\(word)': không được giữ state trước khi sửa")
    }
  }

  /// Hậu quả cụ thể của hành vi CŨ, pin ở mức `WordBuffer`: `storePrevious:
  /// true` làm Backspace dựng lại "ẢM" vào buffer trong khi màn hình là "ARM";
  /// `storePrevious: false` để buffer trống như mong đợi.
  func testStoredStaleStateResurrectsPreReplacementWord() throws {
    let engine = Telex()

    var oldBehavior = WordBuffer()
    for c in "ARM" { oldBehavior.push(char: c, engine: engine) }
    oldBehavior.newWord(storePrevious: true)
    _ = oldBehavior.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(
      oldBehavior.transformed, "ẢM",
      "Hành vi cũ: Backspace hồi sinh 'ẢM' dù màn hình hiển thị 'ARM'")

    var newBehavior = WordBuffer()
    for c in "ARM" { newBehavior.push(char: c, engine: engine) }
    newBehavior.newWord(storePrevious: false)
    _ = newBehavior.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(newBehavior.transformed, "", "Hành vi mới: buffer trống")
    XCTAssertTrue(newBehavior.keys.isEmpty)
  }

  /// Macro trên đường Space (`handleTaskKey`) phải cùng quy tắc với đường dấu
  /// câu (`handleTextChar`): sau khi bung, màn hình là phần bung còn `wordState`
  /// giữ trigger. Space là phím bung macro phổ biến nhất.
  func testMacroExpansionOnSpaceKeepsNoPreviousWordState() throws {
    let savedMacros = Defaults[.macros]
    let savedEnabled = Defaults[.macroEnabled]
    defer {
      Defaults[.macros] = savedMacros
      Defaults[.macroEnabled] = savedEnabled
    }
    Defaults[.macroEnabled] = true
    Defaults[.macros] = [Macro(from: "dc", to: "địa chỉ")]

    let p = InputProcessor(method: .Telex)
    p.newWord()
    for c in "dc" { p.push(char: c) }
    XCTAssertEqual(p.transformed, "dc")

    XCTAssertTrue(
      p.expandMacroAndAdvance(endingChar: " "),
      "Macro 'dc' phải bung ở phím Space")
    XCTAssertNil(p.previousWordState, "Trigger 'dc' không được lưu sau khi bung macro")

    let (backspaces, diffChars) = p.pop(usesNFC: true)
    XCTAssertEqual(backspaces, 0)
    XCTAssertTrue(diffChars.isEmpty)
    XCTAssertEqual(p.transformed, "", "Backspace sau macro không được hồi sinh 'dc'")
  }
}
