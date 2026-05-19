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
      .intersection([.command, .option, .control, .shift, .function])
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
                    Label("Bật / Tắt gõ TV", systemImage: "keyboard")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                LaunchAtLogin.Toggle {
                    Label("Tự khởi động cùng hệ thống", systemImage: "arrow.up.right.square")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                Picker(selection: $appState.typingMethod) {
                    ForEach(TypingMethods.allCases, id: \.self) { method in
                        Text(method.rawValue)
                    }
                } label: {
                    Label("Kiểu gõ", systemImage: "abc")
                }
                .pickerStyle(.segmented)

                Toggle(isOn: $appState.allowedZWJF) {
                    Label("Phụ âm z, w, j, f", systemImage: "character")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                Toggle(isOn: $autoTypoCorrection) {
                    Label("Tự động sửa lỗi gõ nhầm", systemImage: "sparkles")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                
                Toggle(isOn: $hudEnabled) {
                    Label("Hiển thị thông báo khi chuyển VI/EN", systemImage: "macwindow.badge.plus")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    
                Picker(selection: $newStyleTonePlacement) {
                    Text("Kiểu cũ").tag(false)
                    Text("Kiểu mới").tag(true)
                } label: {
                    Label("Kiểu đặt dấu", systemImage: "textformat")
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
                    Label("Phím tắt", systemImage: "command")
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
    @Default(.dictionaryUpdateChannel) private var dictionaryUpdateChannel
    @Default(.dictionaryGitHubUpdateEnabled) private var dictionaryGitHubUpdateEnabled
    @Default(.suggestionEnabled) private var suggestionEnabled
    @Default(.autoApplyHighConfidenceSuggestion) private var autoApplyHighConfidenceSuggestion
    @Default(.personalDictionaryEnabled) private var personalDictionaryEnabled

    @State private var isUpdatingFromGitHub = false
    @State private var gitHubUpdateStatus = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(isOn: $spellCheckEnabled) {
                        Label("Kiểm tra chính tả", systemImage: "checkmark.circle")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    
                    if spellCheckEnabled {
                        Toggle(isOn: $spellCheckInSentenceEnabled) {
                            Label("Kiểm tra trong câu", systemImage: "text.justify.left")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        Picker(selection: $dictionaryUpdateChannel) {
                            Text("Chỉ từ điển nhúng").tag(DictionaryUpdateChannel.embeddedOnly)
                            Text("Từ điển nhúng + Cập nhật cục bộ").tag(DictionaryUpdateChannel.hybrid)
                        } label: {
                            Label("Nguồn từ điển", systemImage: "book")
                        }
                        .pickerStyle(.inline)
                    }
                } header: {
                    Text("Cấu hình Kiểm tra & Từ điển")
                }
                
                if spellCheckEnabled {
                    if dictionaryUpdateChannel == .hybrid {
                        Section {
                            Toggle(isOn: $dictionaryGitHubUpdateEnabled) {
                                Label("Tự động tải từ GitHub", systemImage: "arrow.down.circle")
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                            HStack {
                                Spacer()
                                Button(action: {
                                    isUpdatingFromGitHub = true
                                    gitHubUpdateStatus = "Đang tải dữ liệu từ GitHub..."
                                    LexiconManager.shared.downloadAndUpdateLexicon { success in
                                        DispatchQueue.main.async {
                                            isUpdatingFromGitHub = false
                                            if success {
                                                gitHubUpdateStatus = "Đã tải & cập nhật từ điển thành công!"
                                            } else {
                                                gitHubUpdateStatus = "Từ điển đã là phiên bản mới nhất hoặc có lỗi."
                                            }
                                        }
                                    }
                                }) {
                                    Label("Cập nhật từ điển ngay", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .disabled(isUpdatingFromGitHub)
                                Spacer()
                            }
                            
                            if !gitHubUpdateStatus.isEmpty {
                                Text(gitHubUpdateStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 2)
                            }
                        } header: {
                            Text("Cập nhật từ điển từ GitHub")
                        }
                    }

                    Section {
                        Toggle(isOn: $personalDictionaryEnabled) {
                            Label("Sử dụng từ điển cá nhân", systemImage: "person.circle")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        
                        Text("Áp dụng danh sách từ tự thêm (allow/keep/deny) do bạn cấu hình trong phần mềm.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, -4)
                    } header: {
                        Text("Từ điển cá nhân")
                    }

                    Section {
                        Toggle(isOn: $englishAutoRestoreEnabled) {
                            Label("Tự động khôi phục tiếng Anh", systemImage: "arrow.uturn.backward")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        
                        if englishAutoRestoreEnabled {
                            Picker(selection: $restorePolicy) {
                                Text("Ưu tiên tiếng Việt").tag(RestorePolicy.vietnameseFirst)
                                Text("Cân bằng").tag(RestorePolicy.balanced)
                                Text("Ưu tiên tiếng Anh").tag(RestorePolicy.englishFirst)
                            } label: {
                                Label("Chính sách khôi phục", systemImage: "slider.horizontal.3")
                            }
                            .pickerStyle(.segmented)
                            
                            Text("Lựa chọn cách xử lý đối với các từ mơ hồ giữa tiếng Việt và tiếng Anh (ví dụ: 'of', 'if', 'see', 'tee').")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, -4)
                        }
                    } header: {
                        Text("Tự động khôi phục tiếng Anh (Space Restore)")
                    }
                    
                    Section {
                        Toggle(isOn: $suggestionEnabled) {
                            Label("Gợi ý sửa lỗi chính tả", systemImage: "lightbulb")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        
                        if suggestionEnabled {
                            Toggle(isOn: $autoApplyHighConfidenceSuggestion) {
                                Label("Tự động sửa khi tin cậy cao", systemImage: "wand.and.stars")
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
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(false)
        }
        .frame(width: 440, height: 560)
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

