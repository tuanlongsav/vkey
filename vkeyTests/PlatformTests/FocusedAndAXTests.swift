import XCTest
import Defaults
@testable import vkey

// MARK: - ===========================================
// MARK: - v4.24 (R5) — vì sao đọc hụt AXRole vẫn phải LEO PARENT
// MARK: - ===========================================
//
// CẢ HAI bản vá R5 đã bị LÙI (v4.24): (1) `Focused.fieldKind(from:)` bỏ cuộc sớm
// và trả `.unknown` khi đọc hụt `AXRole`; rồi (2) cờ `fieldKindIsReliable` +
// `AppState.adoptFieldKind` đóng băng phân loại suốt một từ. HEAD lại leo parent
// khi đọc hụt, không có cờ tin cậy, không đóng băng — lý do đầy đủ (a)→(d) nằm
// trong docstring của `Focused.fieldKind(from:)`.
//
// PHẠM VI của cả lớp này: `Focused.fieldKind(from:)` là `private` và đòi một
// `AXUIElement` sống của cây AX thật, thứ không dựng được trong unit test. Nên ở
// đây khoá HAI HỆ QUẢ của việc để `.unknown` lọt ra — đó cũng đúng là hai lý do
// khiến bản vá (1) bị lùi, và là hai thứ sẽ hỏng nếu ai đó dựng nó lại.
final class FocusedFieldStabilityV424Tests: XCTestCase {

  /// R5 (a) — hệ quả thứ nhất của `.unknown`: thanh địa chỉ Chrome MẤT
  /// `.axDirect`, vì `focusedFieldIsBrowserChrome()` đòi đúng `.windowField`.
  /// Mất axDirect là quay lại synthetic backspace trong ô có inline autocomplete
  /// bôi đen — đúng lỗi "trường" → "truường" mà axDirect sinh ra để tránh.
  ///
  /// Đây là hồi quy mà bản vá "đọc hụt `AXRole` thì bỏ cuộc sớm" của v4.23 gây
  /// ra: chỉ cần MỘT lần đọc hụt ở node trong cùng là omnibox rơi về synthetic
  /// backspace suốt phần còn lại của từ. Bản vá đã lùi; test ở lại vì nó khoá
  /// đúng ranh giới mà bất kỳ vòng vá nào sau này cũng phải giữ.
  func testR5_UnknownFieldKindWouldCostTheOmniboxItsAxDirect() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp("com.google.Chrome")

    p.focusedFieldKind = .windowField
    XCTAssertTrue(p.focusedFieldIsBrowserChrome(),
      "omnibox = windowField của app nhóm NFD ⇒ axDirect")

    p.focusedFieldKind = .unknown
    XCTAssertFalse(p.focusedFieldIsBrowserChrome(),
      "bỏ cuộc sớm ở một node đọc hụt ⇒ omnibox rơi về synthetic backspace")

