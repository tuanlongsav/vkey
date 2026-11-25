import XCTest
import Defaults
@testable import vkey

final class PlumeEmitNFCTests: SpellResetTestCase {
  func testPlumeMessengerBubbleUsesNFC() throws {
    // (1) Số học — cả lớp "thanh trên nguyên âm đã có mũ/móc".
    let toneOnMarked: [(String, String)] = [
      ("chư", "chứ"), ("đê", "để"), ("đê", "đề"), ("vê", "về"),
      ("tô", "tố"), ("gơ", "gở"), ("â", "ấ"), ("ă", "ặ"),
      ("điêu", "điều"), ("tiêng", "tiếng"),
    ]
    for (from, to) in toneOnMarked {
      let (nfcBs, _) = EventSimulator.calcKeyStrokes(from: from, to: to, usesNFC: true)
      let (nfdBs, _) = EventSimulator.calcKeyStrokes(from: from, to: to, usesNFC: false)
      XCTAssertEqual(nfdBs, nfcBs + 1,
        "\(from)→\(to): NFD snap phải thừa đúng 1 so với NFC (nfc=\(nfcBs) nfd=\(nfdBs))")
    }

    XCTAssertTrue(InputProcessor.keepsCushionOnSmallDiffs(bundleId: "com.htl.plume"))
    XCTAssertTrue(InputProcessor.keepsCushionOnSmallDiffs(bundleId: "com.facebook.archon"),
      "Messenger Electron cùng Lexical — giữ cushion như Plume")
    XCTAssertFalse(InputProcessor.keepsCushionOnSmallDiffs(bundleId: "ru.keepcoder.Telegram"),
      "Telegram giữ P5 — không mở miễn trừ cushion toàn cục")
    guard case .stepByStep = EventSimulator.getStrategy(for: "com.htl.plume") else {
      return XCTFail("Plume phải stepByStep để Lexical không gộp backspace")
    }

    for kind in [Focused.FieldKind.webContent, .unknown, .windowField] {
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp("com.htl.plume")
      p.focusedFieldKind = kind
      XCTAssertTrue(p.usesNFCForFocusedField(), "Plume × \(kind) phải NFC")

      // chứ — regression gốc 4.26
      var last = ""
      p.newWord()
      for c in "chuws" {
        p.push(char: c)
        let r = p.emitPlan().replacement(from: last, to: p.transformed)
        if c == "s" {
          XCTAssertEqual(r.backspaceCount, 1, "Plume chuws@s: bs NFC=1, không phải NFD=2")
        }
        last = p.transformed
      }
      XCTAssertEqual(p.transformed, "chứ")

      // để — regression follow-up (mất đ → "ể"). Telex hỏi = `r`, không phải `f`
      // (f = huyền → "đề").
      last = ""
      p.newWord()
      for c in "ddeer" {
        p.push(char: c)
        let r = p.emitPlan().replacement(from: last, to: p.transformed)
        if c == "r" {
          XCTAssertEqual(r.backspaceCount, 1, "Plume ddeer@r: bs NFC=1 — NFD=2 sẽ ăn mất đ")
        }
        last = p.transformed
      }
      XCTAssertEqual(p.transformed, "để")

      // về / dở — cùng lớp thanh trên nguyên âm đã mũ/móc (mất phụ âm → "ề"/"ở").
      for (keys, want) in [("veef", "về"), ("dowr", "dở")] {
        last = ""
        p.newWord()
        var toneKey: Character?
        if keys.hasSuffix("f") { toneKey = "f" }
        if keys.hasSuffix("r") { toneKey = "r" }
        for c in keys {
          p.push(char: c)
          let r = p.emitPlan().replacement(from: last, to: p.transformed)
          if c == toneKey {
            XCTAssertEqual(r.backspaceCount, 1, "Plume \(keys)@\(c): bs NFC=1 (NFD=2 ăn phụ âm)")
            XCTAssertFalse(r.diffChars.isEmpty)
          }
          last = p.transformed
        }
        XCTAssertEqual(p.transformed, want, "Plume \(keys)")
      }

      // "fix" — tiếng Anh có phím dấu Telex bao quanh: f…x. Engine biến fi→fĩ
      // (bs=1, nuốt x). Nếu gửi NFD/thừa BS sẽ thành "fx" (mất i).
      last = ""
      p.newWord()
      var fixTrace: [(Character, String, Int, String)] = []
      for c in "fix" {
        p.push(char: c)
        let r = p.emitPlan().replacement(from: last, to: p.transformed)
        fixTrace.append((c, p.transformed, r.backspaceCount, String(r.diffChars)))
        last = p.transformed
      }
      XCTAssertEqual(p.transformed, "fĩ", "Telex 'fix' đặt ngã lên i → fĩ, không phải giữ 'fix'")
      if let xStep = fixTrace.last {
        XCTAssertEqual(xStep.2, 1, "fix@x bs phải 1 — bs≥2 hoặc bs=1+pass-through x → 'fx'. trace=\(fixTrace)")
        XCTAssertEqual(xStep.3, "ĩ", "fix@x phải retype ĩ (nuốt phím x), không thả x thật. trace=\(fixTrace)")
      }
    }
  }

  /// Regression — Telegram gõ "gửi" ra "ửi" (mất chữ ĐẦU). Khác lớp với
  /// testDieuTelegramFix: đây KHÔNG phải NFC/NFD (Telegram đã whitelist NFC), mà
  /// là race của synthetic backspace + retype ở `.hybrid` — compose view custom
  /// của Telegram xử lý async nên rớt ký tự đầu khi thay cả cụm. Fix: định tuyến
  /// `.stepByStep` (gửi từng phím) như Dock/Launchpad + Claude. Test khoá entry.
}

final class EmitPlanWordLockT3Tests: XCTestCase {

  /// Electron ngoài whitelist NFC — cùng lớp với Zalo/Messenger/Discord. Ở app
  /// này `fieldKind` MỚI thật sự quyết định trục (whitelist NFC short-circuit
  /// trước `fieldKind`, nên app Apple/Telegram không dựng được ca lật trục).
  private static let electronApp = "com.tinyspeck.slackmacgap"
  private static let browserApp = "com.google.Chrome"

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

  // MARK: T4 — phép đo, viết thành assert chạy được

