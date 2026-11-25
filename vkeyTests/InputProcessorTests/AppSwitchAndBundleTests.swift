import XCTest
import Defaults
@testable import vkey

// MARK: - v4.22: hộp thoại Lưu của app sandbox làm gãy từ đang gõ
//
// Ô "Thư mục mới" trong hộp thoại Lưu của Safari nằm ở tiến trình phụ
// `com.apple.Safari.SandboxBroker`. AX trả về khi thì bundle đó, khi thì
// `com.apple.Safari` — đổi qua lại TỪNG PHÍM. vkey coi mỗi lần đổi là chuyển
// app, áp lại chế độ Smart Switch, và đường đó xoá sạch bộ đệm từ.
// Hệ quả đo được: gõ "Haf Nooij" ra đúng "Haf Nooij", và "Nooij" ra "Nôị" vì
// từ bị cắt đôi giữa chừng ("nô" đã commit, "ij" thành từ mới → "ị").
final class SandboxHelperBundleTests: XCTestCase {

  /// Bundle phụ của chính app đang chạy KHÔNG phải app khác.
  func testHelperBundleResolvesToParentApp() {
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.Safari.SandboxBroker",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari",
      "SandboxBroker là tiến trình phụ của Safari, không phải app riêng")
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.appkit.xpc.openAndSavePanelService",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari",
      "hộp thoại Lưu ngoài tiến trình vẫn thuộc app đang dùng")
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.WebKit.WebContent",
                                        frontmost: "com.htl.plume"),
      "com.htl.plume",
      "WKWebView out-of-process phải quy về app host (Plume)")
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.WebKit.WebContent",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari",
      "WKWebView trong Safari quy về Safari")
  }

  /// Đối chứng: app khác thật thì vẫn phải nhận ra là khác.
  func testDifferentAppStillSwitches() {
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.google.Chrome",
                                        frontmost: "com.apple.Safari"),
      "com.google.Chrome",
      "Chrome là app khác thật")
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.Safari",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari")
  }

  /// Lưới an toàn chung: gán lại CÙNG giá trị enabled không được xoá từ đang gõ.
  /// `didSet` của Swift bắn cả khi giá trị không đổi, nên mọi lần áp lại chế độ
  /// Smart Switch đều đi qua đây.
  func testSetEnabledSameValueKeepsWordBuffer() {
    let p = InputProcessor(method: .Telex)
    let hook = EventHook(inputProcessor: p)
    hook.setEnabled(true)
    p.newWord()
    for c in "ha" { p.push(char: c) }
    XCTAssertEqual(p.transformed, "ha")
    hook.setEnabled(true)   // gán lại ĐÚNG giá trị cũ
    XCTAssertEqual(p.transformed, "ha", "gán lại cùng giá trị không được xoá đệm")
    p.push(char: "f")
    XCTAssertEqual(p.transformed, "hà", "dấu huyền vẫn áp được sau khi áp lại chế độ")
  }

  /// Đổi giá trị thật thì vẫn phải reset (hành vi cũ, không được phá).
  func testSetEnabledValueChangeStillResets() {
    let p = InputProcessor(method: .Telex)
    let hook = EventHook(inputProcessor: p)
    hook.setEnabled(true)
    p.newWord()
    for c in "ha" { p.push(char: c) }
    hook.setEnabled(false)
    XCTAssertEqual(p.transformed, "", "tắt/bật thật sự vẫn reset đệm")
  }
}


// MARK: - ===========================================
// MARK: - v4.23 — Ranh giới đổi app: bộ đệm & ngữ cảnh câu
// MARK: - ===========================================
final class AppSwitchBoundaryV423Tests: XCTestCase {

