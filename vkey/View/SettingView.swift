import AppKit
import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

// MARK: - Flexible Shortcut Recorder
//
// KeyboardShortcuts.Recorder (built into the library) silently rejects some
// combinations like Shift+Control+Letter. This custom recorder uses a local
// NSEvent monitor to capture *any* modifier+key combination and stores it via
// the same KeyboardShortcuts.setShortcut(_:for:) API, so the registered hotkey
// still works through the library's Carbon hotkey backend.

struct FlexibleShortcutRecorder: NSViewRepresentable {
  let name: KeyboardShortcuts.Name

  func makeNSView(context: Context) -> FlexibleShortcutButton {
    FlexibleShortcutButton(name: name)
  }

  func updateNSView(_ nsView: FlexibleShortcutButton, context: Context) {
    nsView.refresh()
  }
}

/// Format a raw modifier bitmask (NSEvent.ModifierFlags-compatible bits) as
/// the canonical macOS glyph string (⌃⌥⇧⌘) in the conventional order.
func formatModifierMask(_ raw: Int) -> String {
  var out = ""
  if raw & Int(NSEvent.ModifierFlags.control.rawValue) != 0 { out += "⌃" }
  if raw & Int(NSEvent.ModifierFlags.option.rawValue) != 0  { out += "⌥" }
  if raw & Int(NSEvent.ModifierFlags.shift.rawValue) != 0   { out += "⇧" }
  if raw & Int(NSEvent.ModifierFlags.command.rawValue) != 0 { out += "⌘" }
  return out
}

final class FlexibleShortcutButton: NSButton {
  private let name: KeyboardShortcuts.Name
  private var isRecording = false
  private var monitor: Any?

  // Tracks the highest modifier set seen during recording so we can detect
  // "modifier-only" intent: user pressed e.g. Shift+Control, then released
  // everything without pressing a letter key.
  private var pendingModifiers: Int = 0
  private var anyKeySeen = false

  init(name: KeyboardShortcuts.Name) {
    self.name = name
    super.init(frame: .zero)
    bezelStyle = .rounded
    target = self
    action = #selector(buttonClicked)
    widthAnchor.constraint(greaterThanOrEqualToConstant: 170).isActive = true
    refresh()
  }

  required init?(coder: NSCoder) { fatalError() }

  deinit { stopRecording() }

  func refresh() {
    if isRecording {
      title = "Nhập tổ hợp… (Esc: huỷ)"
      return
    }

    let modifierOnly = Defaults[.modifierOnlyToggleHotkey]
    if modifierOnly != 0 {
      title = "\(formatModifierMask(modifierOnly)) (chỉ modifier)   ⌫ xoá"
      return
    }

    if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
      title = "\(shortcut)   ⌫ xoá"
      return
    }

    title = "Bấm để đặt phím tắt"
  }

  @objc private func buttonClicked() {
    if isRecording {
      stopRecording()
    } else {
      startRecording()
    }
  }

  private func startRecording() {
    isRecording = true
    pendingModifiers = 0
    anyKeySeen = false
    refresh()
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
      guard let self else { return event }
      if self.handle(event) {
        return nil  // consumed
      }
      return event
    }
  }

  private func stopRecording() {
    isRecording = false
    pendingModifiers = 0
    anyKeySeen = false
    if let m = monitor {
      NSEvent.removeMonitor(m)
      monitor = nil
    }
    refresh()
  }

  /// Returns true if the event was consumed.
  private func handle(_ event: NSEvent) -> Bool {
    guard isRecording else { return false }

    let modifiers = event.modifierFlags
      .intersection(.deviceIndependentFlagsMask)
      .intersection([.command, .option, .control, .shift])
    let modifierRaw = Int(modifiers.rawValue)

    // .flagsChanged: track modifier-only intent.
    if event.type == .flagsChanged {
      if modifierRaw > pendingModifiers {
        // User added more modifiers — remember the largest combo.
        pendingModifiers = modifierRaw
      } else if modifierRaw == 0 && pendingModifiers != 0 && !anyKeySeen {
        // All modifiers released without ever pressing a letter key →
        // save this combination as a modifier-only hotkey, and clear any
        // previously set key+modifier shortcut.
        Defaults[.modifierOnlyToggleHotkey] = pendingModifiers
        KeyboardShortcuts.reset(name)
        stopRecording()
        return true
      }
      return true
    }

    // .keyDown from here on.
    anyKeySeen = true
    let keyCode = Int(event.keyCode)

    // Escape with no modifiers → cancel
    if keyCode == 53 && modifiers.isEmpty {
      stopRecording()
      return true
    }

    // Backspace / Forward-delete with no modifiers → clear BOTH shortcut types
    if (keyCode == 51 || keyCode == 117) && modifiers.isEmpty {
      KeyboardShortcuts.reset(name)
      Defaults[.modifierOnlyToggleHotkey] = 0
      stopRecording()
      return true
    }

    // Standard key+modifier shortcut. Clear any modifier-only override so
    // only one hotkey kind is active at a time.
    let key = KeyboardShortcuts.Key(rawValue: keyCode)
    let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    KeyboardShortcuts.setShortcut(shortcut, for: name)
    Defaults[.modifierOnlyToggleHotkey] = 0
    stopRecording()
    return true
  }
}