    // Đối chứng: windowField trong app NHÓM NFC (Notes) KHÔNG phải browser-chrome
    // — ranh giới này phải giữ, không thì axDirect bị ép vào mọi cửa sổ.
    p.changeActiveApp("com.apple.Notes")
    p.focusedFieldKind = .windowField
    XCTAssertFalse(p.focusedFieldIsBrowserChrome())
  }

  /// R5 (b) — hệ quả thứ hai: một hiccup AX giữa từ vẫn LẬT TRỤC, chỉ đổi chiều.
  /// Trong app nhóm NFD ngoài whitelist, `.windowField` đi trục NFC còn `.unknown`
  /// đi trục NFD, mà hai trục đếm backspace KHÁC NHAU cho cùng một bước chuyển.
  /// Ký tự 1–3 phát theo trục A, ký tự 4 đếm theo trục B ⇒ lệch backspace ⇒ ăn
  /// ngược vào chữ đã gõ (đúng lớp lỗi v4.14 "đếm một đằng, phát một nẻo").
  ///
  /// Vì thế bản vá "bỏ cuộc sớm" không giải quyết được gì — nó chỉ đổi chiều lật.
  /// Vòng vá kế tiếp (đóng băng phân loại suốt một từ bằng `AppState.adoptFieldKind`)
  /// cũng ĐÃ LÙI: nó so app bằng bundle id THÔ trong khi AX nhảy qua lại giữa app
  /// cha và tiến trình phụ (hộp thoại Lưu của app sandbox, helper của Chromium),
  /// nên chốt tự mở lại gần như mỗi phím — thêm một tầng trạng thái mà không chặn
  /// được gì.
  ///
  /// CA HỎNG CÒN LẠI (F1, chấp nhận sống chung): cần đúng một hiccup AX rơi vào
  /// giữa một từ. Muốn vá lại thì chốt phải đặt ở chỗ ĐẾM backspace (bất biến
  /// "dạng emit == dạng đếm" của v4.15), KHÔNG phải ở chỗ ĐO field, và phải nhận
  /// diện app theo `InputProcessor.canonicalAppBundle` chứ không so bundle id
  /// thô. Hai con số 2 vs 3 dưới đây là thước đo độ lệch đó.
  func testR5_FieldKindFlipMidWordChangesTheBackspaceArithmetic() throws {
    let (nfcBs, _) = EventSimulator.calcKeyStrokes(from: "điêu", to: "điều")
    let (nfdBs, _) = EventSimulator.calcKeyStrokesNFD(from: "điêu", to: "điều")
    XCTAssertEqual(nfcBs, 2)
    XCTAssertEqual(nfdBs, 3)
    XCTAssertNotEqual(nfcBs, nfdBs,
      "hai trục KHÔNG hoán đổi được giữa chừng một từ")

    // Và đây đúng là hai giá trị mà một lần đọc AX hụt hoán đổi được.
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp("com.tinyspeck.slackmacgap")   // Electron, ngoài whitelist NFC
    p.focusedFieldKind = .windowField
    XCTAssertTrue(p.usesNFCForFocusedField(), "đọc được ⇒ windowField ⇒ trục NFC")
    p.focusedFieldKind = .unknown
    XCTAssertFalse(p.usesNFCForFocusedField(), "đọc hụt ⇒ unknown ⇒ trục NFD")

    // [FIX GỐC v4.14] Đối chứng: app trong whitelist NFC short-circuit TRƯỚC
    // fieldKind, nên hiccup không lật được trục — hàng rào cũ vẫn còn nguyên.
    let telegram = InputProcessor(method: .Telex)
    telegram.changeActiveApp("ru.keepcoder.Telegram")
    for kind in [Focused.FieldKind.windowField, .unknown, .webContent, .nativePanel] {
      telegram.focusedFieldKind = kind
      XCTAssertTrue(telegram.usesNFCForFocusedField(),
        "\(kind): app whitelist NFC không được đổi trục theo fieldKind")
    }
  }

  // ⚠️ ĐÃ XOÁ (v4.24) — `testR5_SnapshotWithoutFocusedElementIsMarkedReliable`.
  //
  // Test đó khoá `snap.fieldKindIsReliable == true` cho nhánh "không có focused
  // element" của `Focused.snapshot()` — tức khoá đúng cờ tin cậy mà bản vá R5
  // vòng hai thêm vào `FocusSnapshot`. Cờ đó đã bị GỠ cùng
  // `AppState.adoptFieldKind`, nên test KHÔNG BIÊN DỊCH ĐƯỢC nữa; nó đi theo cơ
  // chế của nó thay vì được "sửa cho biên dịch được" (phần còn lại —
  // `fieldKind == .unknown`, `isComboOrSearch == false` — chỉ chạy khi máy chạy
  // test tình cờ không có focused element, nên không khoá được gì).
  //
  // VÌ SAO GỠ CỜ: cổng đóng băng dùng nó so app bằng bundle id THÔ, trong khi AX
  // nhảy qua lại giữa app cha và tiến trình phụ (hộp thoại Lưu của app sandbox,
  // helper của Chromium) — chốt tự mở lại gần như mỗi phím: thêm một tầng trạng
  // thái mà không chặn được gì. Vòng vá TRƯỚC đó ("đọc hụt thì bỏ cuộc sớm, trả
  // `.unknown`") còn tệ hơn: nó làm omnibox Chrome mất `.axDirect` thường trực —
  // xem `testR5_UnknownFieldKindWouldCostTheOmniboxItsAxDirect`.
  //
  // CA HỎNG QUAY LẠI (F1 — chấp nhận sống chung): một hiccup AX rơi đúng vào giữa
  // một từ lật `fieldKind` `.windowField` ↔ `.unknown`, hai bên trục NFC/NFD, nên
  // ký tự đầu từ phát theo trục này còn ký tự sau đếm backspace theo trục kia ⇒
  // lệch backspace ⇒ ăn ngược vào chữ đã gõ.
  // `testR5_FieldKindFlipMidWordChangesTheBackspaceArithmetic` ở trên đo đúng độ
  // lệch đó (2 vs 3) và ở lại làm chứng cứ.
}


// MARK: - ===========================================
// MARK: - B1 — mã chết đã gỡ & quyền sở hữu axTargetPID
// MARK: - ===========================================
final class DeadCodeAndPIDOwnershipB1Tests: XCTestCase {

