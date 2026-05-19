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

    let appVersion = Bundle.main.appVersionLong

    var body: some View {
        VStack(spacing: 0) {
            Image("Cficon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)

            // Form gives native macOS label-right / control-left layout and
            // centers the whole block horizontally inside its container.
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
                
                Toggle(isOn: $hudEnabled) {
                    Label("Hiển thị thông báo khi chuyển VI/EN", themedSymbol: "macwindow.badge.plus")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    
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

                LabeledContent {
                    FlexibleShortcutRecorder(name: .toggleInputMode)
                } label: {
                    Label("Phím tắt", themedSymbol: "command")
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(false)

            Text(
                "Version \(appVersion)"
            )
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .italic()
            .padding(.top, 8)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 440, height: 560)
    }
}

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView()
            .environmentObject(AppState())
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
            .previewDisplayName("GeneralView preview")
    }
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
    @Default(.wordPredictionEnabled) private var wordPredictionEnabled

    @State private var showingPersonalDictEditor = false
    @State private var showingSuggestionSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // Section 1: Master quick-enable
                Section {
                    Toggle(isOn: Binding(
                        get: {
                            spellCheckEnabled && spellCheckInSentenceEnabled
                                && englishAutoRestoreEnabled && suggestionEnabled
                                && autoApplyHighConfidenceSuggestion && personalDictionaryEnabled
                                && useEnVnReference
                        },
                        set: { newValue in
                            spellCheckEnabled = newValue
                            spellCheckInSentenceEnabled = newValue
                            englishAutoRestoreEnabled = newValue
                            suggestionEnabled = newValue
                            autoApplyHighConfidenceSuggestion = newValue
                            personalDictionaryEnabled = newValue
                            useEnVnReference = newValue
                        }
                    )) {
                        Label("Kích hoạt nhanh tất cả tính năng mới", themedSymbol: "sparkles")
                            .fontWeight(.semibold)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                } header: {
                    Text("Phím tắt thông minh")
                }

                // Section 2: Kiểm tra chính tả
                Section {
                    Toggle(isOn: $spellCheckEnabled) {
                        Label("Kiểm tra chính tả", themedSymbol: "checkmark.circle")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                    if spellCheckEnabled {
                        Toggle(isOn: $spellCheckInSentenceEnabled) {
                            Label("Kiểm tra trong câu", themedSymbol: "text.justify.left")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                } header: {
                    Text("Cấu hình Kiểm tra")
                }

                if spellCheckEnabled {
                    // Section 3: Gợi ý & Sửa lỗi chính tả (moved up, sát "Kiểm tra")
                    Section {
                        Toggle(isOn: $suggestionEnabled) {
                            Label("Gợi ý sửa lỗi chính tả", themedSymbol: "lightbulb")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        if suggestionEnabled {
                            Toggle(isOn: $autoApplyHighConfidenceSuggestion) {
                                Label("Tự động sửa khi tin cậy cao", themedSymbol: "wand.and.stars")
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                            Text("Tự động áp dụng từ gợi ý nếu độ tin cậy đạt mức rất cao (>= 88%).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, -4)
                        }
                    } header: {
                        Text("Gợi ý & Sửa lỗi chính tả")
                    }

                    // Section 4: Space Restore
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

                    // Section 5: Personal dictionary
                    Section {
                        Toggle(isOn: $personalDictionaryEnabled) {
                            Label("Sử dụng từ điển cá nhân", themedSymbol: "person.circle")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        Text("Áp dụng danh sách từ tự thêm (allow/keep/deny) do bạn cấu hình trong phần mềm.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, -4)

                        // 1.5.6: button luôn hiển thị (kể cả khi toggle tắt) để user
                        // còn có chỗ chỉnh sửa cố định 1 nơi. Cũng dùng cho user
                        // bật "Tự động cập nhật từ Thống kê" ở Section bên dưới
                        // — họ vẫn cần chỗ chỉnh sửa khi auto promote sai.
                        HStack {
                            Spacer()
                            Button(action: { showingPersonalDictEditor = true }) {
                                Label("Quản lý từ điển cá nhân", themedSymbol: "pencil.and.outline")
                            }
                            Spacer()
                        }
                        .padding(.top, 4)
                    } header: {
                        Text("Từ điển cá nhân")
                    }

                    // Section 6: Auto-feedback đề xuất từ Thống kê (1.6.0+).
                    // Thay đổi semantic: KHÔNG còn auto-write nữa — chỉ compute
                    // đề xuất pending. User review qua sheet, chốt thêm.
                    Section {
                        Toggle(isOn: $autoPersonalDictFeedback) {
                            Label("Tự động compute đề xuất hàng tuần",
                                  themedSymbol: "person.crop.circle.badge.checkmark")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        Text("Mỗi tuần, vkey nhận thấy các từ bạn gõ nhiều và tạo danh sách ĐỀ XUẤT thêm vào Allow / Keep. Bạn review, sửa loại, rồi quyết định thêm — vkey KHÔNG tự ý ghi vào từ điển cá nhân (tránh sai).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Spacer()
                            Button {
                                showingSuggestionSheet = true
                            } label: {
                                Label("Xem đề xuất pending (\(pendingSuggestions.count))",
                                      themedSymbol: "tray.full")
                            }
                            .disabled(pendingSuggestions.isEmpty)
                            Spacer()
                        }
                        .padding(.top, 4)
                    } header: {
                        Text("Học hành vi từ Thống kê")
                    }

                    // Section 7: Đoán từ tiếp theo — 1.6.0 thử nghiệm.
                    Section {
                        Toggle(isOn: $wordPredictionEnabled) {
                            Label("Đoán từ tiếp theo", themedSymbol: "wand.and.stars")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        Text("Sau khi gõ xong 1 từ + dấu cách, vkey hiển thị HUD nhỏ gần cursor với từ đoán tiếp theo (vd \"tiếp\" → \"theo\"). Nhấn ⇥ Tab để chấp nhận; phím khác → bỏ qua. Tính năng thử nghiệm — học từ thói quen gõ của bạn.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Đoán từ tiếp theo (thử nghiệm)")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(false)
        }
        .frame(width: 440, height: 560)
        .sheet(isPresented: $showingPersonalDictEditor) {
            PersonalDictionaryEditorView()
        }
        .sheet(isPresented: $showingSuggestionSheet) {
            PersonalDictSuggestionSheet()
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
            .frame(height: 240)
            
            Divider()
            
            HStack {
                Spacer()
                Button("Đóng") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 400, height: 420)
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