  /// T4 — hai đơn vị xoá, hai cách đếm, và VÌ SAO CẢ HAI ĐỀU ĐÚNG.
  ///
  /// Đây là bản chạy được của bảng đo ở đầu file. Nó khoá đúng ba con số mà mọi
  /// lập luận về trục dựa vào — nếu ai đó "tối ưu" `calcKeyStrokes*` và một trong
  /// ba con số đổi, thì lập luận "trục hiện tại đúng" hết hiệu lực và test này đỏ
  /// TRƯỚC khi người dùng mất chữ.
  func testT4_DeleteUnitPerEngineMatchesTheCountingAxis() throws {
    // Vật liệu của phép đo: `x` + `ề`.
    let sample = "xề"
    XCTAssertEqual(sample.precomposedStringWithCanonicalMapping.unicodeScalars.count, 2,
      "NFC: x + U+1EC1")
    XCTAssertEqual(sample.decomposedStringWithCanonicalMapping.unicodeScalars.count, 4,
      "NFD: x + e + U+0302 + U+0300 — đúng 4 scalar mà probe đã đặt vào ô")

    // AppKit xoá theo GRAPHEME: 1 Backspace ăn trọn cụm 3 scalar (4 → 1).
    // vkey cho field NFC đếm theo grapheme ⇒ 1. Khớp với 1 lần nhấn.
    let (nfcBs, nfcDiff) = EventSimulator.calcKeyStrokes(from: sample, to: "x")
    XCTAssertEqual(nfcBs, 1, "trục NFC đếm grapheme = đúng số phím AppKit cần")
    XCTAssertTrue(nfcDiff.isEmpty)

    // Blink xoá theo SCALAR: mỗi Backspace bóc 1 scalar, nên phải nhấn 3 lần để
    // hết cụm NFD 3 scalar. vkey cho field NFD đếm theo scalar ⇒ 3. Khớp.
    let (nfdBs, nfdDiff) = EventSimulator.calcKeyStrokesNFD(from: sample, to: "x")
    XCTAssertEqual(nfdBs, 3, "trục NFD đếm scalar = đúng số phím Blink cần")
    XCTAssertTrue(nfdDiff.isEmpty)

    // 1 vs 3 — ĐỘ LỆCH mà một lần lật trục giữa từ tạo ra. Đây là lý do T3 tồn
    // tại: không phải để đổi trục, mà để trục KHÔNG ĐỔI GIỮA CHỪNG.
    XCTAssertNotEqual(nfcBs, nfdBs)

    // Và đây là vì sao nhánh NFC vẫn đúng dù Blink xoá theo scalar: ở dạng NFC,
    // 1 grapheme ĐÚNG BẰNG 1 scalar, nên đếm grapheme ra cùng con số với đếm
    // scalar. Bất biến v4.15 ("phát NFC ⇒ ô giữ NFC") là thứ giữ tiền đề này.
    let nfc = sample.precomposedStringWithCanonicalMapping
    XCTAssertEqual(nfc.count, nfc.unicodeScalars.count,
      "ở dạng NFC, đếm grapheme == đếm scalar ⇒ nhánh NFC khớp cả engine xoá scalar")

    // Bảng gán trục — hai đầu mút mà phép đo T4 xác nhận. KHÔNG ĐỔI CÁC DÒNG NÀY.
    let electron = InputProcessor(method: .Telex)
    electron.changeActiveApp(Self.electronApp)
    electron.focusedFieldKind = .webContent
    XCTAssertFalse(electron.usesNFCForFocusedField(),
      "contenteditable của Electron: Blink xoá scalar + vkey phát NFD ⇒ trục NFD. ĐÚNG.")

    let chrome = InputProcessor(method: .Telex)
    chrome.changeActiveApp(Self.browserApp)
    chrome.focusedFieldKind = .webContent
    XCTAssertTrue(chrome.usesNFCForFocusedField(),
      "web content của TRÌNH DUYỆT: vkey phát NFC ⇒ 1 grapheme == 1 scalar ⇒ trục NFC. ĐÚNG.")
  }


  // MARK: [KHÔNG HỒI QUY] — ô ổn định ⇒ giống hệt hành vi cũ

  /// [KHÔNG HỒI QUY] — với ô ỔN ĐỊNH, chuỗi (bs, diff) của HEAD GIỐNG HỆT thuật
  /// toán TIỀN-T3, trên cả nhánh NFC lẫn nhánh NFD, và trục/chiến-lược-gửi mà
  /// chốt mang theo đúng bằng giá trị hai resolver trả về.
  ///
  /// ĐÂY LÀ BẰNG CHỨNG "ĐỢT NÀY KHÔNG ĐỔI TRỤC CỦA AI". Bảng dưới liệt kê tường
  /// minh trục kỳ vọng cho từng ô — nếu một bản vá sau này đổi trục của bất kỳ
  /// app nào, test đỏ ở đúng dòng đó, kèm tên app.
  func testT3_StableFieldEmitsExactlyThePreT3Sequence() throws {
    // (app, fieldKind, trục NFC?, browser-chrome?)
    let table: [(String, Focused.FieldKind, Bool, Bool)] = [
      // Nhánh NFD — Electron ngoài whitelist (lớp Zalo/Messenger/Discord).
      (Self.electronApp, .webContent, false, false),
      (Self.electronApp, .unknown, false, false),
      // …trừ chính ô cửa sổ: `.windowField` đi trục NFC ĐÚNG VÌ nó gửi bằng
      // axDirect, mà `axDeleteStart` xoá theo grapheme. Hai vế phải cùng chốt.
      (Self.electronApp, .windowField, true, true),
      (Self.electronApp, .nativePanel, true, false),
      // Nhánh NFC — trình duyệt thật.
      (Self.browserApp, .webContent, true, false),
      (Self.browserApp, .unknown, true, false),
      (Self.browserApp, .windowField, true, true),  // omnibox
      (Self.browserApp, .nativePanel, true, false),
      // Whitelist NFC — short-circuit TRƯỚC fieldKind, nên fieldKind không đổi
      // được gì (và browser-chrome phải TẮT, nếu không axDirect tràn ra mọi cửa sổ).
      ("com.apple.Notes", .webContent, true, false),
      ("com.apple.TextEdit", .windowField, true, false),
      ("ru.keepcoder.Telegram", .webContent, true, false),
      ("com.sublimetext.4", .unknown, true, false),
    ]

    for (app, kind, expectNFC, expectChrome) in table {
      for word in ["tieengs", "ddieeuf"] {
        // HEAD — mọi lần gửi lấy kế hoạch từ chốt.
        let head = InputProcessor(method: .Telex)
        head.changeActiveApp(app)
        head.focusedFieldKind = kind
        var headSeq: [T3EmitStep] = []
        for c in word {
          head.push(char: c)
          let r = head.emitPlan().replacement(from: head.lastTransformed, to: head.transformed)
          headSeq.append(T3EmitStep(r.backspaceCount, r.diffChars))
        }

        // TIỀN-T3 — đo field lại ở mỗi phím. Ô đứng yên nên phải ra y hệt.
        let old = InputProcessor(method: .Telex)
        old.changeActiveApp(app)
        old.focusedFieldKind = kind
        var oldSeq: [T3EmitStep] = []
        for c in word {
          old.push(char: c)
          let (bs, diff) = EventSimulator.calcKeyStrokes(
            from: old.lastTransformed, to: old.transformed,
            usesNFC: old.usesNFCForFocusedField())
          oldSeq.append(T3EmitStep(bs, diff))
        }

        XCTAssertEqual(headSeq, oldSeq,
          "\(app) × \(kind) × \"\(word)\": ô ổn định PHẢI phát giống hệt bản tiền-T3")
        XCTAssertEqual(head.transformed, old.transformed)
        XCTAssertFalse(headSeq.isEmpty, "lưới an toàn: chuỗi rỗng thì so sánh trên là vô nghĩa")
      }

      // Chốt mang đúng giá trị hai resolver trả về — T3 giữ nguyên BẢNG ánh xạ
      // app × field → trục, chỉ đổi THỜI ĐIỂM đọc nó.
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp(app)
      p.focusedFieldKind = kind
      p.push(char: "a")
      let plan = p.emitPlan()
      XCTAssertEqual(plan.usesNFC, expectNFC, "\(app) × \(kind): trục")
      XCTAssertEqual(plan.usesNFC, p.usesNFCForFocusedField(),
        "\(app) × \(kind): chốt phải bằng resolver, không được lệch")
      XCTAssertEqual(plan.fieldIsBrowserChrome, expectChrome, "\(app) × \(kind): axDirect?")
      XCTAssertEqual(plan.fieldIsBrowserChrome, p.focusedFieldIsBrowserChrome(),
        "\(app) × \(kind): vế chiến lược gửi cũng phải bằng resolver")
    }
  }

