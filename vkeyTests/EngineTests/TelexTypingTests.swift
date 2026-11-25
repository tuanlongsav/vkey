import XCTest
import Defaults
@testable import vkey

final class TelexTypingTests: SpellResetTestCase {
  /// Test paragraph-level transformation with corrected Telex input
  func testExample() throws {
    // Test a simpler sentence with correct Telex sequences
    let sentence = transform_text_telex(for: "xin chaof taats car cacs banj")
    XCTAssertEqual(sentence, "xin chào tất cả các bạn")

    // Test individual common Vietnamese words
    XCTAssertEqual(transform_text_telex(for: "ddieemr"), "điểm")
    XCTAssertEqual(transform_text_telex(for: "phieen"), "phiên")
    XCTAssertEqual(transform_text_telex(for: "ddaauf"), "đầu")
    XCTAssertEqual(transform_text_telex(for: "tieenf"), "tiền")
    XCTAssertEqual(transform_text_telex(for: "ddor"), "đỏ")
    XCTAssertEqual(transform_text_telex(for: "truowcs"), "trước")
    XCTAssertEqual(transform_text_telex(for: "chuwsng"), "chứng")
    XCTAssertEqual(transform_text_telex(for: "khoans"), "khoán")
  }

  /// Regression — Telegram gõ "điều" ra "đều" (mất chữ "i").
  /// Engine LUÔN sinh đúng chuỗi NFC cho cụm nguyên âm mở + dấu muộn (iêu/iểu…);
  /// lỗi thật nằm ở tầng emit (Telegram bị định tuyến nhầm sang NFD scalar diff
  /// nên backspace thừa 1). Test khoá cả hai nửa: (1) engine đúng, (2) Telegram
  /// native nằm trong whitelist NFC grapheme-delete.
  func testDieuTelegramFix() throws {
    // (1) Engine: cụm "iêu"/"iểu" mang dấu — trước đây chưa có test bao phủ.
    XCTAssertEqual(transform_text_telex(for: "ddieeuf"), "điều")
    XCTAssertEqual(transform_text_telex(for: "nhieeuf"), "nhiều")
    XCTAssertEqual(transform_text_telex(for: "chieeuf"), "chiều")
    XCTAssertEqual(transform_text_telex(for: "kieeur"), "kiểu")
    XCTAssertEqual(transform_text_telex(for: "hieeur"), "hiểu")
    // "điểm" (có coda) không thuộc lớp lỗi này — vẫn đúng.
    XCTAssertEqual(transform_text_telex(for: "ddieemr"), "điểm")

    // (2) App-compat: app native NFC grapheme-delete → whitelist (bypass
    // field-kind mong manh). Telegram + ChatGPT cùng lớp Gemini.
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "ru.keepcoder.Telegram"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.openai.chat"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.htl.plume"))
    // KHÔNG whitelist: Qt tdesktop (delete-unit chưa xác minh), Electron/Chromium
    // (Zalo, Cursor, Slack) vốn NFD scalar-delete đúng sẵn — bảo đảm cô lập.
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "org.telegram.desktop"))
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.vng.zalo"))
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.tinyspeck.slackmacgap"))
  }

  /// Regression — Plume (WKWebView Messenger bubble) mất phụ âm khi đặt dấu
  /// trên nguyên âm đã có mũ/móc. Ba lớp:
  /// 1) Trục: NFD snap đếm +1 backspace so với NFC (chư→chứ, đê→để, vê→về, …).
  /// 2) Transport: `.batch` (delay 0) để Lexical gộp BS → "để"→"ể" / "fix"→"fx".
  /// 3) Attribution (v4.28): panel `.nonactivatingPanel` làm cache AX đọng ở
  ///    app nền và ghi đè activeApp → mất (1)+(2) dù whitelist đúng. Whitelist
  ///    NFC + stepByStep + cushion + chụp AX trước khi chọn activeApp.

  // MARK: - ===========================================
  // MARK: - COMPREHENSIVE TELEX TYPING TESTS
  // MARK: - ===========================================

  // MARK: - Telex: Basic Tone Marks (s, f, r, x, j)

  /// Test all 5 tone marks with single vowel 'a'
  func testTelexToneMarksOnA() throws {
    XCTAssertEqual(transform_text_telex(for: "as"), "á")   // sắc
    XCTAssertEqual(transform_text_telex(for: "af"), "à")   // huyền
    XCTAssertEqual(transform_text_telex(for: "ar"), "ả")   // hỏi
    XCTAssertEqual(transform_text_telex(for: "ax"), "ã")   // ngã
    XCTAssertEqual(transform_text_telex(for: "aj"), "ạ")   // nặng
  }

  /// Test tone marks with common words
  func testTelexToneMarksInWords() throws {
    XCTAssertEqual(transform_text_telex(for: "mas"), "má")
    XCTAssertEqual(transform_text_telex(for: "maf"), "mà")
    XCTAssertEqual(transform_text_telex(for: "mar"), "mả")
    XCTAssertEqual(transform_text_telex(for: "max"), "mã")
    XCTAssertEqual(transform_text_telex(for: "maj"), "mạ")
  }

  // MARK: - Telex: Diacritical Marks (aa, ee, oo, aw, ow, uw, w)

  /// Test circumflex (mũ) marks: aa→â, ee→ê, oo→ô
  func testTelexCircumflex() throws {
    XCTAssertEqual(transform_text_telex(for: "caan"), "cân")
    XCTAssertEqual(transform_text_telex(for: "been"), "bên")
    XCTAssertEqual(transform_text_telex(for: "tooi"), "tôi")
  }

  /// Test breve (trăng) mark: aw→ă
  func testTelexBreve() throws {
    XCTAssertEqual(transform_text_telex(for: "awn"), "ăn")
    XCTAssertEqual(transform_text_telex(for: "tawm"), "tăm")   // no tone
    XCTAssertEqual(transform_text_telex(for: "tawms"), "tắm")  // with sắc tone
  }

  /// Test horn (móc) marks: ow→ơ, uw→ư
  func testTelexHorn() throws {
    XCTAssertEqual(transform_text_telex(for: "owi"), "ơi")
    XCTAssertEqual(transform_text_telex(for: "uwa"), "ưa")
    XCTAssertEqual(transform_text_telex(for: "muw"), "mư")
    XCTAssertEqual(transform_text_telex(for: "mow"), "mơ")
  }

  /// Test 'w' key alone (context-dependent)
  func testTelexWKey() throws {
    XCTAssertEqual(transform_text_telex(for: "tuowi"), "tươi")
    XCTAssertEqual(transform_text_telex(for: "nguowif"), "người")
  }

  // MARK: - Telex: Đ Character (dd)

  /// Test dd→đ
  func testTelexStrokedD() throws {
    XCTAssertEqual(transform_text_telex(for: "ddi"), "đi")
    XCTAssertEqual(transform_text_telex(for: "dduowcj"), "được")
    XCTAssertEqual(transform_text_telex(for: "ddangs"), "đáng")
  }

  /// Test that dd only toggles đ immediately after an initial d.
  func testTelexStrokedDOnlyAtInitialDD() throws {
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường")
    XCTAssertEqual(transform_text_telex(for: "dad"), "đa")
    XCTAssertEqual(transform_text_telex(for: "ded"), "đe")
  }

  // MARK: - Telex: Combined Diacritics and Tones

  /// Test combinations of circumflex + tone
  func testTelexCircumflexWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "caanf"), "cần")
    XCTAssertEqual(transform_text_telex(for: "taats"), "tất")
    XCTAssertEqual(transform_text_telex(for: "beenr"), "bển")
    XCTAssertEqual(transform_text_telex(for: "tooix"), "tỗi")
    XCTAssertEqual(transform_text_telex(for: "tooij"), "tội")
  }

  /// Test combinations of horn + tone
  func testTelexHornWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "mowx"), "mỡ")
    XCTAssertEqual(transform_text_telex(for: "muws"), "mứ")
    XCTAssertEqual(transform_text_telex(for: "tuowis"), "tưới")
  }

  /// Test combinations of breve + tone
  func testTelexBreveWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "awns"), "ắn")
    XCTAssertEqual(transform_text_telex(for: "tawmf"), "tằm")
    XCTAssertEqual(transform_text_telex(for: "bawngj"), "bặng")
  }

  // MARK: - Telex: Special Consonant Clusters

  /// Test "gi" special case - gi alone vs gi+vowel
  func testTelexGiCases() throws {
    // gi alone: tone goes on 'i'
    XCTAssertEqual(transform_text_telex(for: "gis"), "gí")
    XCTAssertEqual(transform_text_telex(for: "gif"), "gì")

    // gi + vowel: gi is consonant, tone on following vowel
    XCTAssertEqual(transform_text_telex(for: "gias"), "giá")
    XCTAssertEqual(transform_text_telex(for: "giaof"), "giào")
  }

  /// Test "qu" consonant cluster
  func testTelexQuCases() throws {
    XCTAssertEqual(transform_text_telex(for: "qua"), "qua")
    XCTAssertEqual(transform_text_telex(for: "quas"), "quá")
    XCTAssertEqual(transform_text_telex(for: "quaans"), "quấn")
    XCTAssertEqual(transform_text_telex(for: "quaans"), "quấn")
  }

  /// Test "ngh" consonant cluster
  func testTelexNghCases() throws {
    XCTAssertEqual(transform_text_telex(for: "nghif"), "nghì")
    XCTAssertEqual(transform_text_telex(for: "ngheef"), "nghề")
    XCTAssertEqual(transform_text_telex(for: "nghieengj"), "nghiệng")
  }

  /// Test other consonant clusters: ch, kh, ng, nh, ph, th, tr
  func testTelexConsonantClusters() throws {
    XCTAssertEqual(transform_text_telex(for: "chas"), "chá")
    XCTAssertEqual(transform_text_telex(for: "khoong"), "không")  // oo=ô, ngang tone
    XCTAssertEqual(transform_text_telex(for: "ngans"), "ngán")
    XCTAssertEqual(transform_text_telex(for: "nhanf"), "nhàn")
    XCTAssertEqual(transform_text_telex(for: "phos"), "phó")
    XCTAssertEqual(transform_text_telex(for: "thaays"), "thấy")
    XCTAssertEqual(transform_text_telex(for: "trongs"), "tróng")
  }

  // MARK: - Telex: Common Vietnamese Words

  /// Test frequently used Vietnamese words
  func testTelexCommonWords() throws {
    XCTAssertEqual(transform_text_telex(for: "xin"), "xin")
    XCTAssertEqual(transform_text_telex(for: "chaof"), "chào")
    XCTAssertEqual(transform_text_telex(for: "camr"), "cảm")
    XCTAssertEqual(transform_text_telex(for: "own"), "ơn")
    XCTAssertEqual(transform_text_telex(for: "vieejt"), "việt")
    XCTAssertEqual(transform_text_telex(for: "nam"), "nam")
    XCTAssertEqual(transform_text_telex(for: "hanhj"), "hạnh")
    XCTAssertEqual(transform_text_telex(for: "phucs"), "phúc")
  }

  /// Test more complex words
  func testTelexComplexWords() throws {
    XCTAssertEqual(transform_text_telex(for: "nguoiwf"), "người")
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường")
    XCTAssertEqual(transform_text_telex(for: "chuowng"), "chương")
    XCTAssertEqual(transform_text_telex(for: "trinhf"), "trình")
    XCTAssertEqual(transform_text_telex(for: "ruoujw"), "rượu")
    XCTAssertEqual(transform_text_telex(for: "huouw"), "hươu")
    XCTAssertEqual(transform_text_telex(for: "khuyur"), "khuỷu")
    XCTAssertEqual(transform_text_telex(for: "khuya"), "khuya")
  }

  func testTelexTheemTransformation() throws {
    XCTAssertEqual(transform_text_telex(for: "theem"), "thêm")
    XCTAssertEqual(transform_text_telex(for: "them"), "them")
  }

  /// 1.9.7: anywhere `dd` ↔ `đ` toggle trong recovery state.
  /// State machine:
  /// - Stage 0 → 1: 2nd 'd' liên tiếp → toggle ON ('d' → 'đ').
  /// - Stage 1 → 2: 3rd 'd' → toggle OFF ('đ' → 'dd').
  /// - Stage 2: subsequent 'd' = no-op (frozen, giữ nguyên "dd").
  /// Reset stage trên non-'d' char hoặc newWord.
  func testTelexAnywhereDDToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "vcdd"), "vcđ")
    XCTAssertEqual(transform_text_telex(for: "vcddd"), "vcdd")    // toggle off
    XCTAssertEqual(transform_text_telex(for: "vcdddd"), "vcdd")   // frozen
    XCTAssertEqual(transform_text_telex(for: "vcddddd"), "vcdd")  // frozen
    // "add" trigger anywhere-dd vì 'd' sau 'a' rơi conLai (recovery).
    XCTAssertEqual(transform_text_telex(for: "add"), "ađ")
    XCTAssertEqual(transform_text_telex(for: "addd"), "add")
    XCTAssertEqual(transform_text_telex(for: "adddd"), "add")  // frozen
  }

  /// 1.9.7: regression — initial 'dd' (Telex chuẩn `dd → đ` ở đầu từ) phải
  /// vẫn work bình thường, không bị anywhere-toggle override.
  func testTelexInitialDDStillWorks() throws {
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường")
    XCTAssertEqual(transform_text_telex(for: "ddi"), "đi")
  }

  /// v2.3.8 — NFD scalar-aware diff cho autocomplete apps (Chrome).
  /// Bug: "google" trong Chrome ra "gooogle" do Chrome store "ô" decomposed
  /// (o + ̂) — Shift+Left grapheme count thiếu so với scalar storage.
  /// Fix: `calcKeyStrokesNFD` compute diff trong NFD scalar space.
  func testCalcKeyStrokesNFDForCombiningDiacritic() throws {
    // Test 1: "gôg" → "googl" (case chính của bug "google → gooogle")
    // NFC: from=3 chars, to=5 chars, common prefix=1 (chỉ 'g').
    //   backspace=2, diff="oogl" (4 chars).
    // NFD: from=4 scalars (g,o,◌̂,g), to=5 scalars (g,o,o,g,l), common=2 (g,o).
    //   backspace=2, diff="ogl" (3 scalars).
    let (nfcBs, nfcDiff) = EventSimulator.calcKeyStrokes(from: "gôg", to: "googl")
    XCTAssertEqual(nfcBs, 2)
    XCTAssertEqual(String(nfcDiff), "oogl")

    let (nfdBs, nfdDiff) = EventSimulator.calcKeyStrokesNFD(from: "gôg", to: "googl")
    XCTAssertEqual(nfdBs, 2, "NFD backspace count khớp với Chrome scalar storage")
    XCTAssertEqual(String(nfdDiff), "ogl", "NFD diff không chứa 'o' thừa")

    // Test 2: "go" → "gô" (step thêm dấu mũ).
    // v2.3.8–v3.5: append combining mark TRẦN (0 bs + ◌̂) — đúng với field NFD
    // thật nhưng PHÁ CHỮ nếu field hoá ra là NFC ("nhập" → "nḥ̂p" ở save panel
    // của Chrome). v3.6: snap về đầu cụm — xoá "o" + retype "ô" hoàn chỉnh,
    // đúng ở CẢ field NFD lẫn NFC.
    let (gôBs, gôDiff) = EventSimulator.calcKeyStrokesNFD(from: "go", to: "gô")
    XCTAssertEqual(gôBs, 1, "xoá 'o' rồi retype nguyên cụm — không gửi dấu trần")
    XCTAssertEqual(gôDiff, ["ô"], "retype cụm grapheme hoàn chỉnh")

    // Test 3: ASCII-only — NFD bằng NFC khi không có combining marks.
    let (a1, d1) = EventSimulator.calcKeyStrokes(from: "hello", to: "hello world")
    let (a2, d2) = EventSimulator.calcKeyStrokesNFD(from: "hello", to: "hello world")
    XCTAssertEqual(a1, a2)
    XCTAssertEqual(String(d1), String(d2))

    // Test 4: Common prefix với "ô" — NFD vs NFC khác nhau.
    // "gô" → "go": NFC common=1, NFD common=2.
    let (nfcBs2, _) = EventSimulator.calcKeyStrokes(from: "gô", to: "go")
    let (nfdBs2, _) = EventSimulator.calcKeyStrokesNFD(from: "gô", to: "go")
    XCTAssertEqual(nfcBs2, 1, "NFC: backspace 1 grapheme 'ô'")
    XCTAssertEqual(nfdBs2, 1, "NFD: backspace 1 scalar (combining ̂)")
  }

  /// v2.3.21 — Telex mu cancellation pattern detect.
  /// User gõ 3 nguyên âm liên tiếp để cancel Telex mu → engine produces 2-vowel
  /// English-like word. Pattern detection cho phép keep transformed mà không
  /// cần word trong English lexicon (catches "foooter→footer", etc.).
  func testTelexCancellationPatternDetect() throws {
    // Match cases
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "gooogle", transformed: "google"))
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "foooter", transformed: "footer"))
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "nooose", transformed: "noose"))
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "aaab", transformed: "aab"))
    // Case-insensitive
    XCTAssertTrue(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "GOOOGLE", transformed: "GOOGLE"))

    // Non-match cases
    XCTAssertFalse(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "google", transformed: "google"))  // No triple
    XCTAssertFalse(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "gooogle", transformed: "googlo"))  // Triple but not the collapse
    XCTAssertFalse(SpellDecisionEngine.isLikelyTelexCancellation(
      rawInput: "abc", transformed: "abc"))
  }

  /// Gõ lặp phím để HUỶ mũ/móc/đ ("phôt" + o → "photo") thì màn hình đã
  /// là chữ Latin trơn, đúng chữ người gõ muốn. Space KHÔNG được "khôi phục
  /// tiếng Anh" về chuỗi phím thô — chuỗi đó còn chứa chính phím huỷ, nên
  /// "photonicat" thành "photoonicat". Quét 237k từ /usr/share/dict/words: 8.576
  /// từ dính (huỷ bằng aa 2.441, oo 2.149, ee 1.639, ww 1.535, dd 812), gần hết
  /// là tên riêng/thuật ngữ ngoài từ điển EN — từ trong từ điển thì đã được nhánh
  /// "transformed là từ EN" giữ lại. Huỷ dấu thanh (ss/ff/…) không dính vì luật
  /// doubledTones đã keepRaw từ trước.
  func testCommitKeepsPlainDisplayAfterTelexCancel() throws {
    let oldZWJF = Defaults[.allowedZWJF]
    defer { Defaults[.allowedZWJF] = oldZWJF }
    Defaults[.allowedZWJF] = true

    let cases: [(keys: String, shown: String)] = [
      ("photoonicat", "photonicat"),  // oo huỷ ô của mũ gõ trễ (phot+o)
      ("momoo", "momo"),
      ("acaacia", "acacia"),          // aa huỷ â
      ("deteector", "detector"),      // ee huỷ ê
      ("cowwl", "cowl"),              // ww huỷ móc
      ("cadddy", "caddy"),            // ddd huỷ đ
      ("Photoonicat", "Photonicat"),  // viết hoa đầu câu
    ]
    for c in cases {
      let ip = InputProcessor(method: .Telex)
      ip.newWord()
      for ch in c.keys { ip.push(char: ch) }
      XCTAssertEqual(ip.transformed, c.shown, "màn hình trước Space khi gõ \(c.keys)")
      let decision = SpellDecisionEngine.shared.evaluate(
        rawInput: c.keys, transformed: ip.transformed,
        needsRecovery: ip.wordBuffer.wordState.needsRecovery || ip.wordBuffer.stopProcessing)
      XCTAssertEqual(decision, .keepRaw, "\(c.keys): Space phải giữ \"\(c.shown)\"")
    }

    // Màn hình CÒN dấu Việt thì vẫn khôi phục như cũ ("text" → "tẽt").
    XCTAssertEqual(
      SpellDecisionEngine.shared.evaluate(rawInput: "text", transformed: "tẽt", needsRecovery: true),
      .restoreRawEnglish("text"))

    // Phần chênh giữa phím thô và màn hình phải TOÀN là phím dấu Telex — chênh
    // bằng chữ khác thì không phải dấu vết của phím huỷ.
    XCTAssertTrue(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "photoonicat", transformed: "photonicat"))
    XCTAssertTrue(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "gooogle", transformed: "google"))
    XCTAssertFalse(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "photonicat", transformed: "photonicat"))  // không chênh
    XCTAssertFalse(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "photonnicat", transformed: "photonicat")) // chênh 'n'
    XCTAssertFalse(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "text", transformed: "tẽt"))               // màn hình có dấu
    XCTAssertFalse(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "a11", transformed: "a1"))                 // VNI: không phải chữ
    // Phím thanh bị nuốt khi gõ THẲNG một từ tiếng Anh — không phải phím huỷ,
    // Space vẫn phải khôi phục ("Jesus" → màn hình "Jeu").
    XCTAssertFalse(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "Jesus", transformed: "Jeu"))
    XCTAssertFalse(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "asks", transformed: "ak"))
    // Phím lặp chữ không đứng liền phím giống nó thì không phải phím huỷ.
    XCTAssertFalse(SpellDecisionEngine.isTelexCancelResidue(
      rawInput: "banana", transformed: "bnana"))
  }

  /// v2.3.7 — Universal anywhere-DD: hoạt động ngay cả khi Free Mark Mode bật.
  /// Free Mark Mode bypass `needsRecovery` → `stopProcessing` không được set →
  /// existing anywhere-DD (gated bởi stopProcessing) không fire. Universal rule
  /// mới đặt ở pre-check fire bất kể state.
  func testTelexAnywhereDDWithFreeMarkMode() throws {
    let oldFreeMark = Defaults[.freeMarkModeEnabled]
    Defaults[.freeMarkModeEnabled] = true
    defer { Defaults[.freeMarkModeEnabled] = oldFreeMark }

    // Anywhere-DD vẫn phải hoạt động:
    XCTAssertEqual(transform_text_telex(for: "vcdd"), "vcđ", "vcdd phải ra vcđ kể cả Free Mark")
    XCTAssertEqual(transform_text_telex(for: "QDD"), "QĐ", "QDD phải ra QĐ kể cả Free Mark")
    XCTAssertEqual(transform_text_telex(for: "BCTDD"), "BCTĐ", "BCTDD phải ra BCTĐ kể cả Free Mark")

    // Initial dd vẫn ok (Telex chuẩn):
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường", "Initial dd vẫn → đ kể cả Free Mark")
  }

  /// v2.3.7 — All-caps abbreviations với DD trailing → Đ.
  /// User report: gõ `QDD` muốn ra `QĐ` (Quyết Định), `BCTDD` muốn ra `BCTĐ`,…
  /// Đây là anywhere-DD toggle nhưng cho all-uppercase abbreviation.
  func testTelexAllCapsAbbreviationDD() throws {
    // Print actual output để debug — verify chính xác behavior.
    let qdd = transform_text_telex(for: "QDD")
    let bctdd = transform_text_telex(for: "BCTDD")
    let ndd = transform_text_telex(for: "NDD")
    let qddMixed = transform_text_telex(for: "Qdd")
    print("DEBUG QDD: '\(qdd)' (expect 'QĐ')")
    print("DEBUG BCTDD: '\(bctdd)' (expect 'BCTĐ')")
    print("DEBUG NDD: '\(ndd)' (expect 'NĐ')")
    print("DEBUG Qdd: '\(qddMixed)' (expect 'Qđ')")

    // QDD → QĐ (Quyết Định)
    XCTAssertEqual(qdd, "QĐ", "QDD phải ra QĐ")
    // BCTDD → BCTĐ
    XCTAssertEqual(bctdd, "BCTĐ", "BCTDD phải ra BCTĐ")
    // NĐDD — type "NDD" thì "NĐ" (mid-stream all-caps)
    XCTAssertEqual(ndd, "NĐ", "NDD phải ra NĐ")
    // Mixed-case không bị uppercase hóa: Qdd → Qđ
    XCTAssertEqual(qddMixed, "Qđ", "Qdd (mixed) → Qđ giữ case")
  }

  /// 1.8.4: Telex regression — gõ "teen" (t + ee→ê + n) phải ra "tên" VN,
  /// không lock raw "teen". Bug v1.7.9: post-replay check dùng full enLexicon
  /// 9826 từ — "teen" match → override sang raw. Fix: dùng isInstantRestoreEnglish
  /// (narrow 126 + userAllow). Verify VN typing chính xác cho các stem ngắn.
  func testTelexPostReplayKeepsVN() throws {
    XCTAssertEqual(transform_text_telex(for: "teen"), "tên")
    // Regression check: tees vẫn ra tế (tee là embedded English nhưng tees
    // không phải English word → replay → keep VN).
    XCTAssertEqual(transform_text_telex(for: "tees"), "tế")
    // theem → thêm (the là English nhưng theem không) — đã có ở testV146BugFixes.
    XCTAssertEqual(transform_text_telex(for: "theem"), "thêm")
  }

  /// 1.8.3: các từ tiếng Anh có "oo" mà engine tự recovery (raw output)
  /// nhờ vowel+final cluster không hợp lệ VN. Đảm bảo những từ này KHÔNG
  /// bị nhầm sang VN khi gõ. Một số từ khác như "room"/"door"/"foot" mà
  /// "ôm"/"ổ"/"ôt" đều là VN valid → engine transform sang VN, fix bằng
  /// select-and-replace strategy ở commit-time (xem applySpellDecisionOnCommit).
  func testTelexEnglishOORecovery() throws {
    XCTAssertEqual(transform_text_telex(for: "footer"), "footer")
    XCTAssertEqual(transform_text_telex(for: "book"), "book")
    XCTAssertEqual(transform_text_telex(for: "books"), "books")
    XCTAssertEqual(transform_text_telex(for: "look"), "look")
    XCTAssertEqual(transform_text_telex(for: "wood"), "wood")
    XCTAssertEqual(transform_text_telex(for: "food"), "food")
  }

  // MARK: - 2.0.2 (J2): Regression cho bug class "toools"
  //
  // Trước 2.0.2 có bug: gõ "text tools" + Space → ra "toools" (thừa 1 'o')
  // do logic `transformed.count == lastTransformedForStep.count` trong
  // InputProcessor.swift (3 sites) append raw 'o' khi engine vừa apply
  // combining diacritic (cùng grapheme count nhưng NFD scalar count tăng).
  // Fix: dùng `WordBuffer.shouldAppendRawKey(...)` so sánh NFD scalars.

  /// v2.2.0: bug "theme" → "themee" (thừa ký tự). Bản chất bug là engine LEAK
  /// raw key khi `isInstantRestoreEnglish` hit ở mid-word → output dài hơn input.
  /// Test này canh giữ điều đó: output KHÔNG được dài hơn input.
  /// (v2.9: "theme" đã được bỏ khỏi instant-restore → Telex ra "thêm" — vẫn
  /// thoả ≤ input.count. "scheme/scene/phone/type" vẫn giữ raw English.)
  func testTelex_2_2_0_theme_no_extra_char() throws {
    XCTAssertEqual(transform_text_telex(for: "theme"), "thêm")  // v2.9: từ VN
    XCTAssertEqual(transform_text_telex(for: "scheme"), "scheme")
    for input in ["theme", "scheme", "scene", "phone", "type"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(
        output.count, input.count,
        "Bug v2.2.0 theme-class: '\(input)' → '\(output)' (thừa ký tự!)"
      )
    }
  }

  /// Test bug "tools" — verify NO EXTRA char appended.
  /// Trước fix: "tools" (5 chars) → "toools" (6 chars, thừa 'o').
  /// Sau fix: output có ≤5 graphemes (có thể là "tools" raw English, hoặc
  /// "tols", hoặc VN transform — quan trọng là KHÔNG dài hơn input).
  /// "tools" cụ thể nằm trong English lexicon → ra "tools".
  func testTelex_J2_oo_class_no_extra_char() throws {
    // Cases có trong English lexicon → restore raw English:
    XCTAssertEqual(transform_text_telex(for: "tools"), "tools")
    // Cases khác — verify count: input.count chars in, output count ≤ input
    // (không thừa ký tự do bug oo). Output có thể là VN transform.
    for input in ["boot", "boost", "bloom", "shoot", "loop", "stoop", "goose"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(
        output.count, input.count,
        "Bug J2 regression: '\(input)' → '\(output)' (thừa ký tự!). Output should be ≤ \(input.count) graphemes."
      )
    }
  }

  /// Test bug class "aa" trigger: KHÔNG thừa ký tự.
  func testTelex_J2_aa_class_no_extra_char() throws {
    for input in ["baa", "naan", "saari"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(output.count, input.count, "Bug J2 aa: '\(input)' → '\(output)'")
    }
  }

  /// Test bug class "ee" trigger: KHÔNG thừa ký tự.
  func testTelex_J2_ee_class_no_extra_char() throws {
    // "see", "fee", "bee" có thể có trong lexicon — verify count không tăng.
    for input in ["bee", "see", "fee", "wee"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(output.count, input.count, "Bug J2 ee: '\(input)' → '\(output)'")
    }
  }

  /// Test path replay (J2 site 2): từ tiếng Anh có 'oo' qua replay path.
  func testTelex_J2_replay_path_no_extra_char() throws {
    XCTAssertEqual(transform_text_telex(for: "footer"), "footer")
    for input in ["tooth", "smooth", "bloom"] {
      let output = transform_text_telex(for: input)
      XCTAssertLessThanOrEqual(output.count, input.count, "Bug J2 replay: '\(input)' → '\(output)'")
    }
  }

  /// Test VNI bug class — toggle digit cancel VẪN cho ký tự thô '1','6','8','9'.
  /// Đây là path tốt cho `shouldAppendRawKey` cần TRẢ TRUE (NFD giảm).
  func testVNI_J2_digit_toggle_preserved() throws {
    XCTAssertEqual(transform_text_vni(for: "a11"), "a1")  // tone sac cancel
    XCTAssertEqual(transform_text_vni(for: "a66"), "a6")  // circumflex cancel
    XCTAssertEqual(transform_text_vni(for: "a88"), "a8")  // breve cancel
    XCTAssertEqual(transform_text_vni(for: "d99"), "d9")  // d stroked cancel
  }

  /// Test Telex triple-toggle vẫn đúng (không bị over-fix).
  func testTelex_J2_triple_toggle_preserved() throws {
    XCTAssertEqual(transform_text_telex(for: "aaa"), "aa")  // â cancel
    XCTAssertEqual(transform_text_telex(for: "ooo"), "oo")  // ô cancel
    XCTAssertEqual(transform_text_telex(for: "eee"), "ee")  // ê cancel
    XCTAssertEqual(transform_text_telex(for: "aww"), "aw")  // ơ→aw cancel
    XCTAssertEqual(transform_text_telex(for: "uww"), "uw")  // ư→uw cancel
  }

  /// Test Vietnamese đúng cách (không break engine Telex chuẩn).
  func testTelex_J2_vietnamese_typing_preserved() throws {
    XCTAssertEqual(transform_text_telex(for: "tieengs"), "tiếng")
    XCTAssertEqual(transform_text_telex(for: "ddoongf"), "đồng")
    XCTAssertEqual(transform_text_telex(for: "khoer"), "khoẻ")
    XCTAssertEqual(transform_text_telex(for: "vieejt"), "việt")
  }

  /// Test v1.4.6 bug fixes: English word restoration replay, uo horn handling, and common words
  func testV146BugFixes() throws {
    // English word restoration replay fixes
    XCTAssertEqual(transform_text_telex(for: "tees"), "tế")       // "tee" is English, but tees → tế
    XCTAssertEqual(transform_text_telex(for: "heest"), "hết")     // "he" is English, but heest → hết
    XCTAssertEqual(transform_text_telex(for: "theem"), "thêm")    // "the" is English, but theem → thêm

    // Horn mark (muMoc) on uo pattern - always apply to both vowels
    XCTAssertEqual(transform_text_telex(for: "dduwowcj"), "được") // uo horn should persist through second w
    XCTAssertEqual(transform_text_telex(for: "dduowcj"), "được")  // Standard form without extra w

    // Basic Telex transformations (regression)
    XCTAssertEqual(transform_text_telex(for: "soats"), "soát")
    XCTAssertEqual(transform_text_telex(for: "gox"), "gõ")
    XCTAssertEqual(transform_text_telex(for: "tooi"), "tôi")
    XCTAssertEqual(transform_text_telex(for: "Goiwj"), "Gợi")
    XCTAssertEqual(transform_text_telex(for: "vieetj"), "việt")
    XCTAssertEqual(transform_text_telex(for: "chinhs"), "chính")
    XCTAssertEqual(transform_text_telex(for: "nhuwng"), "nhưng")
    XCTAssertEqual(transform_text_telex(for: "ddang"), "đang")
    XCTAssertEqual(transform_text_telex(for: "looix"), "lỗi")
    XCTAssertEqual(transform_text_telex(for: "looij"), "lội")
    XCTAssertEqual(transform_text_telex(for: "cuax"), "cũa")
    XCTAssertEqual(transform_text_telex(for: "cuar"), "của")
  }

  // MARK: - Telex: Toggle Behavior (Double Typing)

  /// Test tone toggle (typing same tone twice removes it)
  /// 1.7.5: tone-cancel ưu tiên hơn English doubled-tone preservation —
  /// gõ "ar" + "r" = cancel hỏi tone (a + r tạo dấu hỏi rồi r thứ 2 xoá),
  /// kết quả "ar" (raw a + raw r append). Trade-off: từ tiếng Anh hiếm
  /// như "ass"/"arr"/"aff" không còn được preserve khi gõ tuần tự.
  func testTelexToneToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "ass"), "as")
    XCTAssertEqual(transform_text_telex(for: "aff"), "af")
    XCTAssertEqual(transform_text_telex(for: "arr"), "ar")
    XCTAssertEqual(transform_text_telex(for: "axx"), "ax")
    XCTAssertEqual(transform_text_telex(for: "ajj"), "aj")
  }

  /// Test diacritical mark toggle
  func testTelexDiacriticToggle() throws {
    // Triple 'a' should result in 'aa' (â toggle off + a)
    XCTAssertEqual(transform_text_telex(for: "aaa"), "aa")
    XCTAssertEqual(transform_text_telex(for: "ooo"), "oo")
    XCTAssertEqual(transform_text_telex(for: "eee"), "ee")
  }

  /// Test 'w' toggle
  func testTelexWToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "aww"), "aw")
    XCTAssertEqual(transform_text_telex(for: "oww"), "ow")
    XCTAssertEqual(transform_text_telex(for: "uww"), "uw")
  }

  /// Test 'dd' toggle (triple d)
  func testTelexDToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "ddd"), "dd")
  }

  // MARK: - Telex: Recovery Cases (Invalid Vietnamese)

  /// Test invalid vowel combinations trigger recovery
  func testTelexInvalidVowelRecovery() throws {
    XCTAssertEqual(transform_text_telex(for: "aes"), "aes")
    XCTAssertEqual(transform_text_telex(for: "eas"), "eas")
    XCTAssertEqual(transform_text_telex(for: "yis"), "yis")
  }

  /// Test invalid final consonant triggers recovery
  func testTelexInvalidFinalConsonantRecovery() throws {
    // "ai" cannot have final consonants
    XCTAssertEqual(transform_text_telex(for: "aims"), "aims")
    XCTAssertEqual(transform_text_telex(for: "aotn"), "aotn")
  }

  /// Test foreign/loanwords that bypass Vietnamese rules
  func testTelexForeignWords() throws {
    // Words starting with non-Vietnamese patterns
    XCTAssertEqual(transform_text_telex(for: "macro"), "macro")
    XCTAssertEqual(transform_text_telex(for: "wifi"), "wifi")
  }

  func testAllowedZWJF() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldAllowedZWJF = Defaults[.allowedZWJF]
    Defaults[.spellCheckEnabled] = false
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.allowedZWJF] = oldAllowedZWJF
    }
    
    // Simulate allowedZWJF = false
    Defaults[.allowedZWJF] = false
    XCTAssertEqual(transform_text_telex(for: "zas"), "zas")
    XCTAssertEqual(transform_text_telex(for: "fair"), "fair")
    
    // Simulate allowedZWJF = true
    Defaults[.allowedZWJF] = true
    XCTAssertEqual(transform_text_telex(for: "zas"), "zá")
    XCTAssertEqual(transform_text_telex(for: "fair"), "fải")
  }

  // MARK: - Telex: Edge Cases

  /// Test single vowels with tone
  func testTelexSingleVowels() throws {
    XCTAssertEqual(transform_text_telex(for: "as"), "á")
    XCTAssertEqual(transform_text_telex(for: "es"), "é")
    XCTAssertEqual(transform_text_telex(for: "is"), "í")
    XCTAssertEqual(transform_text_telex(for: "os"), "ó")
    XCTAssertEqual(transform_text_telex(for: "us"), "ú")
    XCTAssertEqual(transform_text_telex(for: "ys"), "ý")
  }

  /// Test words ending with valid consonants
  func testTelexValidFinalConsonants() throws {
    XCTAssertEqual(transform_text_telex(for: "acs"), "ác")   // -c
    XCTAssertEqual(transform_text_telex(for: "achj"), "ạch") // -ch
    XCTAssertEqual(transform_text_telex(for: "ams"), "ám")   // -m
    XCTAssertEqual(transform_text_telex(for: "anf"), "àn")   // -n
    XCTAssertEqual(transform_text_telex(for: "angf"), "àng") // -ng
    XCTAssertEqual(transform_text_telex(for: "anhf"), "ành") // -nh
    XCTAssertEqual(transform_text_telex(for: "aps"), "áp")   // -p
    XCTAssertEqual(transform_text_telex(for: "ats"), "át")   // -t
  }

  /// Test uppercase handling
  func testTelexUppercase() throws {
    XCTAssertEqual(transform_text_telex(for: "VIEEJT"), "VIỆT")
    XCTAssertEqual(transform_text_telex(for: "NAM"), "NAM")
    XCTAssertEqual(transform_text_telex(for: "DDUOWNGF"), "ĐƯỜNG")
  }

  /// Regression 1.7.10: v1.7.9 bump EN dict 126 → 9826 từ làm các telex
  /// stem ngắn ("cos", "hop", "the", "tie") match English → lock raw,
  /// bỏ qua telex transform. Fix: instant-restore dùng list HẸP (embedded
  /// 126 + userAllow) thay vì full lexicon.
  func testTelexEnglishCollisionHotfix() throws {
    XCTAssertEqual(transform_text_telex(for: "cos"), "có")
    XCTAssertEqual(transform_text_telex(for: "hopwj"), "hợp")
    XCTAssertEqual(transform_text_telex(for: "tieengs"), "tiếng")
    XCTAssertEqual(transform_text_telex(for: "theer"), "thể")
    XCTAssertEqual(transform_text_telex(for: "thoongs"), "thống")
    XCTAssertEqual(transform_text_telex(for: "cof"), "cò")
    XCTAssertEqual(transform_text_telex(for: "cor"), "cỏ")
  }

  /// Regression 1.7.10: instant-restore vẫn hoạt động cho các từ trong
  /// embedded EmbeddedLexiconData.englishWords (off/class/staff).
  func testEnglishInstantRestoreEmbeddedStillWorks() throws {
    XCTAssertEqual(transform_text_telex(for: "off"), "off")
    XCTAssertEqual(transform_text_telex(for: "class"), "class")
    XCTAssertEqual(transform_text_telex(for: "staff"), "staff")
  }

  /// Regression 1.7.5: gõ "a r r m" (a + r tạo dấu hỏi + r xoá dấu + m)
  /// phải ra "arm" thay vì "arrm". Bug do English-word "arr" lock raw bypass
  /// tone-cancel. Fix: detect tone-cancel intent (state có tone + char là
  /// tone key) → skip English-word preservation, để engine.push toggle tone.
  func testTelexToneCancelArrm() throws {
    XCTAssertEqual(transform_text_telex(for: "arrm"), "arm")
    XCTAssertEqual(transform_text_telex(for: "ARRM"), "ARM")
    // Tương tự với các tone keys khác
    XCTAssertEqual(transform_text_telex(for: "assm"), "asm")  // a + s sắc + s cancel + m
    XCTAssertEqual(transform_text_telex(for: "affm"), "afm")  // huyền cancel
    XCTAssertEqual(transform_text_telex(for: "axxm"), "axm")  // ngã cancel
    XCTAssertEqual(transform_text_telex(for: "ajjm"), "ajm")  // nặng cancel
  }

  /// Regression 1.7.7: gõ "dùng" (telex: dungf) phải ra "dùng", không phải
  /// "đùng". Trước đây tryLateDToggle có thể trigger nhầm khi user gõ thêm
  /// 'd' trong/cuối từ chưa hoàn chỉnh hoặc khi state cho phép quá rộng.
  /// Pattern "dinjhd" (telex của "định") vẫn phải toggle gạch D đúng.
  func testTelexLateDToggleGated() throws {
    XCTAssertEqual(transform_text_telex(for: "dungf"), "dùng")
    XCTAssertEqual(transform_text_telex(for: "dung"), "dung")
    XCTAssertEqual(transform_text_telex(for: "dinjhd"), "định")
    XCTAssertEqual(transform_text_telex(for: "dd"), "đ")  // toggle dd vẫn đúng
    XCTAssertEqual(transform_text_telex(for: "ddungf"), "đùng")  // intentional đ
  }

  /// Test late D toggle for syllables of length 2 (Telex and VNI)
  func testLateDToggleLength2() throws {
    XCTAssertEqual(transform_text_telex(for: "did"), "đi")
    XCTAssertEqual(transform_text_vni(for: "di9"), "đi")
    
    // Non-syllable boundary should not trigger
    XCTAssertEqual(transform_text_telex(for: "d"), "d")
    XCTAssertEqual(transform_text_telex(for: "di"), "di")
  }

  /// Test backspace rollback for late-D and complex syllables
  func testBackspaceRollback() throws {
    // Telex
    let processor = InputProcessor(method: .Telex)
    
    // test "did" -> backspace -> "di"
    processor.newWord()
    processor.push(char: "d")
    processor.push(char: "i")
    processor.push(char: "d")
    XCTAssertEqual(processor.transformed, "đi")
    
    let (backspaces1, diff1) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(backspaces1, 2)
    XCTAssertEqual(String(diff1), "di")
    XCTAssertEqual(processor.transformed, "di")
    
    // test "dinjhd" -> backspace -> "dịnh"
    processor.newWord()
    processor.push(char: "d")
    processor.push(char: "i")
    processor.push(char: "n")
    processor.push(char: "h")
    processor.push(char: "j")
    XCTAssertEqual(processor.transformed, "dịnh")
    processor.push(char: "h")
    XCTAssertEqual(processor.transformed, "dinhjh") // enters recovery/stopProcessing
    processor.push(char: "d")
    XCTAssertEqual(processor.transformed, "dinhjhd") // recovery continues
    
    // Backspace once to get "dinhjh" (keys: "dinhjh")
    let (backspaces2, diff2) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(backspaces2, 0) // lets OS handle it (1-char delete)
    XCTAssertEqual(String(diff2), "")
    XCTAssertEqual(processor.transformed, "dinhjh")
    
    // Backspace again to restore "dịnh" (keys: "dinjh", from snapshot)
    let (backspaces3, diff3) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(backspaces3, 5) // deletes "inhjh" (5 chars)
    XCTAssertEqual(String(diff3), "ịnh")
    XCTAssertEqual(processor.transformed, "dịnh")
    
    // VNI
    let vniProcessor = InputProcessor(method: .VNI)
    
    // test "di9" -> backspace -> "di"
    vniProcessor.newWord()
    vniProcessor.push(char: "d")
    vniProcessor.push(char: "i")
    vniProcessor.push(char: "9")
    XCTAssertEqual(vniProcessor.transformed, "đi")
    
    let (vniB1, vniD1) = vniProcessor.pop(usesNFC: vniProcessor.usesNFCForFocusedField())
    XCTAssertEqual(vniB1, 2)
    XCTAssertEqual(String(vniD1), "di")
    XCTAssertEqual(vniProcessor.transformed, "di")
  }

  /// Regression 1.7.4: gõ ARM (initialism English) khi commit phải restore
  /// về "ARM" thay vì giữ "Ảm" (vkey vô tình áp tone hỏi cho R). Fix ở
  /// SpellDecisionEngine: detect all-caps ASCII alphabetic ≥2-≤5 chars,
  /// không có double-letter Telex signal, không kết bằng tone key → coi
  /// là English acronym → restoreRawEnglish.
  func testSpellDecisionArmAcronymRestore() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true

    // 4.12: acronym restore khi transformed là từ VN hợp lệ (ARM→Ảm, USA→Úa)
    // giờ yêu cầu raw là từ EN thật. Embedded EN chỉ 126 từ (không có
    // arm/usa) → inject package hermetic thay vì phụ thuộc lexicon-update
    // .json đã tải trên máy chạy test.
    let path = URL(fileURLWithPath: "/tmp/vkey-lexicon-acronym-test.json")
    let manager = LexiconManager(updatePackageURL: path)
    let package = """
    {
      "version": 5,
      "vietnamese": ["ảm","úa","đỏ","đo","việt"],
      "english": ["arm","usa"],
      "keep": []
    }
    """
    try manager.setUpdatePackageData(Data(package.utf8))
    manager.reload()
    defer { try? FileManager.default.removeItem(at: path) }
    let engine = SpellDecisionEngine(lexiconManager: manager)

    XCTAssertEqual(
      engine.evaluate(rawInput: "ARM", transformed: "Ảm", needsRecovery: false),
      .restoreRawEnglish("ARM")
    )
    XCTAssertEqual(
      engine.evaluate(rawInput: "USA", transformed: "Úa", needsRecovery: false),
      .restoreRawEnglish("USA")
    )
    XCTAssertEqual(
      engine.evaluate(rawInput: "API", transformed: "Apí", needsRecovery: false),
      .restoreRawEnglish("API")
    )
    // Không acronym (length > 5):
    XCTAssertNotEqual(
      engine.evaluate(rawInput: "VIEEJT", transformed: "VIỆT", needsRecovery: false),
      .restoreRawEnglish("VIEEJT")
    )
    // Không acronym (last char là tone key):
    XCTAssertNotEqual(
      engine.evaluate(rawInput: "DDOR", transformed: "Đỏ", needsRecovery: false),
      .restoreRawEnglish("DDOR")
    )
    // Không acronym (chứa double-letter Telex pattern "dd"):
    XCTAssertNotEqual(
      engine.evaluate(rawInput: "DDO", transformed: "Đo", needsRecovery: false),
      .restoreRawEnglish("DDO")
    )
  }

  /// Regression 4.12: từ tiếng Việt viết HOA (Caps Lock heading) với phím
  /// dấu GIỮA từ khớp pattern acronym → từng bị restore nhầm thành phím thô:
  /// "TOÁN" + Space → "TOASN" (tương tự BÁN/HỌC/VÀNG/PHÁP/SÁCH). Acronym
  /// giờ chỉ restore khi transformed KHÔNG phải từ VN hợp lệ hoặc raw là từ
  /// EN thật — từ VN hợp lệ với raw vô nghĩa phải giữ nguyên.
  func testSpellDecisionAllCapsVietnameseWordKept() throws {
    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true

    // Engine mặc định: VN lexicon từ syllables asset (có đủ toán/bán/học/
    // vàng/pháp/sách), raw "toasn"… không có trong bất kỳ list EN nào.
    let engine = SpellDecisionEngine.shared
    let cases: [(raw: String, transformed: String)] = [
      ("TOASN", "TOÁN"),
      ("BASN", "BÁN"),
      ("HOJC", "HỌC"),
      ("VAFNG", "VÀNG"),
      ("PHASP", "PHÁP"),
      ("SASCH", "SÁCH"),
    ]
    for c in cases {
      XCTAssertEqual(
        engine.evaluate(rawInput: c.raw, transformed: c.transformed, needsRecovery: false),
        .keepVietnamese,
        "\(c.raw) → \(c.transformed) phải giữ tiếng Việt, không restore raw"
      )
    }
  }

  /// 4.12: matchCase — auto-suggestion từ lexicon là chữ thường; thay thế
  /// phải giữ kiểu hoa/thường của từ user gõ (ALL-CAPS / hoa chữ đầu).
  func testMatchCasePreservesSourceCapitalization() throws {
    XCTAssertEqual(InputProcessor.matchCase(of: "TOASN", to: "toán"), "TOÁN")
    XCTAssertEqual(InputProcessor.matchCase(of: "Dinhj", to: "định"), "Định")
    XCTAssertEqual(InputProcessor.matchCase(of: "dinhj", to: "định"), "định")
    XCTAssertEqual(InputProcessor.matchCase(of: "ĐINHJ", to: "định"), "ĐỊNH")
    // 1 chữ cái hoa → chỉ viết hoa chữ đầu (không đủ tín hiệu ALL-CAPS).
    XCTAssertEqual(InputProcessor.matchCase(of: "A", to: "à"), "À")
    XCTAssertEqual(InputProcessor.matchCase(of: "", to: "định"), "định")
  }

  /// Test mixed case
  func testTelexMixedCase() throws {
    XCTAssertEqual(transform_text_telex(for: "Vieejt"), "Việt")
    XCTAssertEqual(transform_text_telex(for: "DDuowngf"), "Đường")
  }

  /// Bất biến 4.13 — quét TOÀN BỘ instant-restore list bằng engine thật:
  /// từ EN nào mà Telex thuần biến ra từ VN hợp lệ ≥2 ký tự VÀ vẫn thắng
  /// lúc gõ (giữ raw EN) thì PHẢI nằm trong danh sách ngoại lệ đã quyết
  /// định bên dưới. Thêm từ EN mới tạo xung đột chưa quyết → test này fail,
  /// buộc phải cân nhắc (VN thắng qua guard toneKeyCompletesVietnameseWord /
  /// gỡ khỏi list, hay EN thắng có chủ đích thì thêm vào ngoại lệ).
  func testInstantRestoreConflictsAreAllDecided() throws {
    // EN thắng CÓ CHỦ ĐÍCH: hể/thể/thế/sê chỉ bị chiếm khi gõ dấu-TRƯỚC-mũ
    // (thứ tự hiếm; kiểu chuẩn heer/theer/thees không ảnh hưởng), còn
    // here/there/these/three/see là từ EN cực phổ biến. 4.14: pass/horses
    // — phím tone lặp CANCEL dấu + keys khớp list → khoá raw đầy đủ (fix
    // "pas"/"hoe"); pure transform "pa"/"hoe" là VN nhưng chỉ gõ được qua
    // thứ tự phím vô nghĩa với người gõ VN.
    let intendedEnglishWinners: Set<String> = [
      "here", "there", "these", "three", "see", "pass", "horses",
    ]

    let engine = Telex()
    var undecided: [String] = []
    for w in EmbeddedLexiconData.englishWords.sorted() {
      var state = TiengVietState.empty
      var broke = false
      for c in w {
        let r = engine.push(char: c, state: state)
        state = r.state
        if state.needsRecovery { broke = true; break }
      }
      if broke { continue }
      let pure = state.transformed
      guard pure != w, pure.count >= 2,
            LexiconManager.shared.isVietnameseWord(pure) else { continue }
      // EN vẫn thắng lúc gõ (raw giữ nguyên) mà chưa có trong ngoại lệ?
      if transform_text_telex(for: w) == w, !intendedEnglishWinners.contains(w) {
        undecided.append("\(w) -> \(pure)")
      }
    }
    XCTAssertTrue(
      undecided.isEmpty,
      "Từ EN trong instant-restore đè từ VN hợp lệ mà chưa được quyết định: \(undecided)"
    )
  }

  /// Regression 4.14: phím tone lặp lại CANCEL dấu + toàn bộ keys khớp
  /// instant-restore EN → khoá raw ĐẦY ĐỦ. Trước đây "pass" ra "pas" (mất
  /// 1 chữ s — phím s đầu bị consume làm dấu), "horses" ra "hoe", "nurses"
  /// ra sai tương tự. Escape hatch VN ("thiss"→"this", "lisst"→"list",
  /// không khớp list) và các từ đi đường khác (off/staff/class qua instant
  /// lock/cluster) giữ nguyên.
  func testDoubledToneEnglishWordsKeptFull() throws {
    XCTAssertEqual(transform_text_telex(for: "pass"), "pass")
    XCTAssertEqual(transform_text_telex(for: "PASS"), "PASS")
    XCTAssertEqual(transform_text_telex(for: "horses"), "horses")
    XCTAssertEqual(transform_text_telex(for: "nurses"), "nurses")
    XCTAssertEqual(transform_text_telex(for: "business"), "business")
    // Không đổi hành vi cũ:
    XCTAssertEqual(transform_text_telex(for: "off"), "off")
    XCTAssertEqual(transform_text_telex(for: "staff"), "staff")
    XCTAssertEqual(transform_text_telex(for: "class"), "class")
    XCTAssertEqual(transform_text_telex(for: "thiss"), "this")
    XCTAssertEqual(transform_text_telex(for: "lisst"), "list")
    // Cancel ngắn (< 4 phím) giữ semantics cũ — double-tap xoá dấu rồi gõ
    // tiếp vẫn hoạt động (xem testTelexToneToggle/testTelexToneCancelArrm):
    XCTAssertEqual(transform_text_telex(for: "ass"), "as")
    XCTAssertEqual(transform_text_telex(for: "arrm"), "arm")
  }

  /// Regression 4.14: sau tone-cancel EN lock, backspace phải về raw prefix
  /// ("pass"→"pas"), không rollback về state Telex còn dấu ("pá").
  func testToneCancelEnglishLockBackspaceKeepsRawPrefix() throws {
    var buffer = WordBuffer()
    let engine = Telex()

    for c in "pass" { buffer.push(char: c, engine: engine) }
    XCTAssertEqual(buffer.transformed, "pass")
    XCTAssertTrue(buffer.stopProcessing)
    XCTAssertTrue(buffer.stoppedByEnglishWord)

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "pas")
    XCTAssertEqual(String(buffer.keys), "pas")
    XCTAssertTrue(buffer.stopProcessing)
    XCTAssertTrue(buffer.stoppedByEnglishWord)

    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "pa")
    XCTAssertEqual(String(buffer.keys), "pa")

    buffer = WordBuffer()
    for c in "horses" { buffer.push(char: c, engine: engine) }
    XCTAssertEqual(buffer.transformed, "horses")
    _ = buffer.pop(engine: engine, usesNFC: true)
    XCTAssertEqual(buffer.transformed, "horse")
    XCTAssertEqual(String(buffer.keys), "horse")
  }

  /// Regression 4.15: field NFD (web content Chromium/Electron — gồm ô chat
  /// claude.ai) — chuỗi diff NFD kế tiếp khi gõ một từ có dấu phải DỰNG LẠI
  /// ĐÚNG từ đó, KHÔNG rụng phụ âm đầu. Bug 4.14 ("Chrome tìm kiếm NFC") ép
  /// emit NFC vào field NFD → field lưu ít scalar hơn model → backspace dư ăn
  /// mất ký tự trước nguyên âm mang dấu ("gửi"→"ửi", "sửa"→"ửa", "mất"→"ất").
  /// Mô phỏng field bằng buffer scalar NFD, áp đúng (backspaceCount, emit) mà
  /// InputProcessor sinh ra qua calcKeyStrokesNFD + emittedCharacters.
  ///
  /// ⚠️ PHẠM VI (đọc trước khi trích dẫn test này làm bằng chứng): `replayNFDField`
  /// mô phỏng field bằng `fieldScalars.removeLast(bs)`, tức GIẢ ĐỊNH SẴN rằng một
  /// backspace xoá MỘT SCALAR. Đó chính là giả thuyết đang cần kiểm chứng (xem
  /// khối ⚠️ trong `InputProcessor.usesNFCForFocusedField`), nên test này KHÔNG
  /// chứng minh Chromium xoá theo scalar — nó chỉ chứng minh: *nếu* field xoá
  /// theo scalar thì trục diff phải là NFD. Mô hình còn lại (backspace xoá cả
  /// cụm grapheme — app native NFC như Notes/Telegram/ChatGPT) nằm ở
  /// `testNFCGraphemeFieldReplayKeepsLeadingConsonant` ngay bên dưới. Hai test
  /// là hai NỬA của cùng một bất biến "đơn vị xoá của field == trục diff", và
  /// phải luôn đi thành cặp; sửa một cái mà không sửa cái kia là dấu hiệu ai đó
  /// vừa lẫn hai mô hình với nhau.
  func testNFDFieldReplayKeepsLeadingConsonant() throws {
    let engine = Telex()
    // (keys Telex, kết quả kỳ vọng) — mỗi từ 1 phụ âm đầu + nguyên âm mang dấu.
    let cases: [(String, String)] = [
      ("guiwr", "gửi"),
      ("suawr", "sửa"),
      ("nooij", "nội"),
      ("looix", "lỗi"),
      ("maast", "mất"),
    ]

    func replayNFDField(states: [String], normalizeToNFC: Bool) -> String {
      var fieldScalars: [Unicode.Scalar] = []
      var prev = ""
      for s in states {
        let (bs, diff) = EventSimulator.calcKeyStrokesNFD(from: prev, to: s)
        fieldScalars.removeLast(min(bs, fieldScalars.count))
        let emit = EventSimulator.emittedCharacters(diff, normalizeToNFC: normalizeToNFC)
        fieldScalars.append(contentsOf: String(emit).unicodeScalars)
        prev = s
      }
      return String(String.UnicodeScalarView(fieldScalars))
        .precomposedStringWithCanonicalMapping
    }

    for (keys, expected) in cases {
      var buffer = WordBuffer()
      var states: [String] = []
      for c in keys {
        buffer.push(char: c, engine: engine)
        states.append(buffer.transformed)
      }
      XCTAssertEqual(
        states.last?.precomposedStringWithCanonicalMapping, expected,
        "Sanity: engine gõ '\(keys)' phải ra '\(expected)'")

      // Fix 4.15: field NFD nhận emit NFD → dựng đúng, giữ phụ âm đầu.
      XCTAssertEqual(
        replayNFDField(states: states, normalizeToNFC: false), expected,
        "Emit NFD vào field NFD phải dựng đúng '\(expected)'")

      // Tài liệu hoá regression 4.14: emit NFC vào field NFD → rụng phụ âm đầu.
      XCTAssertNotEqual(
        replayNFDField(states: states, normalizeToNFC: true), expected,
        "Emit NFC vào field NFD rụng chữ đầu (bug 4.14) — không được để tái diễn")
    }
  }

  /// NỬA CÒN LẠI của `testNFDFieldReplayKeepsLeadingConsonant`: mô hình field
  /// xoá theo CỤM GRAPHEME (app native lưu NFC — Notes, Telegram, ChatGPT,
  /// Gemini). Ở đây `field.removeLast(bs)` bỏ nguyên một `Character`, nên
  /// backspace đếm theo scalar (NFD) sẽ xoá LỐ: đúng bug "điều"→"đều" và
  /// "gửi"→"ửi" đã gặp trên Telegram.
  ///
  /// Hai test cạnh nhau làm cho cả hai mô hình hiện diện tường minh, và cho
  /// thấy bất biến thật không phải "NFC tốt hơn NFD" mà là: TRỤC ĐẾM BACKSPACE
  /// PHẢI TRÙNG ĐƠN VỊ XOÁ CỦA FIELD. Trục nào đúng cho app nào là câu hỏi đo
  /// đạc riêng — hai test này chỉ khoá phần số học, không khẳng định thay
  /// `usesNFCForFocusedField`.
  func testNFCGraphemeFieldReplayKeepsLeadingConsonant() throws {
    let engine = Telex()
    let cases: [(String, String)] = [
      ("guiwr", "gửi"),
      ("suawr", "sửa"),
      ("nooij", "nội"),
      ("looix", "lỗi"),
      ("maast", "mất"),
      // Ca Telegram/ChatGPT gốc: đếm scalar làm mất chữ "i" giữa từ.
      ("ddieeuf", "điều"),
    ]

    // Field lưu grapheme: 1 backspace = 1 `Character`, emit luôn precompose.
    func replayGraphemeField(states: [String], useNFDDiff: Bool) -> String {
      var field: [Character] = []
      var prev = ""
      for s in states {
        let (bs, diff) = useNFDDiff
          ? EventSimulator.calcKeyStrokesNFD(from: prev, to: s)
          : EventSimulator.calcKeyStrokes(from: prev, to: s)
        field.removeLast(min(bs, field.count))
        field.append(contentsOf: EventSimulator.emittedCharacters(diff, normalizeToNFC: true))
        prev = s
      }
      return String(field).precomposedStringWithCanonicalMapping
    }

    for (keys, expected) in cases {
      var buffer = WordBuffer()
      var states: [String] = []
      for c in keys {
        buffer.push(char: c, engine: engine)
        states.append(buffer.transformed)
      }
      XCTAssertEqual(
        states.last?.precomposedStringWithCanonicalMapping, expected,
        "Sanity: engine gõ '\(keys)' phải ra '\(expected)'")

      XCTAssertEqual(
        replayGraphemeField(states: states, useNFDDiff: false), expected,
        "Field xoá-grapheme + diff NFC phải dựng đúng '\(expected)'")

      XCTAssertNotEqual(
        replayGraphemeField(states: states, useNFDDiff: true), expected,
        "Diff NFD vào field xoá-grapheme xoá lố → mất chữ ('điều'→'đều')")
    }
  }

  /// Regression 4.13: "list" đã gỡ khỏi instant-restore ("lít" là từ VN phổ
  /// biến, kết bằng 't' nên guard phím-tone không cover). Escape hatch cho
  /// EN: "lisst" (double-s). Cặp legacy "tê"→"tee" không còn restore ở
  /// commit (gõ "tê tay" + Space từng thành "tee tay"); "ò"→"of" 1 ký tự
  /// giữ nguyên.
  func testLitNotHijackedAndLegacyTeKeptVietnamese() throws {
    XCTAssertEqual(transform_text_telex(for: "list"), "lít")
    XCTAssertEqual(transform_text_telex(for: "lits"), "lít")
    XCTAssertEqual(transform_text_telex(for: "lisst"), "list")

    XCTAssertFalse(
      LexiconManager.shared.shouldApplyLegacyRestore(transformed: "tê", rawInput: "tee")
    )
    XCTAssertTrue(
      LexiconManager.shared.shouldApplyLegacyRestore(transformed: "ò", rawInput: "of")
    )

    let oldSpell = Defaults[.spellCheckEnabled]
    let oldRestore = Defaults[.englishAutoRestoreEnabled]
    let oldPolicy = Defaults[.restorePolicy]
    defer {
      Defaults[.spellCheckEnabled] = oldSpell
      Defaults[.englishAutoRestoreEnabled] = oldRestore
      Defaults[.restorePolicy] = oldPolicy
    }
    Defaults[.spellCheckEnabled] = true
    Defaults[.englishAutoRestoreEnabled] = true
    Defaults[.restorePolicy] = .vietnameseFirst

    let engine = SpellDecisionEngine.shared
    XCTAssertEqual(
      engine.evaluate(rawInput: "tee", transformed: "tê", needsRecovery: false),
      .keepVietnamese
    )
    XCTAssertEqual(
      engine.evaluate(rawInput: "of", transformed: "ò", needsRecovery: false),
      .restoreRawEnglish("of")
    )
  }

  /// Regression 4.13: "thi"+s phải ra "thí" — trước đây keys "this" khớp
  /// list instant-restore EN (thêm từ v1.5.0, sót quy tắc dọn v2.8/v2.9)
  /// nên gõ "thí điểm" ra "this điểm". Phím tone hoàn thành từ VN hợp lệ
  /// ≥ 2 ký tự → tiếng Việt thắng instant-restore.
  func testTelexThiNotHijackedByThisInstantRestore() throws {
    XCTAssertEqual(transform_text_telex(for: "this"), "thí")
    XCTAssertEqual(transform_text_telex(for: "THIS"), "THÍ")
    XCTAssertEqual(transform_text_telex(for: "This"), "Thí")
    // Escape hatch giữ nguyên: double-s cancel tone → literal "this".
    XCTAssertEqual(transform_text_telex(for: "thiss"), "this")
    // of/if (từ VN 1 ký tự ò/ì) giữ instant-restore như cũ.
    XCTAssertEqual(transform_text_telex(for: "of"), "of")
    XCTAssertEqual(transform_text_telex(for: "if"), "if")
    // Instant-restore không kết bằng phím tone vẫn hoạt động bình thường.
    XCTAssertEqual(transform_text_telex(for: "google"), "google")
    XCTAssertEqual(transform_text_telex(for: "these"), "these")
    XCTAssertEqual(transform_text_telex(for: "there"), "there")
  }

  // MARK: - Telex: Tricky Words That Previously Had Bugs

  /// Test "xuất" and similar words
  func testTelexXuatFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "xuaats"), "xuất")
    XCTAssertEqual(transform_text_telex(for: "xuaan"), "xuân")
    XCTAssertEqual(transform_text_telex(for: "luaatj"), "luật")
    XCTAssertEqual(transform_text_telex(for: "tuaans"), "tuấn")
  }

  /// Test "được" and similar words
  func testTelexDuocFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "dduowcj"), "được")
    XCTAssertEqual(transform_text_telex(for: "muownj"), "mượn")
    XCTAssertEqual(transform_text_telex(for: "luowts"), "lướt")
    XCTAssertEqual(transform_text_telex(for: "huowng"), "hương")
  }

  /// Test words with "iê"
  func testTelexIeFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "tieengs"), "tiếng")
    XCTAssertEqual(transform_text_telex(for: "bieets"), "biết")
    XCTAssertEqual(transform_text_telex(for: "kieems"), "kiếm")
    XCTAssertEqual(transform_text_telex(for: "ddieenj"), "điện")
  }

}