  private var savedZWJF = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.allowedZWJF] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  // ⚠️ ĐÃ XOÁ (v4.24) — `testP1_RealAppChangeClearsWordBuffer`.
  //
  // Test đó khoá: đang gõ "vie" ở Safari mà `changeActiveApp("com.google.Chrome")`
  // thì `transformed` phải về "" và phím kế tiếp mở TỪ MỚI. Nó khoá đúng một
  // dòng `newWord()` trong `InputProcessor.changeActiveApp`. Dòng đó đã bị GỠ,
  // nên test đi theo — giữ lại là khoá một con đường không còn tồn tại.
  //
  // VÌ SAO GỠ: hàm ấy chạy trong callback event-tap, mà trên macOS 26 `activeApp`
  // DAO ĐỘNG mỗi phím ở overlay (Spotlight) — hai khối trong `EventHook` ghi nó
  // từ hai nguồn lệch nhau (`eventTargetUnixProcessID` trả app NỀN, AX trả
  // Spotlight). Guard `app != activeApp` vì thế đúng mà vô dụng: mỗi phím là một
  // lần "đổi app" thật sự khác giá trị → xoá bộ đệm ở MỌI phím → không dấu nào
  // hình thành nữa, gõ tiếng Việt âm thầm biến thành gõ tiếng Anh. Vòng vá tiếp
  // theo (gộp hai khối thành một bộ phân giải duy nhất) lại đẻ hồi quy khác.
  //
  // CA HỎNG QUAY LẠI (P1 — chấp nhận sống chung): một app cướp focus mà KHÔNG
  // sinh keyDown/mouseDown, đúng lúc đang gõ dở một từ → bộ đệm của app cũ sống
  // sót, và số backspace của lần thay thế kế tiếp (tính trên "vie") ăn mất ký tự
  // cuối của ô bên app mới. Hiếm, hỏng đúng một ký tự, gõ lại được — rẻ hơn hẳn
  // "mất dấu ở mọi app".
  //
  // MUỐN VÁ LẠI: đọc docstring (a)→(d) của `InputProcessor.changeActiveApp`
  // TRƯỚC. Điều kiện tiên quyết là chứng minh trên máy thật rằng `activeApp` ỔN
  // ĐỊNH ở mọi phím (macOS 26 + Spotlight + Chrome web content). Dựng lại
  // `newWord()` khi chưa có bằng chứng đó thì
  // `testR1_ActiveAppPingPongMustNotTouchTheWordBuffer` sẽ đỏ — và nó đỏ có lý do.

  /// P1 — một lời gọi `changeActiveApp` KHÔNG được giết bộ đệm từ.
  ///
  /// Sau khi nửa "xoá đệm khi đổi app" của P1 bị LÙI (v4.24 — xem khối chú thích
  /// ngay trên), test này xanh một cách hiển nhiên: không đường nào trong
  /// `changeActiveApp` đụng tới bộ đệm nữa. Giữ lại làm TRIPWIRE — ai thêm
  /// `newWord()` vào đó mà quên guard sẽ thấy nó đỏ trước khi kịp đi hết vòng lặp
  /// vá-rồi-lùi lần nữa.
  ///
  /// Bối cảnh vẫn nguyên giá trị: `changeActiveApp` bị gọi lại với CÙNG bundle
  /// rất thường xuyên (`AppState.activeApplicationDidChange` gọi không guard; AX
  /// nhảy qua lại giữa app cha và tiến trình phụ của nó). Xoá vô điều kiện chính
  /// là dựng lại lỗi v4.22 — từ đang gõ bị cắt đôi giữa chừng ("Nooij" → "Nôị").
  func testP1_SameAppReassignmentKeepsWordBuffer() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp("com.apple.Safari")
    p.newWord()
    for c in "nooi" { p.push(char: c) }
    XCTAssertEqual(p.transformed, "nôi")

    p.changeActiveApp("com.apple.Safari")   // gán lại ĐÚNG giá trị cũ
    XCTAssertEqual(p.transformed, "nôi", "Gán lại cùng bundle không được xoá đệm")

    p.push(char: "j")
    XCTAssertEqual(p.transformed, "nội", "Dấu nặng vẫn áp được lên cả cụm")
  }

  /// P8 — ngữ cảnh câu chết cùng ranh giới app.
  ///
  /// `changeActiveApp` nay gọi `resetSentenceCapitalizeState()`. Nửa quan sát
  /// được từ test là cờ chờ-viết-hoa: sau Enter ở app A, chuyển sang app B thì
  /// chữ đầu tiên gõ ở B KHÔNG được tự viết hoa — câu đó thuộc về app A.
  ///
  /// PHẠM VI: nửa còn lại của P8 (`prev1Committed`/`prev2Committed` — cửa sổ
  /// n-gram) là `private` và chỉ quan sát được qua `NGramStore` file-backed,
  /// nên KHÔNG assert ở đây; đừng đọc test này như bằng chứng cửa sổ n-gram đã
  /// bị cắt.
  func testP8_PendingCapitalizeDiesOnRealAppChange() throws {
    Defaults[.autoCapitalizeEnabled] = true
    defer { Defaults.reset(.autoCapitalizeEnabled) }

    func press(_ p: InputProcessor, code: UInt16) -> Unmanaged<CGEvent>? {
      let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
      event.flags = []
      return p.handleEvent(event: event)
    }

    // Đối chứng: KHÔNG đổi app → vẫn tự viết hoa như cũ.
    let staying = InputProcessor(method: .Telex)
    staying.changeActiveApp("com.apple.Notes")
    _ = press(staying, code: 36)          // Enter
    _ = press(staying, code: 0)           // a
    XCTAssertEqual(staying.transformed, "A", "Cùng app: Enter vẫn mở câu mới")

    // Đổi app thật giữa Enter và chữ cái → ngữ cảnh câu của app cũ phải chết.
    let switching = InputProcessor(method: .Telex)
    switching.changeActiveApp("com.apple.Notes")
    _ = press(switching, code: 36)        // Enter (ở Notes)
    switching.changeActiveApp("com.apple.Safari")
    _ = press(switching, code: 0)         // a (ở Safari)
    XCTAssertEqual(switching.transformed, "a",
      "Câu vừa xuống dòng thuộc app CŨ — không được viết hoa hộ app mới")
  }
}


