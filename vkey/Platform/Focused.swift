//
//  Focused.swift
//
//

import AppKit
import ApplicationServices
import Foundation

public struct Focused {
  /// Timeout mặc định TOÀN TIẾN TRÌNH cho mọi message AX (giây).
  ///
  /// ⚠️ ĐẶT TIMEOUT LÊN SYSTEM-WIDE ELEMENT LÀ ĐẶT MẶC ĐỊNH CHO CẢ TIẾN TRÌNH,
  /// không phải cho riêng element đó (theo tài liệu Apple). Trước đây có BỐN
  /// chỗ cùng gọi `AXUIElementSetMessagingTimeout` lên system-wide với hai giá
  /// trị khác nhau (0,05 và 0,1) từ hai thread (tap thread và
  /// `simulationQueue`), không chỗ nào khôi phục — nên timeout thực tế của MỌI
  /// truy vấn AX nhảy 0,05↔0,1 tuỳ đường nào chạy sau cùng. Nó không phải chi
  /// tiết vô hại: timeout điều khiển thẳng xác suất đọc hụt `kAXRole` trong
  /// `fieldKind(from:)`, tức xác suất `.windowField` ↔ `.unknown` lật trục
  /// NFC/NFD GIỮA MỘT TỪ (lỗi F1). Giờ mặc định được đặt đúng MỘT lần lúc
  /// launch, còn chỗ nào cần ngắn hơn thì mượn có thời hạn qua `withAXTimeout`.
  ///
  /// F4: 0,1 là ngân sách của các đường chạy NGOÀI tap thread —
  /// `EventSimulator.axFocusedElement` + `axDirectReplace` trên `simulationQueue`,
  /// và nhịp refresh trên `focusRefreshQueue`. Ở đó chờ lâu chỉ làm chậm chính
  /// nó, không đụng tới event tap. Đường chạy MỖI PHÍM trên tap thread thì mượn
  /// `hotPathAXTimeout` — xem constant ngay dưới.
  public static let defaultAXTimeout: Float = 0.1

  /// F4 — NGÂN SÁCH CỦA ĐƯỜNG NÓNG: mọi truy vấn AX chạy trên TAP THREAD.
  ///
  /// Event tap của vkey nằm trên main run loop, và macOS TẮT tap nào chẹn quá
  /// lâu. Bốn đường sau chạy trên đó, tần suất tới từng phím:
  ///   • `EventSimulator.focusedOverlayBundle()` — mỗi keyDown khi Smart Switch bật;
  ///   • `EventSimulator.overlaySearchIsFocused()` — mỗi lần gửi thay thế;
  ///   • `Focused.snapshot()` — MỖI keyDown (leo tới 25 cấp ⇒ tới ~50 message);
  ///   • `Focused.isSecureField()` — mỗi event khi secure input đang bật.
  /// Với chúng, 0,05 KHÔNG phải "tối ưu vi mô": nó là cận trên của thời gian
  /// chẹn tap, nhân với số message của lần leo cây.
  ///
  /// ⚠️ ĐỪNG "gom" hằng này về `defaultAXTimeout` cho gọn. Vòng trước đã gom
  /// (B1.2): bốn chỗ đặt timeout rời rạc được dọn thành một mặc định ổn định
  /// 0,1 + hai chỗ mượn 0,05 — sạch hơn thật, nhưng `snapshot()` và
  /// `isSecureField()` không nằm trong hai chỗ mượn đó, nên chúng bị NÂNG từ
  /// 0,05 (giá trị mà `focusedOverlayBundle()` vô tình chốt lại trong HEAD, vì
  /// nó chạy trước và không khôi phục) lên 0,1 — tức thời gian chẹn tap xấu
  /// nhất TĂNG GẤP ĐÔI ở đúng đường nóng. Hai hằng số vì có thật hai ngân sách.
  public static let hotPathAXTimeout: Float = 0.05

  /// 1.9.0: timeout cho AX queries (giây). Gọi 1 lần lúc app launch để
  /// áp dụng global. Tránh AX call block quá lâu khi target app không
  /// responsive (vd app hang) → giảm risk macOS disable event tap.
  /// Áp dụng cho system-wide element nên cover tất cả AX query subsequent.
  public static func setupAXTimeout(_ timeoutSeconds: Float = defaultAXTimeout) {
    let systemWide = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(systemWide, timeoutSeconds)
  }