  /// B1.1 — chuỗi `isSearchOrComboFocused` đã biến mất TRỌN VẸN.
  ///
  /// Cái giá của việc giữ nó không phải là một biến thừa: `Focused.snapshot()`
  /// phải đọc thêm `kAXRole` RIÊNG trên focused element — một round-trip AX MỖI
  /// PHÍM, trên tap thread, cho một giá trị không ai đọc (người đọc duy nhất,
  /// `isFixAutocompleteApp()`, đã gỡ ở v4.23). Mà timeout/độ trễ AX điều khiển
  /// thẳng xác suất đọc hụt role ⇒ xác suất lật trục giữa từ. Một round-trip thừa
  /// mỗi phím KHÔNG trung tính.
  ///
  /// Hai vế được khoá bằng hai cách khác nhau vì hai thứ khác nhau:
  ///   • `FocusSnapshot.isComboOrSearch` — khoá lúc BIÊN DỊCH (init memberwise
  ///     hai tham số chỉ tồn tại khi struct có đúng hai trường);
  ///   • `InputProcessor.isSearchOrComboFocused` — khoá lúc CHẠY bằng Mirror,
  ///     vì "một stored property KHÔNG tồn tại" không diễn đạt được bằng kiểu.
  func testB1_1_DeadSearchOrComboChainIsFullyGone() throws {
    let snapshotFields = Mirror(reflecting: Focused.FocusSnapshot(bundleId: nil, fieldKind: .unknown))
      .children.compactMap(\.label)
    XCTAssertEqual(snapshotFields, ["bundleId", "fieldKind"],
      "FocusSnapshot chỉ còn hai trường — thêm trường nào cũng là thêm round-trip AX mỗi phím")

    let processorFields = Mirror(reflecting: InputProcessor(method: .Telex))
      .children.compactMap(\.label)
    // Lưới an toàn: Mirror phải THẤY được stored property, nếu không assert dưới
    // đây đúng một cách vô nghĩa.
    XCTAssertTrue(processorFields.contains("focusedFieldKind"),
      "đối chứng: Mirror có đọc được stored property của InputProcessor")
    XCTAssertFalse(processorFields.contains { $0.contains("SearchOrCombo") },
      "cờ chết đã gỡ — muốn dựng lại nhận diện ô search/combo thì đọc role TỪ "
        + "`fieldKind` (nó đã đọc role node trong cùng rồi), ĐỪNG thêm lần đọc thứ hai")
  }

  /// B1.2 — timeout AX có MỘT trạng thái ổn định, không phải "kẻ ghi sau thắng".
  ///
  /// Đặt timeout lên system-wide element là đặt MẶC ĐỊNH CHO CẢ TIẾN TRÌNH. Trước
  /// B1 có bốn chỗ cùng đặt, hai giá trị (0,05 và 0,1), từ hai thread, không chỗ
  /// nào khôi phục — nên timeout thực tế của MỌI truy vấn AX nhảy tuỳ đường nào
  /// chạy sau cùng. Nay trạng thái ổn định là `defaultAXTimeout`, còn chỗ cần
  /// ngắn hơn thì MƯỢN CÓ THỜI HẠN qua `withAXTimeout`.
  func testB1_2_AXTimeoutHasOneStableDefault() throws {
    XCTAssertEqual(Focused.defaultAXTimeout, 0.1, accuracy: 0.0001,
      "giá trị ổn định — `AppDelegate` cũng gọi setupAXTimeout(0.1)")
    XCTAssertGreaterThan(Focused.defaultAXTimeout, 0.05,
      "mặc định phải ≥ mọi giá trị mượn ngắn: xác suất đọc hụt kAXRole chỉ được GIẢM")

    // `withAXTimeout` là một scope, không phải một lần ghi: nó trả giá trị của
    // `body` ra ngoài và trả timeout về mặc định trong `defer`.
    XCTAssertEqual(Focused.withAXTimeout(0.05) { 42 }, 42)
    XCTAssertEqual(Focused.withAXTimeout(0.05) { "ok" }, "ok")
  }