struct GeneralView: View {
    @EnvironmentObject var appState: AppState
    @Default(.newStyleTonePlacement) private var newStyleTonePlacement
    @Default(.autoTypoCorrection) private var autoTypoCorrection
    @Default(.hudEnabled) private var hudEnabled
    // 2.0 (A5): auto-capitalize đầu câu
    @Default(.autoCapitalizeEnabled) private var autoCapitalizeEnabled
    // 2.0 (B2): tự động disable khi đổi sang non-Latin IME
    @Default(.nonLatinIMEAutoDisable) private var nonLatinIMEAutoDisable
    // 2.0 (A6): free mark mode
    @Default(.freeMarkModeEnabled) private var freeMarkModeEnabled
    // v2.1.1: theme picker
    @Default(.uiTheme) private var uiTheme

    /// v2.1.1+: settings header rẽ nhánh theo theme.
    @ViewBuilder
    private var settingsHeader: some View {
        switch uiTheme {
        case .tonal:
            VStack(spacing: 10) {
                Image(uiTheme.headerImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: VKeyDesign.red500.opacity(0.28), radius: 16, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
                Text("vkey")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(VKeyDesign.red500)
                    .tracking(-0.8)
                Text("Bộ gõ tiếng Việt thông minh cho macOS")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        case .muc:
            // v2.2.0: editorial style — serif wordmark, sharp radii, no glow,
            // editorial double-rule under wordmark.
            VStack(spacing: 8) {
                Image(uiTheme.headerImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                Text("vkey")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(VKeyDesign.mucRed500)
                    .tracking(-0.3)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(VKeyDesign.mucInk500)
                        .frame(height: 1)
                    Spacer().frame(height: 2)
                    Rectangle()
                        .fill(VKeyDesign.mucInk500)
                        .frame(height: 3)
                }
                .frame(width: 64)
                .padding(.vertical, 2)
                Text("Bộ gõ tiếng Việt cho macOS")
                    .font(.system(size: 11.5, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
                    .italic()
            }
        case .classic:
            Image(uiTheme.headerImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
    }
    // 1.9.0: HUD customization
    // 1.9.2: 2 vars dưới chuyển sang SpellCheckView (cùng block prediction).

    let appVersion = Bundle.main.appVersionLong

    var body: some View {
        VStack(spacing: 0) {
            // v2.1.1: header rẽ nhánh theo theme.
            //   .tonal   → app icon 84px + wordmark "vkey" + tagline + glow
            //   .classic → icon 96px centered, no wordmark (v2.0.2 look)
            settingsHeader
                .padding(.top, 16)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)

            // Form gives native macOS label-right / control-left layout and
            // centers the whole block horizontally inside its container.
            // v2.2.0: theme picker đã được di chuyển ra MenuBar dropdown
            // (vkeyApp.swift), nhóm cùng với "Giao diện ứng dụng" để có
            // tổng 5 lựa chọn (Mặc định / 3D / Emoji / Tonal / Mực).
            Form {
                Toggle(isOn: $appState.enabled) {
                    Label("Bật / Tắt gõ TV", themedSymbol: "keyboard")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                LaunchAtLogin.Toggle {
                    Label("Tự khởi động cùng hệ thống", themedSymbol: "arrow.up.right.square")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                Picker(selection: $appState.typingMethod) {
                    ForEach(TypingMethods.allCases, id: \.self) { method in
                        Text(method.rawValue)
                    }
                } label: {
                    Label("Kiểu gõ", themedSymbol: "abc")
                }
                .pickerStyle(.segmented)

                Toggle(isOn: $appState.allowedZWJF) {
                    Label("Phụ âm z, w, j, f", themedSymbol: "character")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                Toggle(isOn: $autoTypoCorrection) {
                    Label("Tự động sửa lỗi gõ nhầm", themedSymbol: "sparkles")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                // 2.0 (A5): viết hoa đầu câu sau . ! ? Enter
                Toggle(isOn: $autoCapitalizeEnabled) {
                    Label("Viết hoa đầu câu (sau . ! ? Enter)", themedSymbol: "textformat.size")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                // 2.0 (B2): tự động tắt khi đổi sang IME tiếng Nhật / Trung / Hàn
                Toggle(isOn: $nonLatinIMEAutoDisable) {
                    Label("Tự tắt khi đổi sang IME khác (Nhật/Trung/Hàn)", themedSymbol: "globe")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                Toggle(isOn: $hudEnabled) {
                    Label("Hiển thị thông báo khi chuyển VI/EN", themedSymbol: "macwindow.badge.plus")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                // 2.0 (A6): free mark mode — đặt dấu tự do
                // 2.0.1: di chuyển xuống đây theo yêu cầu (dưới hudEnabled, trên Kiểu đặt dấu)
                Toggle(isOn: $freeMarkModeEnabled) {
                    Label("Đặt dấu tự do (Free Mark)", themedSymbol: "wand.and.stars")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                if freeMarkModeEnabled {
                    Text("Bỏ kiểm tra cấu trúc âm tiết — đặt dấu ở vị trí bất kỳ. Hữu ích cho tên riêng / tiếng dân tộc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, -8)
                }

                Picker(selection: $newStyleTonePlacement) {
                    Text("Kiểu cũ").tag(false)
                    Text("Kiểu mới").tag(true)
                } label: {
                    Label("Kiểu đặt dấu", themedSymbol: "textformat")
                }
                .pickerStyle(.segmented)
                
                if newStyleTonePlacement {
                    Text("Ví dụ kiểu mới: oà, uý, khoẻ, thuỷ,...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, -8)
                } else {
                    Text("Ví dụ kiểu cũ: òa, úy, khỏe, thủy,...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, -8)
                }

                // 2.0.2 (J3): đổi label "Phím tắt" → "Phím tắt chuyển đổi VI/EN".
                // Default modifier-only: ⇧⌥ (Shift+Option) — set qua
                // `Defaults.Keys.modifierOnlyToggleHotkey`. User vẫn có thể
                // gán key+modifier qua FlexibleShortcutRecorder bên dưới.
                LabeledContent {
                    FlexibleShortcutRecorder(name: .toggleInputMode)
                } label: {
                    Label("Phím tắt chuyển đổi VI/EN", themedSymbol: "command")
                }

                // 2.0 (B4) + 2.0.2 (J3): hotkey Text Tools.
                // Default modifier-only ⌃⇧ qua `modifierOnlyTextToolsHotkey`.
                LabeledContent {
                    FlexibleShortcutRecorder(name: .openTextConversionMenu)
                } label: {
                    Label("Phím tắt Text Tools", themedSymbol: "textformat")
                }

                // 2.0.1: Floating Toolbar + HUDThemeSection đã bị xoá theo
                // yêu cầu user — HUD opacity/font đã có trong block "Đoán từ
                // tiếp theo" (tab Chính tả) cho HUD thực tế đang dùng.

            }
            .formStyle(.grouped)
            .scrollDisabled(false)

            // v2.2.0 "Theme Library" — 5 themes (Mặc định / 3D / Emoji / Tonal / Mực)
            // chuyển ra MenuBar; thêm Mực; fix bug gõ "theme" → "thêm".
            Text("Phiên bản \(appVersion) ngày 22/5/2026")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 200, minHeight: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 2.0.1: HUDThemeSection đã được xoá. 3 control (theme/blur/accent) chưa
// thực sự kết nối tới ToggleHUD/PredictionHUD nên gây nhầm lẫn cho user.
// `hudOpacityPercent` (Defaults từ 1.9.0) vẫn còn và đang hoạt động — đủ
// cho nhu cầu chỉnh độ mờ HUD.

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView()
            .environmentObject(AppState())
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
            .previewDisplayName("GeneralView preview")
    }
}

/// 1.9.1: Preset cấu hình nhanh tính năng. Tags 0..3 map vào Defaults Int.
enum QuickConfigPreset: Int {
    case custom = 0
    case basic = 1
    case medium = 2
    case high = 3
}

struct SpellCheckView: View {
    @Default(.spellCheckEnabled) private var spellCheckEnabled
    @Default(.spellCheckInSentenceEnabled) private var spellCheckInSentenceEnabled
    @Default(.englishAutoRestoreEnabled) private var englishAutoRestoreEnabled
    @Default(.restorePolicy) private var restorePolicy
    @Default(.suggestionEnabled) private var suggestionEnabled
    @Default(.autoApplyHighConfidenceSuggestion) private var autoApplyHighConfidenceSuggestion
    @Default(.personalDictionaryEnabled) private var personalDictionaryEnabled
    @Default(.useEnVnReference) private var useEnVnReference
    @Default(.autoPersonalDictFeedback) private var autoPersonalDictFeedback
    @Default(.pendingDictSuggestions) private var pendingSuggestions
    // 1.8.3: chuyển từ Tab Chung sang đây — prediction thuộc chức năng spell-checking.
    @Default(.wordPredictionEnabled) private var wordPredictionEnabled
    // 2.0.2 (J1): xoá `predictionTopN` — prediction về top-1 only.
    @Default(.predictionHUDLineOffset) private var predictionHUDLineOffset
    // 1.9.2: HUD customization chuyển từ Tab Chung sang đây — chỉ visible
    // khi `wordPredictionEnabled = true`. Gom cùng nhóm cài đặt prediction.
    @Default(.predictionHUDFontSize) private var predictionHUDFontSize
    @Default(.hudOpacityPercent) private var hudOpacityPercent

    // 1.9.1: quick config preset
    @Default(.quickConfigPreset) private var quickConfigPreset
    @Default(.autoTypoCorrection) private var autoTypoCorrection
    // 1.7.11: cần đọc 3 danh sách để gate nút "Gửi cho tác giả" (≥50 từ).
    @Default(.userAllowWords) private var userAllowWordsView
    @Default(.userKeepWords) private var userKeepWordsView
    @Default(.userDenyWords) private var userDenyWordsView

    @State private var showingPersonalDictEditor = false
    @State private var showingSuggestionSheet = false

    // 1.6.2+: state cho nút "Cập nhật từ điển ngay".
    @State private var isCheckingDictUpdate = false
    @State private var dictUpdateStatus = ""
    @State private var lexiconVnVersion: Int = 0
    @State private var lexiconVnEntries: Int = 0
    // 1.7.10: expose số từ Anh trong bộ nhớ + version.
    @State private var lexiconEnVersion: Int = 0
    @State private var lexiconEnEntries: Int = 0

    /// 1.9.1: mô tả ngắn của preset hiện tại để hiển thị dưới Picker.
    private var quickConfigDescription: String {
        switch QuickConfigPreset(rawValue: quickConfigPreset) ?? .custom {
        case .high:
            return "Bật tất cả tính năng auto: spell-check, suggestion, auto-apply, personal dict, prediction, auto-typo, EnVn reference, auto-feedback. vkey can thiệp tối đa để \"hiểu ý\" user."
        case .medium:
            return "Cân bằng: spell-check + auto-restore EN + suggestion (không auto-apply) + personal dict + auto-typo. User vẫn review suggestion thủ công. Tắt: prediction, auto-feedback."
        case .basic:
            return "Tối giản: chỉ spell-check master + personal dict. Tắt mọi auto-feature. vkey \"trong suốt\" nhất, không can thiệp."
        case .custom:
            return "Tự chỉnh từng toggle bên dưới. Picker này chỉ áp dụng preset 1 chiều — sau đó user free điều chỉnh, picker vẫn hiển thị preset gốc đã chọn."
        }
    }

    /// 1.9.1: apply preset → batch update các toggle. Skip nếu preset .custom.
    private func applyQuickConfigPreset(_ preset: QuickConfigPreset) {
        switch preset {
        case .high:
            spellCheckEnabled = true
            spellCheckInSentenceEnabled = true
            englishAutoRestoreEnabled = true
            suggestionEnabled = true
            autoApplyHighConfidenceSuggestion = true
            personalDictionaryEnabled = true
            autoPersonalDictFeedback = true
            useEnVnReference = true
            wordPredictionEnabled = true
            autoTypoCorrection = true
        case .medium:
            spellCheckEnabled = true
            spellCheckInSentenceEnabled = true
            englishAutoRestoreEnabled = true
            suggestionEnabled = true
            autoApplyHighConfidenceSuggestion = false
            personalDictionaryEnabled = true
            autoPersonalDictFeedback = false
            useEnVnReference = true
            wordPredictionEnabled = false
            autoTypoCorrection = true
        case .basic:
            spellCheckEnabled = true
            spellCheckInSentenceEnabled = false
            englishAutoRestoreEnabled = false
            suggestionEnabled = false
            autoApplyHighConfidenceSuggestion = false
            personalDictionaryEnabled = true
            autoPersonalDictFeedback = false
            useEnVnReference = false
            wordPredictionEnabled = false
            autoTypoCorrection = false
        case .custom:
            break  // không change toggles
        }
    }

    // 1.9.3: Section "Tra cứu từ điển" + property `lexiconSearchResult`
    // đã được xóa theo user feedback.

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // 1.9.1: Section "Cấu hình nhanh" — thay thế toggle "Kích
                // hoạt nhanh tất cả" cũ bằng Picker 4-state cho phép user
                // chọn mức tính năng (Cao/Trung bình/Cơ bản/Người dùng).
                Section {
                    Picker("", selection: $quickConfigPreset) {
                        Text("Cao").tag(QuickConfigPreset.high.rawValue)
                        Text("Trung bình").tag(QuickConfigPreset.medium.rawValue)
                        Text("Cơ bản").tag(QuickConfigPreset.basic.rawValue)
                        Text("Người dùng").tag(QuickConfigPreset.custom.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: quickConfigPreset) { _, newValue in
                        applyQuickConfigPreset(QuickConfigPreset(rawValue: newValue) ?? .custom)
                    }
                    Text(quickConfigDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Cấu hình nhanh", themedSymbol: "slider.horizontal.3")
                }

                // Section 2 (v1.7.0): "Cấu hình kiểm tra chính tả" — gộp
                // master toggle + personal dict + auto-feedback vào CÙNG section
                // để giảm cognitive load.
                // v1.7.2: trim caption + bỏ Spacer() trong HStack button.
                // v1.7.3: bỏ Divider() giữa các sub-toggle — Form đã có row
                // separator tự nhiên. Bỏ giúp giảm ~30px khoảng trống mỗi
                // Divider.
                Section {
                    Toggle(isOn: $spellCheckEnabled) {
                        Label("Kiểm tra chính tả", themedSymbol: "checkmark.circle")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                    if spellCheckEnabled {
                        Toggle(isOn: $suggestionEnabled) {
                            Label("Gợi ý sửa lỗi chính tả", themedSymbol: "lightbulb")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        if suggestionEnabled {
                            Toggle(isOn: $autoApplyHighConfidenceSuggestion) {
                                Label("Tự động sửa khi tin cậy cao", themedSymbol: "wand.and.stars")
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        }

                        Toggle(isOn: $personalDictionaryEnabled) {
                            Label("Sử dụng từ điển cá nhân", themedSymbol: "person.circle")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        // 1.7.11: 2 nút song song — "Sửa từ điển cá nhân"
                        // (đổi tên từ "Quản lý") + "Gửi cho tác giả" (đưa
                        // ra ngoài, trước đây nằm trong Personal Dict Editor).
                        HStack {
                            Spacer()
                            Button(action: { showingPersonalDictEditor = true }) {
                                Label("Sửa từ điển cá nhân", themedSymbol: "pencil.and.outline")
                            }
                            Button(action: sendDictToAuthor) {
                                Label("Gửi cho tác giả", themedSymbol: "envelope.fill")
                            }
                            .disabled(totalPersonalDictCount() < 50)
                            .help("Yêu cầu ≥50 từ trong tổng 3 danh sách. Mở mail compose tới tuanlong.sav@gmail.com.")
                            Spacer()
                        }

                        Toggle(isOn: $autoPersonalDictFeedback) {
                            Label("Tự động đề xuất hàng tuần",
                                  themedSymbol: "person.crop.circle.badge.checkmark")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        Button {
                            showingSuggestionSheet = true
                        } label: {
                            Label("Xem đề xuất (\(pendingSuggestions.count))",
                                  themedSymbol: "tray.full")
                        }
                        .disabled(pendingSuggestions.isEmpty)
                        .frame(maxWidth: .infinity, alignment: .center)

                        // 1.8.3: Đoán từ tiếp theo — chuyển từ Tab Chung sang đây.
                        Toggle(isOn: $wordPredictionEnabled) {
                            Label("Đoán từ tiếp theo", themedSymbol: "wand.and.stars")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        if wordPredictionEnabled {
                            Text("Sau khi gõ xong 1 từ + dấu cách, vkey hiển thị HUD nhỏ cạnh cursor với từ đoán tiếp theo (vd \"tiếp\" → \"theo\"). Nhấn ⇥ Tab để chấp nhận; phím khác → bỏ qua. Ưu tiên gợi ý từ trong từ điển gốc + từ điển cá nhân.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, -8)

                            // 2.0.2 (J1): xoá Stepper "Số gợi ý hiển thị". Prediction
                            // về top-1 only — digit 1/2/3 dễ nhầm với gõ số.

                            // v2.2.0: range mở rộng 1...10 → 1...20 (theo user request).
                            Stepper(value: $predictionHUDLineOffset, in: 1...20) {
                                HStack {
                                    Label("Khoảng cách HUD đến caret", themedSymbol: "arrow.up.and.down")
                                    Spacer()
                                    Text("\(predictionHUDLineOffset) dòng")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            Text("HUD đặt phía trên (hoặc dưới nếu không đủ chỗ) caret line, cách xa khoảng N dòng văn bản để không che nội dung đang gõ.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, -8)

                            // 1.9.2: cỡ chữ + độ đậm HUD — gom cùng block.
                            // 1.9.4: range mở rộng — chữ 10-20 → 12-24,
                            // opacity 50-100 → 30-100. Default font 13→16,
                            // opacity 100→75 (cho user mới).
                            Stepper(value: $predictionHUDFontSize, in: 12...24) {
                                HStack {
                                    Label("Cỡ chữ HUD đoán từ", themedSymbol: "textformat.size")
                                    Spacer()
                                    Text("\(predictionHUDFontSize) pt")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            Stepper(value: $hudOpacityPercent, in: 30...100, step: 5) {
                                HStack {
                                    Label("Độ đậm HUD", themedSymbol: "circle.lefthalf.filled")
                                    Spacer()
                                    Text("\(hudOpacityPercent)%")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            Text("Cỡ chữ chỉ áp dụng cho HUD đoán từ. Độ đậm áp dụng cho cả HUD đoán từ và HUD báo chuyển bộ gõ (Tiếng Việt / Tiếng Anh). Giảm độ đậm xuống thấp để HUD rất trong suốt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, -8)
                        }
                    }
                } header: {
                    Text("Cấu hình kiểm tra chính tả")
                }

                if spellCheckEnabled {
                    // v1.7.1: Section "Gợi ý & Sửa lỗi chính tả" đã được merge
                    // vào Section "Cấu hình kiểm tra chính tả" ở trên.

                    // Section: Space Restore
                    Section {
                        Toggle(isOn: $englishAutoRestoreEnabled) {
                            Label("Tự động khôi phục tiếng Anh", themedSymbol: "arrow.uturn.backward")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        if englishAutoRestoreEnabled {
                            Picker(selection: $restorePolicy) {
                                Text("Ưu tiên tiếng Việt").tag(RestorePolicy.vietnameseFirst)
                                Text("Cân bằng").tag(RestorePolicy.balanced)
                                Text("Ưu tiên tiếng Anh").tag(RestorePolicy.englishFirst)
                            } label: {
                                Label("Chính sách khôi phục", themedSymbol: "slider.horizontal.3")
                            }
                            .pickerStyle(.segmented)

                            Text("Lựa chọn cách xử lý đối với các từ mơ hồ giữa tiếng Việt và tiếng Anh (ví dụ: 'of', 'if', 'see', 'tee').")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, -4)

                            Toggle(isOn: $useEnVnReference) {
                                Label("Dùng từ điển tham chiếu Anh-Việt", themedSymbol: "character.book.closed")
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                            Text("Mở rộng nhận diện tiếng Anh bằng từ điển song ngữ (mới ở v1.5.0). Nguồn dữ liệu: Wiktionary qua Wiktextract/Kaikki.org (CC BY-SA 4.0) — xem LICENSE-DATA.md.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, -4)
                        }
                    } header: {
                        Text("Tự động khôi phục tiếng Anh (Space Restore)")
                    }

                    // v1.7.0: "Từ điển cá nhân" + "Học hành vi từ Thống kê"
                    // đã được merge vào Section "Cấu hình kiểm tra chính tả" ở trên.

                    // Section: Từ điển từ GitHub (1.6.2+ — manual update button).
                    // Auto-update vẫn chạy 24h/lần khi launch; button này cho user
                    // force refresh ngay khi cần (vd vừa thấy maintainer release
                    // version mới mà chưa đợi đủ 24h).
                    Section {
                        // 1.7.10: hiện 2 dòng cho VN + EN counts.
                        HStack {
                            Text("Tiếng Việt:")
                                .font(.caption)
                            Text("v\(lexiconVnVersion)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(lexiconVnEntries) từ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        HStack {
                            Text("Tiếng Anh:")
                                .font(.caption)
                            Text("v\(lexiconEnVersion)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(lexiconEnEntries) từ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        HStack {
                            Spacer()
                            Button(action: triggerManualDictUpdate) {
                                Label(isCheckingDictUpdate ? "Đang kiểm tra…" : "Cập nhật từ điển ngay",
                                      themedSymbol: "arrow.down.circle")
                            }
                            .disabled(isCheckingDictUpdate)
                            Spacer()
                        }
                        .padding(.top, 4)

                        if !dictUpdateStatus.isEmpty {
                            Text(dictUpdateStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 2)
                        }

                        Text("vkey tự kiểm tra bản từ điển mới mỗi 24 giờ. Bấm \"Cập nhật ngay\" để kiểm tra thủ công (vd khi maintainer vừa publish bản mới hơn).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } header: {
                        Text("Từ điển từ GitHub")
                    }

                    // 1.9.3: Section "Tra cứu từ điển" đã được xóa theo
                    // user feedback (không cần thiết, gây phân tâm).

                    // v1.7.0: Section "Học hành vi từ Thống kê" đã được merge
                    // vào Section "Cấu hình kiểm tra chính tả" ở trên.

                    // 1.6.1: Section "Đoán từ tiếp theo" đã chuyển sang
                    // tab Chung — feature global, không trực thuộc spell check.
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(false)
        }
        .frame(minWidth: 200, minHeight: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingPersonalDictEditor) {
            PersonalDictionaryEditorView()
        }
        .sheet(isPresented: $showingSuggestionSheet) {
            PersonalDictSuggestionSheet()
        }
        .onAppear(perform: refreshDictMetadata)
    }

    // MARK: - Dict update actions (1.6.2+)

    private func refreshDictMetadata() {
        let versions = LexiconManager.shared.snapshotVersions()
        lexiconVnVersion = versions.vn
        lexiconVnEntries = LexiconManager.shared.vietnameseWordsSnapshot().count
        // 1.7.10: cũng đọc EN.
        lexiconEnVersion = versions.en
        lexiconEnEntries = LexiconManager.shared.englishWordsSnapshot().count
    }

    private func triggerManualDictUpdate() {
        isCheckingDictUpdate = true
        dictUpdateStatus = ""
        LexiconManager.shared.downloadAndUpdateLexicon { updated in
            DispatchQueue.main.async {
                isCheckingDictUpdate = false
                refreshDictMetadata()
                if updated {
                    dictUpdateStatus = "✓ Đã cập nhật. Phiên bản mới: v\(lexiconVnVersion) — \(lexiconVnEntries) từ."
                } else {
                    dictUpdateStatus = "Đã ở phiên bản mới nhất (v\(lexiconVnVersion))."
                }
            }
        }
    }

    // 1.7.11: helpers cho nút "Gửi cho tác giả" ngoài Personal Dict Editor.
    private func totalPersonalDictCount() -> Int {
        userAllowWordsView.count + userKeepWordsView.count + userDenyWordsView.count
    }

    private func sendDictToAuthor() {
        let allowJoined = userAllowWordsView.joined(separator: ", ")
        let keepJoined = userKeepWordsView.joined(separator: ", ")
        let denyJoined = userDenyWordsView.joined(separator: ", ")
        let body = """
        Chào tác giả vkey,

        Tôi xin gửi từ điển cá nhân để bạn rà soát và bổ sung vào từ điển chung nếu phù hợp.

        --- Allow (\(userAllowWordsView.count) từ) ---
        \(allowJoined)

        --- Keep (\(userKeepWordsView.count) từ) ---
        \(keepJoined)

        --- Deny (\(userDenyWordsView.count) từ) ---
        \(denyJoined)

        ---
        Phiên bản vkey: \(Bundle.main.appVersionLong)
        """
        let subject = "[vkey] Đề xuất bổ sung từ điển cá nhân"
        let allowed = CharacterSet.urlQueryAllowed
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let urlStr = "mailto:tuanlong.sav@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct SpellCheckView_Previews: PreviewProvider {
    static var previews: some View {
        SpellCheckView()
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
            .previewDisplayName("SpellCheckView preview")
    }
}

struct PersonalDictionaryEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var newWord = ""
    
    @Default(.userAllowWords) private var userAllowWords
    @Default(.userKeepWords) private var userKeepWords
    @Default(.userDenyWords) private var userDenyWords
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Quản lý từ điển cá nhân")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
            Picker("Loại từ điển", selection: $selectedTab) {
                Text("Cho phép (Allow)").tag(0)
                Text("Ưu tiên giữ (Keep)").tag(1)
                Text("Loại bỏ (Deny)").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Add Word Form
            HStack {
                TextField("Nhập từ mới…", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addWord()
                    }
                Button("Thêm") {
                    addWord()
                }
                .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // List of words
            List {
                let words = currentWordsList()
                if words.isEmpty {
                    Text("Chưa có từ nào trong danh sách.")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(words, id: \.self) { word in
                        HStack {
                            Text(word)
                            Spacer()
                            Button(action: {
                                removeWord(word)
                            }) {
                                ThemedSymbol(name: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(height: 200)

            Divider()

            // 1.7.11: "Gửi từ điển cho tác giả" đã được đưa ra tab Chính tả
            // (cạnh nút "Sửa từ điển cá nhân"), không cần lặp lại trong editor.

            HStack {
                Spacer()
                Button("Đóng") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 400, height: 520)
    }
    
    private func currentWordsList() -> [String] {
        switch selectedTab {
        case 0: return userAllowWords
        case 1: return userKeepWords
        case 2: return userDenyWords
        default: return []
        }
    }
    
    private func addWord() {
        let cleaned = newWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return }
        
        switch selectedTab {
        case 0:
            if !userAllowWords.contains(cleaned) {
                userAllowWords.append(cleaned)
            }
        case 1:
            if !userKeepWords.contains(cleaned) {
                userKeepWords.append(cleaned)
            }
        case 2:
            if !userDenyWords.contains(cleaned) {
                userDenyWords.append(cleaned)
            }
        default:
            break
        }
        
        newWord = ""
    }
    
    private func removeWord(_ word: String) {
        switch selectedTab {
        case 0:
            userAllowWords.removeAll(where: { $0 == word })
        case 1:
            userKeepWords.removeAll(where: { $0 == word })
        case 2:
            userDenyWords.removeAll(where: { $0 == word })
        default:
            break
        }
    }
}