  /// [KHÔNG HỒI QUY] — Backspace: trục dùng để ĐẾM bên trong `WordBuffer.pop`
  /// đúng bằng trục sẽ PHÁT ra (bất biến v4.15, nay do KIỂU giữ).
  ///
  /// `pop` là đường duy nhất mà số đếm được tính ở NƠI KHÁC (nó phải replay
  /// state trước khi đếm), nên nó cũng là chỗ dễ tuột nhất khỏi bất biến. Test
  /// đối chiếu `pop(plan:)` với `pop(usesNFC:)` thô trên hai processor giống hệt.
  func testT3_PopCountsAndEmitsOnTheSameLockedAxis() throws {
    for (app, kind) in [(Self.electronApp, Focused.FieldKind.webContent),
                        (Self.browserApp, .windowField)] {
      let viaPlan = InputProcessor(method: .Telex)
      viaPlan.changeActiveApp(app)
      viaPlan.focusedFieldKind = kind
      for c in "ddieeuf" { viaPlan.push(char: c) }
      XCTAssertEqual(viaPlan.transformed, "điều")

      let plan = viaPlan.emitPlan()
      let r = viaPlan.pop(plan: plan)
      XCTAssertEqual(r.plan.usesNFC, plan.usesNFC,
        "số đếm và trục phát PHẢI đi chung một giá trị")

      let viaRaw = InputProcessor(method: .Telex)
      viaRaw.changeActiveApp(app)
      viaRaw.focusedFieldKind = kind
      for c in "ddieeuf" { viaRaw.push(char: c) }
      let (bs, diff) = viaRaw.pop(usesNFC: plan.usesNFC)

      XCTAssertEqual(T3EmitStep(r.backspaceCount, r.diffChars), T3EmitStep(bs, diff),
        "\(app) × \(kind): pop(plan:) phải ra đúng cái pop(usesNFC:) ra")
    }
  }


  // MARK: F1 — chốt NFD sau lần gửi có backspace (khác chốt-theo-từ đã lùi)

  /// Electron web content: sau lần gửi NFD đầu tiên có `bs > 0`, hiccup AX đổi
  /// `.webContent` → `.windowField` giữa từ KHÔNG được lật trục sang NFC.
  func testF1_NfdEmitPlanSurvivesMidWordFieldFlip() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(Self.electronApp)
    p.focusedFieldKind = .webContent

    let word = "tieengs"
    var lockedSeq: [T3EmitStep] = []
    for (i, c) in word.enumerated() {
      p.push(char: c)
      let r = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      if !r.isEmpty {
        p.recordConsequentialEmitForTests(r)
        lockedSeq.append(T3EmitStep(r.backspaceCount, r.diffChars))
      }
      if i == 4 { p.focusedFieldKind = .windowField }
    }

    let baseline = InputProcessor(method: .Telex)
    baseline.changeActiveApp(Self.electronApp)
    baseline.focusedFieldKind = .webContent
    var baseSeq: [T3EmitStep] = []
    for c in word {
      baseline.push(char: c)
      let r = baseline.emitPlan().replacement(
        from: baseline.lastTransformed, to: baseline.transformed)
      if !r.isEmpty {
        baseSeq.append(T3EmitStep(r.backspaceCount, r.diffChars))
      }
    }

    XCTAssertEqual(lockedSeq, baseSeq,
      "chốt NFD sau bs>0 phải giữ chuỗi phát ổn định dù fieldKind dao động")
    XCTAssertFalse(p.emitPlan().usesNFC, "vẫn trên nhánh NFD sau flip")
  }

  /// Hộp thoại Lưu (nativePanel/NFC): không kích hoạt chốt NFD — AX vẫn được đo
  /// lại mỗi phím để tự hội tụ NFC.
  func testF1_NativePanelNeverArmsNfdLockSoAxisCanSelfHeal() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(Self.electronApp)
    p.focusedFieldKind = .nativePanel

    for c in "nooij" {
      p.push(char: c)
      let r = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      if !r.isEmpty { p.recordConsequentialEmitForTests(r) }
    }
    XCTAssertTrue(p.emitPlan().usesNFC, "nativePanel ⇒ NFC")

    p.focusedFieldKind = .unknown
    XCTAssertFalse(p.emitPlan().usesNFC,
      "không có chốt NFD ⇒ hiccup về .unknown vẫn đo lại, không đóng băng NFC")
  }

  /// `.unknown` không đủ tin cậy để chốt — tránh đóng băng NFD khi hộp thoại Lưu
  /// vừa mở mà AX chưa kịp báo `.nativePanel`.
  func testF1_UnknownFieldKindNeverArmsNfdLock() throws {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(Self.electronApp)
    p.focusedFieldKind = .unknown

    for c in "tuw" {
      p.push(char: c)
      let r = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      if !r.isEmpty { p.recordConsequentialEmitForTests(r) }
    }

    p.focusedFieldKind = .nativePanel
    XCTAssertTrue(p.emitPlan().usesNFC,
      ".unknown không chốt NFD ⇒ chuyển sang nativePanel vẫn đo lại NFC")
  }
}