// MARK: - ===========================================
// MARK: - v4.24 (R1) — "app đang nhận phím": bộ phân giải MỘT-NGUỒN ĐÃ LÙI
// MARK: - ===========================================
//
// v4.23 gộp hai khối ghi `activeApp` trong `EventHook.eventTapCallback` thành
// MỘT bộ phân giải (overlay AX → event-target PID → cache) và kéo ảnh chụp AX
// lên chạy sớm hơn. Bản gộp đó ĐÃ LÙI (v4.24): nó chỉ an toàn khi đi kèm
// `newWord()` trong `changeActiveApp`, mà cặp ấy biến dao động `activeApp` vô
// hại thành xoá bộ đệm mỗi phím → không dấu nào hình thành nữa.
//
// HEAD hôm nay lại có hai khối, và `activeApp` lại được phép dao động ở overlay.
// Điều đó KHÔNG SAO — hậu quả duy nhất là đặt lại chiến lược gửi, vì không còn
// ai xoá bộ đệm theo nó. Hai test dưới đây khoá đúng ranh giới ấy.
final class AppSwitchResolverV424Tests: XCTestCase {

  private var savedZWJF = true
  private var savedFreeMark = false

  override func setUp() {
    super.setUp()
    savedZWJF = Defaults[.allowedZWJF]
    savedFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.allowedZWJF] = true
    Defaults[.freeMarkModeEnabled] = false
  }

  override func tearDown() {
    Defaults[.allowedZWJF] = savedZWJF
    Defaults[.freeMarkModeEnabled] = savedFreeMark
    super.tearDown()
  }

  /// R1 — `activeApp` được phép DAO ĐỘNG; bộ đệm từ thì KHÔNG được chết theo.
  ///
  /// Trên macOS 26 với Smart Switch TẮT, gõ vào Spotlight: `eventTargetUnixProcessID`
  /// trả app NỀN (vd Excel) còn ảnh AX trả `com.apple.Spotlight`. Hai khối trong
  /// `EventHook.eventTapCallback` ghi `input.activeApp` từ hai nguồn đó, nên giá
  /// trị kéo qua kéo lại MỖI PHÍM. Đó là sự thật của HEAD và vkey sống chung với
  /// nó.
  ///
  /// ⚠️ ĐÂY LÀ TRIPWIRE CHO MỘT QUYẾT ĐỊNH, KHÔNG PHẢI TEST KHOÁ MỘT FIX. Bản
  /// v4.23 cho `changeActiveApp` gọi `newWord()`; cộng với dao động trên, mỗi
  /// phím thành một lần "đổi app" ⇒ `transformed` luôn rỗng ⇒ không dấu nào hình
  /// thành ⇒ gõ tiếng Việt âm thầm biến thành gõ tiếng Anh ở MỌI app. Bản vá đó
  /// đã lùi; test này đỏ đúng lúc ai đó dựng lại nó.
  ///
  /// CỐ Ý KHÔNG assert chiều ngược lại (đổi app THẬT có xoá đệm hay không): P1 là
  /// lỗi đang được chấp nhận sống chung — xem khối chú thích trong
  /// `AppSwitchBoundaryV423Tests` và docstring (a)→(d) của
  /// `InputProcessor.changeActiveApp`. Một bản vá P1 ĐÚNG trong tương lai (điều
  /// kiện tiên quyết: chứng minh trên máy thật rằng `activeApp` ổn định mỗi phím)
  /// sẽ phải sửa chính test này một cách CÓ CHỦ Ý, sau khi đọc hết lịch sử đó.
  func testR1_ActiveAppPingPongMustNotTouchTheWordBuffer() throws {
    let overlay = "com.apple.Spotlight"
    let background = "com.microsoft.Excel"

    // Hai nguồn bất đồng bộ ⇒ mỗi phím phân giải ra một app khác. Dấu vẫn phải
    // hình thành đủ trên cả cụm.
    let pingPong = InputProcessor(method: .Telex)
    pingPong.changeActiveApp(overlay)
    pingPong.newWord()
    var flip = false
    for c in "tieengs" {
      flip.toggle()
      pingPong.changeActiveApp(flip ? background : overlay)
      pingPong.push(char: c)
    }
    XCTAssertEqual(pingPong.transformed, "tiếng",
      "dao động activeApp từng phím KHÔNG được đụng tới bộ đệm từ")

    // Đối chứng: phân giải ổn định (ca gõ Spotlight bình thường) cũng ra "tiếng"
    // — nếu ca này đỏ thì lỗi nằm ở engine, không ở ranh giới đổi app.
    let stable = InputProcessor(method: .Telex)
    stable.changeActiveApp(overlay)
    stable.newWord()
    for c in "tieengs" {
      stable.changeActiveApp(overlay)
      stable.push(char: c)
    }
    XCTAssertEqual(stable.transformed, "tiếng")
  }

  /// R1 — ba viên gạch thuần mà đường nhận diện "app đang nhận phím" của HEAD
  /// vẫn đi qua. Bộ phân giải gộp của v4.23 đã lùi, nhưng cả `isOverlayBundle`
  /// lẫn `canonicalAppBundle` đều CÓ SẴN ở HEAD và vẫn được `EventHook` gọi —
  /// nếu một trong ba đổi nghĩa thì việc nhận diện app đổi hành vi mà chẳng test
  /// nào khác nhìn thấy.
  func testR1_ResolverBuildingBlocksKeepTheirMeaning() throws {
    // Nhánh 1 — overlay đang thực-focus THẮNG event-target PID (bằng chứng
    // v4.11: `eventTargetUnixProcessID` trả app NỀN cho phím Spotlight trên
    // macOS 26). Ở HEAD, danh sách overlay là thứ quyết định `focusedOverlayBundle()`
    // có ghi đè bundle của event-target hay không, khi Smart Switch BẬT.
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.Spotlight"))
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.dock"))
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.systemuiserver"))
    // App thường KHÔNG được coi là overlay: coi nhầm thì cache focused-bundle
    // (vốn chỉ ghi khi AX trả về bundle, nên DÍNH) biến thành latch overlay —
    // đúng thứ v4.11 đã gỡ và bản vá này không được dựng lại.
    XCTAssertFalse(EventSimulator.isOverlayBundle("com.microsoft.Excel"))
    XCTAssertFalse(EventSimulator.isOverlayBundle("com.google.Chrome"))

    // Nhánh 2/3 — giá trị phân giải xong còn phải quy về app CHA, nếu không mỗi
    // phím trong hộp thoại Lưu lại là một lần "đổi app" (lỗi v4.22: "Nooij" →
    // "Nôị"). Cả hai khối ghi `activeApp` ở HEAD đều đi qua đúng hàm này.
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(
        focused: "com.apple.appkit.xpc.openAndSavePanelService",
        frontmost: "com.apple.TextEdit"),
      "com.apple.TextEdit")
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.apple.Safari.SandboxBroker",
                                        frontmost: "com.apple.Safari"),
      "com.apple.Safari")
    // …mà app khác THẬT thì vẫn phải nhận ra là khác — nếu không, chiến lược gửi
    // của app này bị áp cho app kia (và một bản vá P1 tương lai cũng chết theo).
    XCTAssertEqual(
      InputProcessor.canonicalAppBundle(focused: "com.google.Chrome",
                                        frontmost: "com.apple.Safari"),
      "com.google.Chrome")
  }
}