  /// Chạy `body` với timeout AX ngắn hơn mặc định rồi TRẢ LẠI
  /// `defaultAXTimeout`. Dùng cho các truy vấn chạy trên tap thread: ở đó chờ
  /// lâu làm macOS disable event tap, nên chúng cần cận trên chặt hơn mặc định
  /// — truyền `hotPathAXTimeout`, đừng viết số rời tại chỗ gọi.
  ///
  /// Chỉ dùng khi thứ cần truy vấn CHÍNH LÀ system-wide element (hỏi "ai đang
  /// focus" thì không biết trước pid, nên không có element nào khác để hỏi).
  /// Truy vấn một element đã biết thì đặt timeout LÊN CHÍNH ELEMENT ĐÓ —
  /// element-scope không rò ra toàn tiến trình (xem `focusedElement(ofPID:)`).
  ///
  /// ⚠️ Vẫn là trạng thái toàn tiến trình: một AX call trên thread khác rơi
  /// đúng cửa sổ này sẽ chịu timeout ngắn. API không có timeout theo từng lời
  /// gọi cho system-wide nên không tránh được — nhưng cửa sổ giờ hữu hạn và
  /// trạng thái ổn định là `defaultAXTimeout`, thay vì "kẻ ghi sau thắng".
  public static func withAXTimeout<T>(_ timeoutSeconds: Float, _ body: () -> T) -> T {
    let systemWide = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(systemWide, timeoutSeconds)
    defer { AXUIElementSetMessagingTimeout(systemWide, defaultAXTimeout) }
    return body()
  }

  public static func element() -> AXUIElement? {
    let systemWideElement = AXUIElementCreateSystemWide()
    return systemWideElement.getAttribute(property: kAXFocusedUIElementAttribute)
  }

  /// v3.9: phân loại ngữ cảnh của focused element (leo cây AX) để caller quyết
  /// định kiểu diff (NFC/NFD) và chiến lược gửi (synthetic vs axDirect).
  public enum FieldKind {
    /// Dưới `AXWebArea` — web content Chromium/Electron: lưu/xoá theo scalar
    /// → diff NFD synthetic.
    case webContent
    /// Trong hộp thoại modal native (`AXSheet` / cửa sổ subrole dialog) — vd
    /// `NSSavePanel`/`NSOpenPanel`: AppKit thật → diff NFC synthetic.
    case nativePanel
    /// Field thường trong cửa sổ chính (KHÔNG web area, KHÔNG dialog). Với app
    /// native = ô text bình thường; với app nhóm NFD (Chromium) đây là
    /// browser-chrome — vd THANH ĐỊA CHỈ (omnibox): field Chromium Views có
    /// inline autocomplete bôi đen → caller dùng diff NFC + chiến lược axDirect.
    case windowField
    /// Không xác định được (AX timeout / đứt chain / chạm trần) — giữ mặc định
    /// theo app.
    case unknown
  }