// MARK: - ===========================================
// MARK: - EmitPlan — BẤT BIẾN v4.15 GIỜ DO KIỂU GIỮ
// MARK: - ===========================================
//
// ĐÂY LÀ GIÁ TRỊ CÒN LẠI CỦA CẢ ĐỢT, sau khi chốt trục theo từ, cổng chụp AX theo
// ranh giới từ và sticky-on-miss đều đã lùi.
//
//   Bất biến v4.15: dạng dùng để ĐẾM backspace phải ĐÚNG BẰNG dạng PHÁT ra.
//   Vi phạm = số backspace lệch scalar = ăn ngược vào chữ đã gõ. Đó chính là
//   v4.14 ("gửi" → "ửi"), hồi quy nặng nhất lịch sử repo.
//
// Trước đây bất biến ấy chỉ là QUY ƯỚC: mỗi call site tự gọi
// `usesNFCForFocusedField()`, tự NHỚ truyền đúng cái `Bool` đó xuống transport, và
// người review phải tự kiểm 13 chỗ. Giờ số đếm và trục đi chung MỘT giá trị:
// `EmitPlan.Replacement.init` là `fileprivate` nên chỉ factory của `EmitPlan` dựng
// được, mọi đường dựng đều đếm bằng CHÍNH trục của plan đó, và transport nhận
// `normalizeToNFC: replacement.plan.usesNFC` chứ không phải một tham số rời.
//
// ⚠️ `EmitPlan` KHÔNG NHỚ GÌ. `emitPlan()` đo lại mỗi lần gọi, hệt HEAD — đó là
// điều `HeadParityGoldenTests` ngay dưới chứng minh bằng số. Đừng đọc lớp này như
// di tích của chốt: chốt đã gỡ, cái này thì không.
//
// Lớp dưới khoá cả hai vế. Vế CHẠY ĐƯỢC: mọi đường dựng đếm đúng trục của mình, và
// dạng đi ra dây có đúng số scalar như lúc đếm. Vế KHÔNG DIỄN ĐẠT ĐƯỢC BẰNG ASSERT
// ("không còn đường nào khác để một trục lạ tới được transport") phải kiểm ở mức
// NGUỒN — một `Replacement` dựng lậu làm test KHÔNG BIÊN DỊCH chứ không đỏ, nên
// không có cách nào viết nó thành `XCTAssert`.
final class EmitPlanTypeConstraintTests: XCTestCase {

  /// Electron ngoài whitelist NFC (lớp Zalo/Messenger/Slack/Discord) — app DUY
  /// NHẤT mà `fieldKind` thật sự quyết định trục, nên là chỗ duy nhất dựng được
  /// hai trục cạnh nhau để so.
  private static let electronApp = "com.tinyspeck.slackmacgap"
  private static let browserApp = "com.google.Chrome"

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

  /// Dựng một bước phát THẬT có mang dấu: gõ "tieeng" rồi phím `s`, tức
  /// `lastTransformed == "tiêng"` → `transformed == "tiếng"`, diff = "ếng".
  /// Bước này được chọn vì nó là bước DUY NHẤT trong từ mà hai trục cho hai số
  /// backspace khác nhau — mọi assert dưới đây vô nghĩa nếu chọn bước khác.
  private func processorAtToneStep(app: String, kind: Focused.FieldKind) -> InputProcessor {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(app)
    p.focusedFieldKind = kind
    for c in "tieengs" { p.push(char: c) }
    return p
  }

  /// (1) MỌI đường dựng `Replacement` đều đếm bằng CHÍNH trục của plan sinh ra nó,
  /// và trục ấy ĐI THEO giá trị chứ không nằm rời ở đâu đó.
  ///
  /// Ba đường dựng, đủ bộ: `replacement(from:to:)` (đường chính),
  /// `insertion(of:)` (dự đoán từ / lưới an toàn auto-capitalize), và
  /// `pop(plan:)` (cầu nối duy nhất cho số đếm tính ở nơi khác — `WordBuffer.pop`
  /// phải replay state trước khi đếm nên không đếm hộ từ `EmitPlan` được).
  func testEveryConstructionPathCountsOnItsOwnPlansAxis() throws {
    for (app, kind) in [(Self.electronApp, Focused.FieldKind.webContent),
                        (Self.browserApp, Focused.FieldKind.webContent),
                        (Self.electronApp, Focused.FieldKind.windowField)] {
      let p = processorAtToneStep(app: app, kind: kind)
      let plan = p.emitPlan()

      // LƯỚI CHỐNG TEST RỖNG, đặt TRƯỚC mọi assert khác: bước này phải phân biệt
      // được hai trục, nếu không thì "đếm đúng trục" đúng một cách vô nghĩa.
      let onPlanAxis = EventSimulator.calcKeyStrokes(
        from: p.lastTransformed, to: p.transformed, usesNFC: plan.usesNFC)
      let onOtherAxis = EventSimulator.calcKeyStrokes(
        from: p.lastTransformed, to: p.transformed, usesNFC: !plan.usesNFC)
      XCTAssertNotEqual(
        T3EmitStep(onPlanAxis.0, onPlanAxis.1), T3EmitStep(onOtherAxis.0, onOtherAxis.1),
        "\(app) × \(kind): bước 'tiêng'→'tiếng' PHẢI cho hai số khác nhau ở hai trục")

      // (a) đường chính
      let r = plan.replacement(from: p.lastTransformed, to: p.transformed)
      XCTAssertEqual(r.plan.usesNFC, plan.usesNFC,
        "trục ĐI THEO giá trị `Replacement`, không phải một Bool rời bên cạnh")
      XCTAssertEqual(r.plan.fieldIsBrowserChrome, plan.fieldIsBrowserChrome,
        "đường gửi cũng đi cùng — tách hai vế là mở lại cửa cho 'trường'→'truường'")
      XCTAssertEqual(T3EmitStep(r.backspaceCount, r.diffChars),
                     T3EmitStep(onPlanAxis.0, onPlanAxis.1),
        "\(app) × \(kind): số đếm phải là số của trục TRONG plan")

      // (b) chèn thuần — không có backspace nào để lệch, nhưng trục vẫn phải
      //     đi theo vì transport dùng nó để chọn dạng emit.
      let ins = plan.insertion(of: Array("ếng"))
      XCTAssertEqual(ins.backspaceCount, 0, "insertion không xoá gì")
      XCTAssertEqual(ins.plan.usesNFC, plan.usesNFC)
      XCTAssertEqual(ins.plan.fieldIsBrowserChrome, plan.fieldIsBrowserChrome)

      // (c) `pop(plan:)` — trục dùng để replay/đếm BÊN TRONG `WordBuffer.pop`
      //     đúng bằng trục sẽ phát ra.
      let popped = p.pop(plan: plan)
      XCTAssertEqual(popped.plan.usesNFC, plan.usesNFC)
      let raw = processorAtToneStep(app: app, kind: kind).pop(usesNFC: plan.usesNFC)
      XCTAssertEqual(T3EmitStep(popped.backspaceCount, popped.diffChars),
                     T3EmitStep(raw.0, raw.1),
        "\(app) × \(kind): pop(plan:) phải ra đúng cái pop(usesNFC: plan.usesNFC) ra")
    }
  }