  /// B1.3 — PID đích ĐI THEO LẦN GỬI, không được đọc lại từ global lúc flush.
  ///
  /// `axTargetPID` là hộp thư MỘT CHIỀU từ tap thread: đúng một người ghi
  /// (`EventHook.eventTapCallback`) và đúng một người đọc (`sendReplacement`,
  /// đọc ĐỒNG BỘ ngay lúc vào hàm, tức vẫn trong lần gọi tap callback đã ghi giá
  /// trị đó). Nhánh `.axDirect` flush TRỄ trên `simulationQueue`; nếu tầng dưới
  /// còn đọc lại global thì người dùng đổi app đúng giữa chừng sẽ khiến thao tác
  /// gửi của app A ghi AX vào ô đang focus của app B.
  ///
  /// Khoá bằng CHỮ KÝ: chỉ riêng việc gán dưới đây biên dịch được đã chứng minh
  /// PID đi bằng tham số. CỐ Ý KHÔNG GỌI hàm — `axDirectReplace` ghi thẳng vào ô
  /// đang focus của máy chạy test.
  func testB1_3_AxTargetPIDTravelsAsAParameter() throws {
    let signatureLock: [Any] = [
      EventSimulator.axDirectReplace(backspaceCount:insert:usesNFC:targetPID:)
        as (Int, String, Bool, pid_t) -> Bool
    ]
    XCTAssertEqual(signatureLock.count, 1,
      "axDirectReplace phải NHẬN targetPID; bỏ tham số này = quay lại đọc global lúc flush")

    // Biến global vẫn còn (tap thread cần chỗ để ghi) và vẫn là pid_t.
    let saved = EventSimulator.axTargetPID
    defer { EventSimulator.axTargetPID = saved }
    EventSimulator.axTargetPID = pid_t(4242)
    XCTAssertEqual(EventSimulator.axTargetPID, pid_t(4242))
  }
}


// MARK: - ===========================================
// MARK: - F4 — HAI NGÂN SÁCH AX, KHÔNG PHẢI MỘT
// MARK: - ===========================================
final class HotPathAXBudgetF4Tests: XCTestCase {

  /// F4 — `testB1_2_AXTimeoutHasOneStableDefault` khoá được "có MỘT mặc định ổn
  /// định", nhưng KHÔNG khoá được ngân sách của đường NÓNG — nên vòng B1 nâng
  /// `Focused.snapshot()` và `isSecureField()` từ 0,05 lên 0,1 mà 419 test vẫn
  /// xanh. Đó là nhân đôi cận trên thời gian chẹn event tap, ở đúng đường chạy
  /// mỗi phím, cho một lần leo cây tới ~50 message AX.
  ///
  /// Hai hằng vì có thật hai ngân sách: `defaultAXTimeout` cho việc chạy NGOÀI
  /// tap thread (`simulationQueue`, `focusRefreshQueue` — nơi nhịp trễ 0,5s tồn
  /// tại chính để chờ hộp thoại native hiện ra), `hotPathAXTimeout` cho mọi thứ
  /// chạy TRÊN tap thread.
  ///
  /// ⚠️ SAU VÒNG LÙI, HẰNG NÀY CÀNG CẦN CHỨ KHÔNG PHẢI BỚT CẦN. Đợt T3 từng gắn
  /// một cổng `if input.isAtWordBoundary` trước lời gọi chụp AX, tức mỗi TỪ mới
  /// chụp một lần; cổng đó đã lùi cùng chốt trục, nên `Focused.snapshot()` chạy
  /// lại MỖI keyDown như HEAD. Ai thấy "chỉ còn một chỗ gọi, gộp hai hằng cho
  /// gọn" thì đang nhân đôi cận trên thời gian chẹn event tap của đường chạy mỗi
  /// phím. Lý do lùi cổng: xem MARK "[ĐÃ XOÁ] test khoá cổng chụp AX theo ranh
  /// giới từ" phía trên.
  func testF4_HotPathAXBudgetIsSeparateFromTheBackgroundBudget() throws {
    XCTAssertEqual(Focused.hotPathAXTimeout, 0.05, accuracy: 0.0001,
      "ngân sách đường nóng — giá trị mà HEAD vô tình chốt lại qua focusedOverlayBundle()")
    XCTAssertEqual(Focused.defaultAXTimeout, 0.1, accuracy: 0.0001,
      "ngân sách nền — KHÔNG đổi ở đợt này")
    XCTAssertLessThan(Focused.hotPathAXTimeout, Focused.defaultAXTimeout,
      "gom hai hằng làm một là nâng cận trên chẹn tap của đường chạy mỗi phím")

    // `snapshot` phải NHẬN ngân sách. Chữ ký là chỗ duy nhất ép được điều đó:
    // nếu ai gỡ tham số, `performFocusedElementRefresh` hết đường xin ngân sách
    // nền và cả hai người gọi lại dùng chung một con số.
    // CỐ Ý KHÔNG GỌI — `snapshot()` đọc AX của máy đang chạy test.
    let signatureLock: [Any] = [
      Focused.snapshot(timeout:) as (Float) -> Focused.FocusSnapshot,
      Focused.focusedElement(timeout:) as (Float) -> AXUIElement?
    ]
    XCTAssertEqual(signatureLock.count, 2,
      "Focused.snapshot + focusedElement phải nhận `timeout:` — fetch system-wide "
        + "tách khỏi leo cây element-scope")

    // `withAXTimeout` vẫn là SCOPE (mượn có thời hạn), không phải một lần ghi.
    XCTAssertEqual(Focused.withAXTimeout(Focused.hotPathAXTimeout) { 7 }, 7)
  }
}