  /// Core leo cây AX từ `element` — tách ra để `snapshot()` tái dùng.
  /// Thứ tự kiểm tra QUAN TRỌNG: `AXWebArea` luôn là con của cửa sổ nên gặp
  /// TRƯỚC `AXWindow` → web content phân loại đúng trước khi chạm window.
  ///
  /// ⚠️ NHÁNH "ĐỌC HỤT `AXRole` → LEO PARENT" LÀ CÓ CHỦ Ý. ĐÃ THỬ SỬA, ĐÃ LÙI
  /// (v4.23/v4.24). ĐỌC HẾT TRƯỚC KHI ĐỘNG VÀO:
  ///
  /// (a) LỖI GỐC (F1, có thật, vẫn còn): hàm này chạy MỖI keyDown
  ///     (`AppState.syncFocusedContextForKeystroke`). Một hiccup AX giữa chừng
  ///     có thể đổi kết quả `.windowField` ↔ `.unknown`, mà hai giá trị đó nằm
  ///     hai bên trục NFC/NFD. Ký tự 1-3 của một từ phát theo trục A, ký tự 4
  ///     đếm backspace trên `lastTransformed` theo trục B → số backspace lệch →
  ///     ăn ngược vào chữ đã gõ (lớp lỗi v4.14 "đếm một đằng, phát một nẻo").
  /// (b) ĐÃ VÁ THẾ NÀO: (1) phân biệt `AXError` "app trả lời nhưng không có
  ///     role" với "gọi AX hụt hẳn", đọc hụt thì BỎ CUỘC SỚM trả `.unknown`;
  ///     rồi (2) đổi thành vẫn leo parent nhưng kèm cờ `fieldKindIsReliable`,
  ///     và cho `AppState.adoptFieldKind` đóng băng phân loại suốt một từ.
  /// (c) HỒI QUY ĐẺ RA:
  ///     • Cách (1) làm thanh địa chỉ Chrome MẤT `.axDirect`:
  ///       `focusedFieldIsBrowserChrome()` đòi `.windowField`, mà chỉ cần một
  ///       lần đọc hụt ở node trong cùng là ra `.unknown` → omnibox rơi về
  ///       synthetic backspace, dựng lại đúng lỗi "trường" → "truường". Và nó
  ///       VẪN lật trục giữa từ, chỉ đổi chiều (đọc được = `.windowField`/NFC,
  ///       hiccup = `.unknown`/NFD).
  ///     • Cách (2) so app bằng bundle id THÔ, trong khi AX nhảy qua lại giữa
  ///       app cha và tiến trình phụ của nó (hộp thoại Lưu của app sandbox,
  ///       helper của Chromium) — nên chốt đóng băng tự mở lại gần như mỗi
  ///       phím, tức tốn thêm một tầng trạng thái mà không chặn được gì.
  /// (d) QUYẾT ĐỊNH: giữ hành vi HEAD — đọc hụt thì leo parent, không có cờ tin
  ///     cậy, không đóng băng. F1 vẫn còn nhưng cần đúng một hiccup AX rơi vào
  ///     đúng giữa một từ; hai bản vá kia hỏng thường trực ở omnibox. Muốn vá
  ///     lại thì chốt phải đặt ở chỗ ĐẾM backspace (bất biến "dạng emit == dạng
  ///     đếm" của v4.15), không phải ở chỗ ĐO field, và phải nhận diện app theo
  ///     `InputProcessor.canonicalAppBundle` chứ không so bundle id thô.
  ///
  /// (e) LẦN THỬ THỨ BA, CŨNG ĐÃ LÙI (đợt T3). Lần này chốt đặt đúng chỗ mục (d)
  ///     yêu cầu — ở tầng ĐẾM (`InputProcessor.EmitPlan`, khoá theo vòng đời
  ///     của TỪ) — và hàm này chỉ đổi kiểu trả về thành `FieldKind?` để "đo
  ///     hụt" khác với "`.unknown`". Cả hai đã lùi. Lý do KHÔNG phải lỗi cài
  ///     đặt mà là TIỀN ĐỀ SAI, và nó nằm ngay trong cách vkey đo:
  ///     • Phép đo TỆ NHẤT — phím ĐẦU của từ, ngay sau click/⌘S khi AX còn
  ///       thấy focus CŨ — lại là phép đo KHÔNG CÓ HẬU QUẢ ở HEAD: phím 1 luôn
  ///       cho `lastTransformed == ""` ⇒ `bs == 0`, chỉ chèn một ký tự ASCII,
  ///       trục không quan sát được. Phép đo THẬT SỰ có hậu quả là phím đầu
  ///       tiên sinh dấu (thường phím 3–5, tức 200–500ms sau khi focus đổi) —
  ///       lúc AX đã lắng. Chốt theo từ lấy đúng phép đo tệ nhất rồi dán nó lên
  ///       cả từ.
  ///     • Trục sai KHÔNG đối xứng. Chốt nhầm NFC trong ô Blink là vô hại (NFC
  ///       thì 1 grapheme đúng bằng 1 scalar — đã đo, xem Tools/probe/README.md);
  ///       chốt nhầm NFD trong ô AppKit thì hỏng CÂM: gõ `Nooij` ra `Ṇ̂i`.
  ///     • Trong ca ⌘S mở hộp thoại Lưu của app Electron, HEAD TỰ HỘI TỤ VỀ
  ///       ĐÚNG (chiều lật NFD→NFC là chiều lành), còn chốt thì đóng băng cái
  ///       sai cho trọn từ.
  ///     ⇒ Đổi một lỗi ngẫu nhiên hiếm lấy một lỗi hệ thống trong thao tác hằng
  ///     ngày. Không đáng. Hàm này vì thế trả `FieldKind` KHÔNG-Optional như
  ///     HEAD: đo hụt ⇒ `.unknown`.
  /// (f) ĐIỀU KIỆN TIÊN QUYẾT NẾU AI ĐÓ MUỐN THỬ LẠI: phải ĐO TRƯỚC bằng
  ///     `Tools/probe`, đừng suy luận — (i) trục có THẬT SỰ lật giữa một từ
  ///     không, và tần suất bao nhiêu; (ii) sau click/⌘S thì bao lâu AX mới báo
  ///     đúng ô. Không có hai con số đó thì mọi hàng rào chỉ là phỏng đoán.
  private static func fieldKind(from element: AXUIElement) -> FieldKind {
    var current: AXUIElement? = element
    var depth = 0
    // Trần 25 cấp: vòng lặp luôn có cận trên để không treo trên cây bệnh/đệ quy.
    while let el = current, depth < 25 {
      guard let role: String = el.getAttribute(property: kAXRoleAttribute) else {
        // Role không đọc được ở node này (AX timeout/lỗi) — leo parent thay vì
        // bỏ cuộc sớm (sheet/dialog có thể nằm sâu hơn node lỗi).
        current = el.getAttribute(property: kAXParentAttribute)
        depth += 1
        continue
      }
      if role == "AXWebArea" { return .webContent }
      if role == "AXSheet" { return .nativePanel }
      if role == "AXWindow" {
        let subrole: String? = el.getAttribute(property: kAXSubroleAttribute)
        if subrole == "AXDialog" || subrole == "AXSystemDialog" { return .nativePanel }
        return .windowField
      }
      if role == "AXApplication" { return .windowField }
      current = el.getAttribute(property: kAXParentAttribute)
      depth += 1
    }
    return .unknown
  }