// MARK: - ===========================================
// MARK: - ZWJF-Off Classic Telex Tests (v2.13)
// MARK: - ===========================================

/// Khi TẮT "cho phép âm tiết đầu w/z/j/f" (`allowedZWJF=false`), w trở thành
/// phím dấu Telex cổ điển: "w"→ư, "tw"→tư, "nhw"→như. Trước v2.13 w vẫn bị
/// giữ nguyên là "w" (engine thiếu nhánh w-không-nguyên-âm, và bảng
/// impossible-prefix khoá "tw/dw/sw/wr" thành raw English).
final class ZWJFOffTelexTests: XCTestCase {

  func testClassicTelexW_whenZWJFOff() throws {
    withZWJF(false) {
      XCTAssertEqual(telex("w"), "ư", "w đứng không phải ra ư khi ZWJF tắt")
      XCTAssertEqual(telex("W"), "Ư")
      XCTAssertEqual(telex("tw"), "tư", "tw phải ra tư — prefix 'tw' không được khoá raw")
      XCTAssertEqual(telex("nhw"), "như")
      XCTAssertEqual(telex("twf"), "từ")
      XCTAssertEqual(telex("dwa"), "dưa")
    }
  }

  // Regression: ZWJF BẬT (mặc định) → w giữ nguyên cho loanword.
  func testWStaysRawForLoanwords_whenZWJFOn() throws {
    withZWJF(true) {
      XCTAssertEqual(telex("web"), "web")
      XCTAssertEqual(telex("w"), "w")
    }
  }