  /// (2) DẠNG ĐI RA DÂY == DẠNG ĐÃ ĐẾM. Bất biến v4.15 viết thành số scalar.
  ///
  /// `EventSimulator.sendReplacement` KHÔNG phát thẳng `diffChars`: nó chạy qua
  /// `emittedCharacters(_:normalizeToNFC:)` trước. Nếu `normalizeToNFC` khác trục
  /// đã đếm, số scalar THỰC PHÁT khác số scalar đã đếm backspace — đó đúng là hình
  /// dạng của v4.14. Test đo cả chiều đúng lẫn chiều sai.
  func testWireFormHasTheSameScalarCountAsTheCountedForm() throws {
    for (app, kind) in [(Self.electronApp, Focused.FieldKind.webContent),
                        (Self.browserApp, Focused.FieldKind.webContent)] {
      let p = processorAtToneStep(app: app, kind: kind)
      let counted = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      let countedScalars = String(counted.diffChars).unicodeScalars.count

      // CHIỀU ĐÚNG — đúng tham số mà `sendTypedReplacement` truyền xuống.
      let wire = EventSimulator.emittedCharacters(
        counted.diffChars, normalizeToNFC: counted.plan.usesNFC)
      XCTAssertEqual(String(wire).unicodeScalars.count, countedScalars,
        "\(app) × \(kind): transport KHÔNG được đổi số scalar so với lúc đếm")

      // CHIỀU SAI — cùng `diffChars`, trục ngược. Chỉ nhánh NFD quan sát được:
      // precompose bóp cụm NFD lại, phát ÍT scalar hơn số backspace đã đếm.
      // (Nhánh NFC vô hại theo đúng phép đo T4 — ở dạng NFC 1 grapheme đã bằng 1
      // scalar nên `normalizeToNFC: false` không đổi gì. Đó là lý do trục sai
      // KHÔNG ĐỐI XỨNG, và cũng là một trong ba lý do lùi chốt theo từ.)
      let wrongWire = EventSimulator.emittedCharacters(
        counted.diffChars, normalizeToNFC: !counted.plan.usesNFC)
      if counted.plan.usesNFC {
        XCTAssertEqual(String(wrongWire).unicodeScalars.count, countedScalars,
          "\(app): trục NFC — 1 grapheme == 1 scalar nên chiều ngược vô hại (T4)")
      } else {
        XCTAssertLessThan(String(wrongWire).unicodeScalars.count, countedScalars,
          "\(app): trục NFD + normalizeToNFC=true ⇒ phát ít scalar hơn số đã đếm "
            + "backspace = ăn mất ký tự trước nguyên âm mang dấu. ĐÂY là v4.14.")
      }
    }
  }

  /// (3) KHÔNG CÒN ĐƯỜNG NÀO KHÁC để một trục lạ tới được transport.
  ///
  /// Vế này không viết thành assert chạy được: dựng lậu một `Replacement` làm test
  /// KHÔNG BIÊN DỊCH chứ không đỏ. Nên kiểm ở mức NGUỒN, mức TOKEN, và tự bỏ qua
  /// nếu không đọc được file (test có thể chạy trên máy khác nơi biên dịch).
  ///
  /// Bốn thứ được khoá, mỗi thứ là một cách khác nhau để bất biến v4.15 tuột:
  ///   (a) `init` của `Replacement` còn `fileprivate`;
  ///   (b) mọi chỗ dựng `Replacement(plan:` nằm TRONG `struct EmitPlan`;
  ///   (c) cả cây `vkey/` có ĐÚNG MỘT chỗ gọi `EventSimulator.sendReplacement(`;
  ///   (d) và chỗ đó truyền `normalizeToNFC: replacement.plan.usesNFC`.
  func testTheAxisCannotReachTransportByAnyOtherRoute() throws {
    let repoRoot = vkeyRepoRootURL()
    let emitPlanPath = repoRoot.appendingPathComponent("vkey/Input/EmitPlan.swift")
    let ipPath = repoRoot.appendingPathComponent("vkey/App/InputProcessor.swift")
    guard
      let emitPlanSrc = try? String(contentsOf: emitPlanPath, encoding: .utf8),
      let ipSrc = try? String(contentsOf: ipPath, encoding: .utf8)
    else {
      throw XCTSkip("không đọc được \(emitPlanPath.path) / \(ipPath.path) — lưới bổ sung, bỏ qua")
    }
    let emitPlanLines = emitPlanSrc.components(separatedBy: "\n")
    let ipLines = ipSrc.components(separatedBy: "\n")
    func isCode(_ l: String) -> Bool {
      let t = l.trimmingCharacters(in: .whitespaces)
      return !t.hasPrefix("//") && !t.hasPrefix("///") && !t.hasPrefix("*")
    }

    // (a)
    XCTAssertTrue(
      emitPlanLines.contains { isCode($0) && $0.contains("fileprivate init(plan: EmitPlan") },
      "`EmitPlan.Replacement.init` phải còn `fileprivate`. Nới nó ra là trả bất biến "
        + "v4.15 về làm quy ước review — đúng trạng thái đã đẻ ra v4.14 (\"gửi\"→\"ửi\").")

    // (b) — thân `struct EmitPlan` = từ dòng khai báo tới `// MARK:` kế tiếp.
    guard let planDecl = emitPlanLines.firstIndex(where: { isCode($0) && $0.hasPrefix("struct EmitPlan") })
    else {
      return XCTFail("`struct EmitPlan` đã biến mất khỏi EmitPlan.swift")
    }
    let planEnd = emitPlanLines[(planDecl + 1)...].firstIndex { $0.hasPrefix("// MARK:") } ?? emitPlanLines.endIndex
    let planRange = planDecl..<planEnd
    for i in emitPlanLines.indices where isCode(emitPlanLines[i]) && emitPlanLines[i].contains("Replacement(plan:") {
      XCTAssertTrue(planRange.contains(i),
        "EmitPlan.swift:\(i + 1) dựng `Replacement` NGOÀI `EmitPlan`. Mọi đường "
          + "dựng phải đếm bằng chính trục của plan; một đường ngoài là một đường "
          + "truyền lệch trục xuống transport.")
    }

    // (c) — quét CẢ cây nguồn, không chỉ file này.
    let appRoot = repoRoot.appendingPathComponent("vkey")
    var callSites: [String] = []
    if let walker = FileManager.default.enumerator(atPath: appRoot.path) {
      for case let rel as String in walker where rel.hasSuffix(".swift") {
        // Bản thân transport khai báo hàm; chỉ đếm NGƯỜI GỌI.
        if rel.hasSuffix("EventSimulator.swift") { continue }
        let p = appRoot.appendingPathComponent(rel)
        guard let text = try? String(contentsOf: p, encoding: .utf8) else { continue }
        for (n, l) in text.components(separatedBy: "\n").enumerated()
        where isCode(l) && l.contains("EventSimulator.sendReplacement(") {
          callSites.append("\(rel):\(n + 1)")
        }
      }
    }
    XCTAssertEqual(callSites.count, 1,
      "transport chỉ được có MỘT người gọi (`sendTypedReplacement`). Thêm người gọi "
        + "thứ hai là thêm một chỗ tự chọn `normalizeToNFC`. Thấy: \(callSites)")
    XCTAssertTrue(callSites.first?.contains("InputProcessor.swift") ?? false,
      "…và người gọi đó phải là `InputProcessor.sendTypedReplacement`. Thấy: \(callSites)")

    // (d) — và người gọi đó lấy trục TỪ CHÍNH `replacement`.
    let nfcArgs = ipLines.filter { isCode($0) && $0.contains("normalizeToNFC:") }
      .map { $0.trimmingCharacters(in: .whitespaces) }
    XCTAssertEqual(nfcArgs, ["normalizeToNFC: replacement.plan.usesNFC"],
      "trục xuống transport phải đọc từ chính `Replacement` đã đếm ra số backspace. "
        + "Một `Bool` rời ở đây là hình dạng chính xác của hồi quy v4.14.")
  }
}