// MARK: - Phạm vi gỡ cờ Shift kẹt

/// Cờ `InputProcessor.hardwareShiftDown` theo dõi Shift THẬT bằng cách nghe
/// `flagsChanged`, và `passThrough` gỡ `.maskShift` khỏi event trả về app khi
/// cờ là `false`. Cờ đó có thể mắc SAI `false` trong lúc người gõ đang giữ
/// Shift: dòng cập nhật nằm sau hai early-return của `handleTapEvent`, nên mọi
/// `flagsChanged` xảy ra khi tap bị `.tapDisabledByTimeout`, khi tap bị tháo
/// rồi gắn lại, hoặc khi quyền Trợ năng mất rồi được cấp lại, đều không tới.
///
/// Đo 09/10/2026 (`Tools/probe/shifttest.swift`, `Tools/probe/arrowtest.swift`
/// — event đi qua `.cghidEventTap` nên vkey xử lý như phím thật):
///   - Shift CÓ `flagsChanged`: "xin " + Shift+c + "hao" → "xin Chao" (đúng)
///   - Shift chỉ dính trên event: → "xin chao" (cờ làm việc của nó)
///   - "abc" + Shift+Left + "x": có `flagsChanged` → "abx" (chọn rồi ghi đè);
///     không có → **"abxc"** — Shift bị gỡ nên mũi tên chỉ dời con trỏ.
///
/// Mất Shift+mũi tên (và Shift+Enter, trong app chat là xuống dòng chứ không
/// phải gửi tin) nặng hơn hẳn lỗi mà cờ này đi vá — ký tự thứ hai bị viết hoa.
/// Nên phạm vi gỡ thu về đúng hai phím mà v4.32 đo được: phím CHỮ và Backspace.
final class StuckShiftScopeTests: XCTestCase {
  private func letterProcessor() -> InputProcessor {
    let processor = InputProcessor(method: .Telex)
    processor.changeActiveApp("com.apple.Notes")
    processor.hardwareShiftDown = false
    return processor
  }

