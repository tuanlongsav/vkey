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
    @Default(.wordPredictionEnabled) private var wordPredictionEnabled

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

                // 1.6.1: Đoán từ tiếp theo — chuyển từ tab Chính tả sang đây.
                Toggle(isOn: $wordPredictionEnabled) {
                    Label("Đoán từ tiếp theo", themedSymbol: "wand.and.stars")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                if wordPredictionEnabled {
                    Text("Sau khi gõ xong 1 từ + dấu cách, vkey hiển thị HUD nhỏ cạnh cursor với từ đoán tiếp theo (vd \"tiếp\" → \"theo\"). Nhấn ⇥ Tab để chấp nhận; phím khác → bỏ qua. Ưu tiên gợi ý từ trong từ điển gốc + từ điển cá nhân.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, -8)
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
        .frame(minWidth: 320, minHeight: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    @State private var showingPersonalDictEditor = false
    @State private var showingSuggestionSheet = false

    // 1.6.2+: state cho nút "Cập nhật từ điển ngay".
    @State private var isCheckingDictUpdate = false
    @State private var dictUpdateStatus = ""
    @State private var lexiconVnVersion: Int = 0
    @State private var lexiconVnEntries: Int = 0

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

                        Button(action: { showingPersonalDictEditor = true }) {
                            Label("Quản lý từ điển cá nhân", themedSymbol: "pencil.and.outline")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

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
                        HStack {
                            Text("Phiên bản từ điển:")
                                .font(.caption)
                            Text("v\(lexiconVnVersion)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(lexiconVnEntries) từ tiếng Việt")
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

                    // v1.7.0: Section "Học hành vi từ Thống kê" đã được merge
                    // vào Section "Cấu hình kiểm tra chính tả" ở trên.

                    // 1.6.1: Section "Đoán từ tiếp theo" đã chuyển sang
                    // tab Chung — feature global, không trực thuộc spell check.
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(false)
        }
        .frame(minWidth: 320, minHeight: 480)
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

            // v1.7.2: Gửi từ điển cho tác giả
            VStack(alignment: .leading, spacing: 4) {
                let totalCount = userAllowWords.count + userKeepWords.count + userDenyWords.count
                let canSend = totalCount >= 50

                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(canSend ? Color.accentColor : Color.secondary)
                    Text("Gửi từ điển cho tác giả vkey")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }

                Text("Yêu cầu ≥50 từ trong tổng 3 danh sách (Allow/Keep/Deny). Bạn có \(totalCount) từ.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Khi gửi, vkey mở app mail mặc định. Tác giả rà soát và bổ sung vào từ điển chung nếu phù hợp.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Button(action: sendDictToAuthor) {
                    Label(canSend ? "Gửi cho tuanlong.sav@gmail.com" : "Cần thêm \(max(0, 50 - totalCount)) từ",
                          themedSymbol: "paperplane")
                }
                .disabled(!canSend)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

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

    // v1.7.2: send dict to author via mailto.
    private func sendDictToAuthor() {
        let allowJoined = userAllowWords.joined(separator: ", ")
        let keepJoined = userKeepWords.joined(separator: ", ")
        let denyJoined = userDenyWords.joined(separator: ", ")

        let body = """
        Chào tác giả vkey,

        Tôi xin gửi từ điển cá nhân để bạn rà soát và bổ sung vào từ điển chung nếu phù hợp.

        --- Allow (\(userAllowWords.count) từ) ---
        \(allowJoined)

        --- Keep (\(userKeepWords.count) từ) ---
        \(keepJoined)

        --- Deny (\(userDenyWords.count) từ) ---
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