// MARK: - ===========================================
// MARK: - ĐỐI CHIẾU HEAD — chuỗi (bs, diff) VIẾT CỨNG
// MARK: - ===========================================
//
// ⚠️ SỐ TRONG BẢNG DƯỚI KHÔNG LẤY TỪ HÀNH VI HIỆN TẠI. Chúng được ĐO trên chính
// HEAD (commit 5e22d85 — trước B1/B2, tức trước `EmitPlan`), theo đúng cách này:
//
//   git archive HEAD | tar -x -C <tmp>/head          # bản HEAD sạch, NGOÀI repo
//   # thêm vào <tmp>/head/vkeyTests một test chỉ để in số, rồi:
//   xcodebuild -project vkey.xcodeproj -scheme vkey -destination 'platform=macOS' \
//     -derivedDataPath <tmp>/dd-head -only-testing:vkeyTests/<probe> test
//
// Đường đo trên HEAD chép nguyên văn `handleTextChar` của HEAD:
//   push(char:) → EventSimulator.calcKeyStrokes(from: lastTransformed,
//                   to: transformed, usesNFC: usesNFCForFocusedField())
// Backspace: `pop(usesNFC: usesNFCForFocusedField())`. Macro: `macroTarget(...)`
// rồi `calcKeyStrokes(from: current, to: target, usesNFC:)` — đúng số học của
// `expandMacroIfMatch`. (Chính hàm đó KHÔNG gọi được trong test: nó phát event
// thật vào ô đang focus của máy chạy test.)
//
// VÌ SAO CẦN BẢNG NÀY BÊN CẠNH `testT3_StableFieldEmitsExactlyThePreT3Sequence`.
// Test kia so HAI ĐƯỜNG TRONG CÙNG MỘT CÂY NGUỒN, mà cả hai vế đều gọi chính
// `EventSimulator.calcKeyStrokes` — nên một thay đổi trong THUẬT TOÁN DIFF đẩy cả
// hai vế lệch CÙNG CHIỀU và test kia vẫn xanh.
//
// Đã kiểm bằng ĐỘT BIẾN chứ không suy luận (chạy trên bản sao ngoài repo): tắt
// vòng lùi-prefix v3.6 trong `calcKeyStrokesNFD` (đổi điều kiện thành
// `if false && …`) thì CẢ BA test của `EmitPlanWordLockT3Tests` vẫn XANH, còn
// `testTypingSequencesMatchHeadExactly` dưới đây ĐỎ 8 chỗ. Đó chính xác là khoảng
// trống mà bảng vàng lấp: một mỏ neo NGOÀI cây nguồn.
//
// Chiều còn lại thì hai bên trùng nhau — đột biến bảng app × field → trục (cho
// `.webContent` trả `true` vô điều kiện) làm CẢ HAI cùng đỏ. Bảng vàng chỉ hơn ở
// thông điệp: nó nói thẳng app nào, ô nào, từ nào, và in ra cả hai chuỗi số.
//
// NÓ CŨNG LÀ BẰNG CHỨNG NGHIỆM THU CỦA VÒNG LÙI: sau khi gỡ chốt trục theo từ,
// cổng chụp AX và sticky-on-miss, hành vi phát ra phải trùng HEAD tới từng scalar.
//

final class HeadParityGoldenTests: XCTestCase {

  private static let electronApp = "com.tinyspeck.slackmacgap"
  private static let browserApp = "com.google.Chrome"
  private static let appleApp = "com.apple.Notes"

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

  // MARK: Bảng vàng, đo trên HEAD