  func testStuckShiftIsKeptOnNavigationAndEnter() throws {
    // 123–126 mũi tên, 115 Home, 119 End, 48 Tab, 36 Enter, 49 Space, 18 số 1
    for code in [123, 124, 125, 126, 115, 119, 48, 36, 49, 18] as [CGKeyCode] {
      let processor = letterProcessor()
      let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true))
      event.flags = .maskShift
      _ = processor.handleEvent(event: event)
      XCTAssertTrue(
        event.flags.contains(.maskShift),
        "mã phím \(code): chỉ phím chữ và Backspace được gỡ Shift. Gỡ ở đây làm mất "
          + "Shift+mũi tên (chọn chữ) và biến Shift+Enter thành Enter (app chat gửi tin dở)")
    }
  }

  func testStuckShiftIsStillStrippedFromLettersAndBackspace() throws {
    for code in [8, 34, 51] as [CGKeyCode] {  // c, i, Backspace
      let processor = letterProcessor()
      let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true))
      event.flags = .maskShift
      _ = processor.handleEvent(event: event)
      XCTAssertFalse(
        event.flags.contains(.maskShift),
        "mã phím \(code): đây là phạm vi v4.32 đo được — ký tự thứ hai không được "
          + "viết hoa, và Backspace không được đi kèm Shift (Shift+Backspace không xoá)")
    }
  }

  /// Cờ phải đồng bộ được lại từ trạng thái phần cứng, vì `flagsChanged` có thể
  /// đã mất. `NSEvent.modifierFlags` KHÔNG dùng được: đo cùng ngày cho thấy nó
  /// trễ một event (ở `flagsChanged` Shift-down nó còn báo `false`, ở
  /// `flagsChanged` Shift-up nó còn báo `true`).
  func testEventHookSyncsShiftFromHardwareState() throws {
    let processor = InputProcessor(method: .Telex)
    processor.hardwareShiftDown = true  // giá trị mắc sai
    let hook = EventHook(inputProcessor: processor)
    hook.syncHardwareShiftFromSystem()
    XCTAssertEqual(
      processor.hardwareShiftDown,
      CGEventSource.flagsState(.hidSystemState).contains(.maskShift),
      "đồng bộ lại phải lấy đúng trạng thái Shift của phần cứng")
  }
}
