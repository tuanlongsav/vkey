//
//  Focused.swift
//
//

import AppKit
import ApplicationServices
import Foundation

public struct Focused {
  /// 1.9.0: timeout cho AX queries (giây). Gọi 1 lần lúc app launch để
  /// áp dụng global. Tránh AX call block quá lâu khi target app không
  /// responsive (vd app hang) → giảm risk macOS disable event tap.
  /// Áp dụng cho system-wide element nên cover tất cả AX query subsequent.
  public static func setupAXTimeout(_ timeoutSeconds: Float = 0.1) {
    let systemWide = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(systemWide, timeoutSeconds)
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
  public struct FocusSnapshot {
    public let bundleId: String?
    public let isComboOrSearch: Bool
    public let fieldKind: FieldKind
  }

  public static func snapshot() -> FocusSnapshot {
    guard let element = Focused.element() else {
      return FocusSnapshot(bundleId: nil, isComboOrSearch: false, fieldKind: .unknown)
    }
    var bundleId: String? = nil
    var pid: pid_t = 0
    if AXUIElementGetPid(element, &pid) == .success {
      bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }
    let role: String? = element.getAttribute(property: kAXRoleAttribute)
    let isComboOrSearch = (role == "AXComboBox" || role == "AXSearchField")
    let kind = Focused.fieldKind(from: element)
    return FocusSnapshot(
      bundleId: bundleId, isComboOrSearch: isComboOrSearch, fieldKind: kind)
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
  public static func isSecureField() -> Bool {
    guard let focusedElement = Focused.element() else { return false }
    if let subrole: String = focusedElement.getAttribute(property: kAXSubroleAttribute) {
      return subrole == (kAXSecureTextFieldSubrole as String)
    }
    return false
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