  /// Trục NFD — đếm theo SCALAR. Ô Blink/Electron ngoài whitelist NFC: đúng lớp ô
  /// soạn tin Zalo / Messenger / Slack / Discord.
  private static let nfdGolden: [GoldenSeq] = [
    GoldenSeq(word: "tieengs", result: "tiếng", steps: [
      (0, "t", 1), (0, "i", 1), (0, "e", 1), (1, "ê", 2), (0, "n", 1), (0, "g", 1),
      (4, "ếng", 5),
    ]),
    GoldenSeq(word: "ddieeuf", result: "điều", steps: [
      (0, "d", 1), (1, "đ", 1), (0, "i", 1), (0, "e", 1), (1, "ê", 2), (0, "u", 1),
      (3, "ều", 4),
    ]),
    GoldenSeq(word: "nguoiwf", result: "người", steps: [
      (0, "n", 1), (0, "g", 1), (0, "u", 1), (0, "o", 1), (0, "i", 1),
      (3, "ươi", 5), (3, "ời", 4),
    ]),
    // `Nooij` là ca mà lời bàn về trục hay viện tới: chốt nhầm NFD trong một ô
    // AppKit làm nó ra `Ṇ̂i`. Độ lệch cụ thể nằm ở bước cuối — 3 backspace ở đây
    // so với 2 ở bảng NFC ngay dưới.
    GoldenSeq(word: "Nooij", result: "Nội", steps: [
      (0, "N", 1), (0, "o", 1), (1, "ô", 2), (0, "i", 1), (3, "ội", 4),
    ]),
  ]

  /// Trục NFC — đếm theo GRAPHEME. App Apple/whitelist, web content trình duyệt
  /// thật (từ v4.21), và ô cửa sổ (omnibox) của app nhóm NFD.
  private static let nfcGolden: [GoldenSeq] = [
    GoldenSeq(word: "tieengs", result: "tiếng", steps: [
      (0, "t", 1), (0, "i", 1), (0, "e", 1), (1, "ê", 1), (0, "n", 1), (0, "g", 1),
      (3, "ếng", 3),
    ]),
    GoldenSeq(word: "ddieeuf", result: "điều", steps: [
      (0, "d", 1), (1, "đ", 1), (0, "i", 1), (0, "e", 1), (1, "ê", 1), (0, "u", 1),
      (2, "ều", 2),
    ]),
    GoldenSeq(word: "nguoiwf", result: "người", steps: [
      (0, "n", 1), (0, "g", 1), (0, "u", 1), (0, "o", 1), (0, "i", 1),
      (3, "ươi", 3), (2, "ời", 2),
    ]),
    GoldenSeq(word: "Nooij", result: "Nội", steps: [
      (0, "N", 1), (0, "o", 1), (1, "ô", 1), (0, "i", 1), (2, "ội", 2),
    ]),
  ]

  /// Backspace: gõ trọn từ rồi bấm Delete 9 lần (nhiều hơn số phím đã gõ — để ca
  /// "xoá quá tay trên bộ đệm đã cạn" cũng nằm trong bảng).
  private static let nfdPopGolden: [(String, [(Int, String, Int)])] = [
    ("ddieeuf", [(2, "u", 1), (0, "", 0), (0, "", 0), (0, "", 0), (0, "", 0),
                 (1, "d", 1), (0, "", 0), (0, "", 0), (0, "", 0)]),
    ("tieengs", [(3, "ng", 2), (0, "", 0), (0, "", 0), (0, "", 0), (0, "", 0),
                 (0, "", 0), (0, "", 0), (0, "", 0), (0, "", 0)]),
  ]

  private static let nfcPopGolden: [(String, [(Int, String, Int)])] = [
    ("ddieeuf", [(2, "êu", 2), (0, "", 0), (1, "e", 1), (0, "", 0), (0, "", 0),
                 (1, "d", 1), (0, "", 0), (0, "", 0), (0, "", 0)]),
    ("tieengs", [(3, "êng", 3), (0, "", 0), (0, "", 0), (1, "e", 1), (0, "", 0),
                 (0, "", 0), (0, "", 0), (0, "", 0), (0, "", 0)]),
  ]

  // MARK: Tiện ích

  private func expected(_ g: (Int, String, Int)) -> T3EmitStep {
    T3EmitStep(golden: g.0, g.1, scalars: g.2)
  }

  /// Đường gõ THẬT của cây hiện tại: `push` → `emitPlan().replacement(from:to:)`.
  /// Đây đúng là dòng ở `handleTextChar`; đổi nó thì test này hết là đối chiếu.
  private func typeSequence(app: String, kind: Focused.FieldKind, word: String)
    -> (steps: [T3EmitStep], result: String)
  {
    let p = InputProcessor(method: .Telex)
    p.changeActiveApp(app)
    p.focusedFieldKind = kind
    var out: [T3EmitStep] = []
    for c in word {
      p.push(char: c)
      let r = p.emitPlan().replacement(from: p.lastTransformed, to: p.transformed)
      out.append(T3EmitStep(r.backspaceCount, r.diffChars))
    }
    return (out, p.transformed)
  }

  // MARK: Các bài đối chiếu

  /// (1) GÕ — gồm cả bỏ dấu cuối từ ("tieengs", "ddieeuf") lẫn thay CẢ CỤM
  /// ("nguoiwf": `w` viết lại "uo"→"ươ" giữa từ, rồi `f` viết lại "ươi"→"ời").
  ///
  /// Bảng ô ở đây cố ý phủ CẢ BỐN nhánh của việc gán trục, vì đó là thứ dễ bị
  /// "sửa" nhất: whitelist NFC (short-circuit TRƯỚC fieldKind), trình duyệt thật,
  /// Electron ngoài whitelist, và ô cửa sổ của app nhóm NFD.
  func testTypingSequencesMatchHeadExactly() throws {
    let cases: [(String, Focused.FieldKind, [GoldenSeq], Bool, Bool)] = [
      (Self.electronApp, .webContent, Self.nfdGolden, false, false),
      (Self.electronApp, .unknown, Self.nfdGolden, false, false),
      (Self.electronApp, .windowField, Self.nfcGolden, true, true),   // omnibox-like
      (Self.browserApp, .webContent, Self.nfcGolden, true, false),
      (Self.appleApp, .unknown, Self.nfcGolden, true, false),         // whitelist NFC
    ]

    for (app, kind, golden, expectNFC, expectChrome) in cases {
      // Bảng ánh xạ app × field → trục: khoá TRƯỚC, vì mọi con số dưới đây chỉ có
      // nghĩa khi ô này thật sự đang ở trục ta nghĩ.
      let probe = InputProcessor(method: .Telex)
      probe.changeActiveApp(app)
      probe.focusedFieldKind = kind
      XCTAssertEqual(probe.usesNFCForFocusedField(), expectNFC, "\(app) × \(kind): trục")
      XCTAssertEqual(probe.focusedFieldIsBrowserChrome(), expectChrome,
        "\(app) × \(kind): axDirect?")

      for g in golden {
        let got = typeSequence(app: app, kind: kind, word: g.word)
        XCTAssertEqual(got.result, g.result, "\(app) × \(kind) × \(g.word): engine")
        XCTAssertEqual(got.steps, g.steps.map(expected),
          "\(app) × \(kind) × \"\(g.word)\": chuỗi (bs, diff) LỆCH so với HEAD")
      }
    }
  }