  /// v3.7: ảnh chụp trạng thái focused element trong MỘT lần fetch system-wide.
  /// Trước đây `performFocusedElementRefresh` gọi 3 hàm riêng, mỗi hàm tự
  /// `Focused.element()` → 3 round-trip AX. Gộp còn 1 fetch + 1 lần leo cây.
  ///
  /// `isComboOrSearch` đã gỡ khỏi struct này: nó tốn một lần đọc `kAXRole`
  /// RIÊNG trên focused element — trùng đúng thuộc tính mà `fieldKind(from:)`
  /// đọc ngay sau đó ở node đầu vòng lặp — và giá trị đó không còn ai dùng
  /// (chuỗi `AppState.currentFocusedElementIsSearchOrCombo` →
  /// `InputProcessor.isSearchOrComboFocused` chết từ khi v4.23 gỡ
  /// `isFixAutocompleteApp()`). Vì `snapshot()` chạy MỖI keyDown trên tap
  /// thread, đó là một round-trip AX mỗi phím trả về giá trị bị vứt.
  ///
  /// ĐÃ LÙI: `fieldKind` từng là `FieldKind?` để phân biệt "đo hụt" với
  /// `.unknown`, phục vụ quy tắc sticky-on-miss ở `AppState`. Cả cụm đó lùi
  /// cùng chốt trục theo từ — xem `fieldKind(from:)` mục (e). Đo hụt lại là
  /// `.unknown` như HEAD.
  public struct FocusSnapshot {
    public let bundleId: String?
    public let fieldKind: FieldKind
  }

  /// - Parameter timeout: ngân sách chờ cho MỌI message AX của lần chụp này.
  ///   Mặc định là `hotPathAXTimeout` vì người gọi đông nhất —
  ///   `AppState.syncFocusedContextForKeystroke` qua `EventHook` — chạy ĐỒNG BỘ
  ///   TRÊN TAP THREAD, và một lần chụp là tới ~50 message AX (leo tối đa 25
  ///   cấp, mỗi cấp đọc role + parent). Người gọi chạy trên queue nền
  ///   (`AppState.performFocusedElementRefresh`) truyền `defaultAXTimeout`:
  ///   ở đó chẹn lâu không đụng tap, mà nhịp trễ 0,5s ấy tồn tại CHÍNH LÀ để
  ///   bắt hộp thoại native xuất hiện muộn — cắt ngân sách của nó là cắt đúng
  ///   thứ nó sinh ra để làm.
  public static func snapshot(timeout: Float = hotPathAXTimeout) -> FocusSnapshot {
    withAXTimeout(timeout) {
      guard let element = Focused.element() else {
        return FocusSnapshot(bundleId: nil, fieldKind: .unknown)
      }
      var bundleId: String? = nil
      var pid: pid_t = 0
      if AXUIElementGetPid(element, &pid) == .success {
        bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
      }
      let kind = Focused.fieldKind(from: element)
      return FocusSnapshot(bundleId: bundleId, fieldKind: kind)
    }
  }

  /// Whether the currently focused UI element (in the frontmost app) is a
  /// secure/password text field. Used to decide whether system-wide secure
  /// input actually belongs to the foreground app — `CGSIsSecureEventInputSet`
  /// is global and stays on while a *background* app holds a focused password
  /// field, which would otherwise keep vkey stuck in private mode after the
  /// user switches away.
  ///
  /// Returns `false` when AX can't resolve the focused element. Callers should
  /// treat that as "front app owns it" only when the front app is already the
  /// known secure-input owner (e.g. Terminal sudo, which exposes no secure
  /// subrole) — see `EventHook`.
  ///
  /// F4: chạy trên TAP THREAD (`EventHook`), mỗi event trong lúc secure input
  /// đang bật — nên đi bằng ngân sách đường nóng.
  public static func isSecureField() -> Bool {
    withAXTimeout(hotPathAXTimeout) {
      guard let focusedElement = Focused.element() else { return false }
      if let subrole: String = focusedElement.getAttribute(property: kAXSubroleAttribute) {
        return subrole == (kAXSecureTextFieldSubrole as String)
      }
      return false
    }
  }
}

extension AXUIElement {
  public func getAttribute<T>(property: String) -> T? {
    var ptr: AnyObject?
    if AXUIElementCopyAttributeValue(self, property as CFString, &ptr) != AXError.success {
      return nil
    }
    return ptr as? T
  }
}