  /// v4.23 (E12): gõ `w` LẦN HAI phải huỷ sạch, không để lại chữ 'u' giả.
  ///
  /// Telex cổ điển biến `w` đứng một mình thành `ư` bằng cách TỰ SINH chữ 'u'
  /// rồi đặt móc. Phím `w` kế tiếp trước đây chỉ toggle TẮT móc, nên chữ 'u'
  /// tự sinh ở lại: "ww" ra "uw", "www" ra "uww", "tww" ra "tuw" — gõ URL
  /// ("www.") thành rác. Nay `w` thứ hai rơi xuống push thô nên chuỗi hiện
  /// đúng phím đã gõ.
  ///
  /// Giới hạn đã biết: KHÔNG ra được đúng một chữ "w" cho ca "ww" vì
  /// `WordBuffer.shouldAppendRawKey` đòi `new.count == old.count`, chuỗi rỗng
  /// không được nối phím thô. "ww" (đúng những phím đã gõ) là kết quả tốt nhất
  /// đạt được mà không đụng InputProcessor.
  func testDoubleWCancelsWithoutGhostU_whenZWJFOff() throws {
    withZWJF(false) {
      XCTAssertEqual(telex("ww"), "ww", "w thứ hai huỷ, không để lại 'u' tự sinh")
      XCTAssertEqual(telex("www"), "www", "gõ 'www.' phải ra 'www', không phải 'uww'")
      XCTAssertEqual(telex("tww"), "tww", "sau phụ âm cũng vậy — không phải 'tuw'")

      // Đối chứng: mọi đường móc HỢP LỆ phải nguyên vẹn.
      XCTAssertEqual(telex("w"), "ư")
      XCTAssertEqual(telex("tw"), "tư")
      XCTAssertEqual(telex("nhw"), "như")
      // 'u' do NGƯỜI DÙNG gõ thì `w` vẫn là lệnh móc, và `w` thứ hai vẫn là
      // đường huỷ móc CŨ (chữ 'u' thật ở lại) — không được nhầm hai ca.
      XCTAssertEqual(telex("uw"), "ư")
      XCTAssertEqual(telex("uww"), "uw")
    }
  }
}