  /// (2) BACKSPACE — đường duy nhất mà số đếm được tính ở nơi khác
  /// (`WordBuffer.pop` phải replay state trước khi đếm).
  func testBackspaceSequencesMatchHeadExactly() throws {
    let cases: [(String, Focused.FieldKind, [(String, [(Int, String, Int)])])] = [
      (Self.electronApp, .webContent, Self.nfdPopGolden),
      (Self.browserApp, .webContent, Self.nfcPopGolden),
      (Self.appleApp, .unknown, Self.nfcPopGolden),
    ]

    for (app, kind, golden) in cases {
      for (word, steps) in golden {
        let p = InputProcessor(method: .Telex)
        p.changeActiveApp(app)
        p.focusedFieldKind = kind
        for c in word { p.push(char: c) }

        var got: [T3EmitStep] = []
        for _ in 0..<steps.count {
          let r = p.pop(plan: p.emitPlan())   // = đúng dòng của nhánh `.Delete`
          got.append(T3EmitStep(r.backspaceCount, r.diffChars))
        }
        XCTAssertEqual(got, steps.map(expected),
          "\(app) × \(kind) × \"\(word)\": chuỗi Backspace LỆCH so với HEAD")
      }
    }
  }

  /// (3) MACRO — bung cả cụm một lần, và là đường phát có `diffChars` DÀI NHẤT
  /// trong vkey, nên cũng là chỗ độ lệch trục nhìn rõ nhất: "Việt Nam " đi ra dây
  /// là 11 scalar ở trục NFD nhưng 9 ở trục NFC.
  ///
  /// Bảng macro lấy `DefaultMacros.allDefaults` — bản seed sẵn cho mọi máy mới —
  /// chứ không phải `Defaults[.macros]`, vì tiến trình test không có bảng của
  /// người dùng. Số học thì y hệt `expandMacroIfMatch`.
  func testMacroExpansionMatchesHeadExactly() throws {
    let golden: [(String, Focused.FieldKind, [(String, String, Int, String, Int)])] = [
      (Self.electronApp, .webContent, [
        ("vn", "Việt Nam ", 2, "Việt Nam ", 11),
        ("hn", "Hà Nội ", 2, "Hà Nội ", 10),
      ]),
      (Self.browserApp, .webContent, [
        ("vn", "Việt Nam ", 2, "Việt Nam ", 9),
        ("hn", "Hà Nội ", 2, "Hà Nội ", 7),
      ]),
      (Self.appleApp, .unknown, [
        ("vn", "Việt Nam ", 2, "Việt Nam ", 9),
        ("hn", "Hà Nội ", 2, "Hà Nội ", 7),
      ]),
    ]

    for (app, kind, rows) in golden {
      for (trigger, target, bs, diffText, diffScalars) in rows {
        let p = InputProcessor(method: .Telex)
        p.changeActiveApp(app)
        p.focusedFieldKind = kind
        for c in trigger { p.push(char: c) }

        let current = p.transformed
        let got = try XCTUnwrap(
          InputProcessor.macroTarget(
            for: current, endingChar: " ", macros: DefaultMacros.allDefaults),
          "\(trigger): macro seed sẵn phải khớp — nếu không, ba assert dưới vô nghĩa")
        XCTAssertEqual(got, target, "\(trigger): phần bung")

        // Đúng dòng của `expandMacroIfMatch` trong cây hiện tại.
        let r = p.emitPlan().replacement(from: current, to: got)
        XCTAssertEqual(T3EmitStep(r.backspaceCount, r.diffChars),
                       T3EmitStep(golden: bs, diffText, scalars: diffScalars),
          "\(app) × \(kind) × macro \"\(trigger)\": LỆCH so với HEAD")
      }
    }
  }

  /// (4) LƯỚI CHỐNG BẢNG VÀNG RỖNG.
  ///
  /// Nếu hai bảng NFC/NFD trùng nhau thì ba bài trên xanh mà chẳng khoá được gì —
  /// đúng cái bẫy đã làm 419 test xanh trong khi hai lỗi mức CAO đi qua. Bài này
  /// assert rằng chúng KHÁC, và khác ở SỐ BACKSPACE (chỗ ăn mất chữ), chứ không
  /// phải chỉ ở số scalar (chỗ hiển thị).
  ///
  /// Đồng thời ghi lại phép đo T4 dưới dạng bất đẳng thức: `Nooij` cần 2 backspace
  /// ở ô AppKit (xoá GRAPHEME) và 3 ở ô Blink (xoá SCALAR). Chốt nhầm trục NFD
  /// trong ô AppKit ⇒ gửi thừa 1 backspace ⇒ ăn ngược vào chữ đã gõ (`Ṇ̂i`); chốt
  /// nhầm trục NFC trong ô Blink thì KHÔNG có độ lệch nào — trục sai không đối
  /// xứng, và đó là một trong ba lý do lùi chốt theo từ.
  func testTheTwoGoldenTablesActuallyDiffer() throws {
    XCTAssertEqual(Self.nfdGolden.count, Self.nfcGolden.count)
    for (nfd, nfc) in zip(Self.nfdGolden, Self.nfcGolden) {
      XCTAssertEqual(nfd.word, nfc.word)
      XCTAssertEqual(nfd.result, nfc.result, "hai trục phải cho CÙNG kết quả trên màn hình")
      XCTAssertNotNil(zip(nfd.steps, nfc.steps).first { $0.0.0 != $0.1.0 },
        "\"\(nfd.word)\": hai bảng phải khác nhau ở SỐ BACKSPACE, nếu không bảng vàng "
          + "này không phân biệt được trục nào cả")
    }

    // T4 viết thành số: đơn vị xoá của hai engine, đo bằng `Tools/probe`.
    let nfdNooij = try XCTUnwrap(Self.nfdGolden.first { $0.word == "Nooij" })
    let nfcNooij = try XCTUnwrap(Self.nfcGolden.first { $0.word == "Nooij" })
    XCTAssertEqual(nfcNooij.steps.last?.0, 2,
      "ô AppKit xoá GRAPHEME ⇒ 1 phím ăn trọn cụm ⇒ đếm grapheme = 2")
    XCTAssertEqual(nfdNooij.steps.last?.0, 3,
      "ô Blink xoá SCALAR ⇒ mỗi phím bóc 1 scalar ⇒ đếm scalar = 3")
  }
}
