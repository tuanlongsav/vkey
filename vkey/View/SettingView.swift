import AppKit
import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI
import UniformTypeIdentifiers

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

/// v2.3.1: mapping `KeyboardShortcuts.Name` → modifier-only Defaults key.
/// Trước 2.3.1 hardcode `.modifierOnlyToggleHotkey` cho cả Toggle VI/EN
/// lẫn Text Tools → 2 button hiển thị cùng 1 mask (bug). Sau khi parameterize,
/// mỗi recorder đọc/ghi vào đúng key của nó.
private func modifierOnlyKey(for name: KeyboardShortcuts.Name) -> Defaults.Key<Int> {
  switch name {
  case .openTextConversionMenu: return .modifierOnlyTextToolsHotkey
  default:                      return .modifierOnlyToggleHotkey
  }
}

final class FlexibleShortcutButton: NSButton {
  private let name: KeyboardShortcuts.Name
  private let modifierKey: Defaults.Key<Int>
  private var isRecording = false
  private var monitor: Any?

  // Tracks the highest modifier set seen during recording so we can detect
  // "modifier-only" intent: user pressed e.g. Shift+Control, then released
  // everything without pressing a letter key.
  private var pendingModifiers: Int = 0
  private var anyKeySeen = false

  init(name: KeyboardShortcuts.Name) {
    self.name = name
    self.modifierKey = modifierOnlyKey(for: name)
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

    let modifierOnly = Defaults[modifierKey]
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
        Defaults[modifierKey] = pendingModifiers
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
      Defaults[modifierKey] = 0
      stopRecording()
      return true
    }

    // Standard key+modifier shortcut. Clear any modifier-only override so
    // only one hotkey kind is active at a time.
    let key = KeyboardShortcuts.Key(rawValue: keyCode)
    let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    KeyboardShortcuts.setShortcut(shortcut, for: name)
    Defaults[modifierKey] = 0
    stopRecording()
    return true
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
                Button(action: importWords) {
                    Label("Nhập file", themedSymbol: "square.and.arrow.down")
                }
                Button(action: exportWords) {
                    Label("Xuất file", themedSymbol: "square.and.arrow.up")
                }
                
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
    
    private func importWords() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Ưu tiên UTF-8; file lưu bằng encoding khác (UTF-16, Windows…) thì
        // để Foundation tự dò thay vì fail im lặng.
        var content: String
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            content = utf8
        } else {
            var detected = String.Encoding.utf8
            guard let fallback = try? String(contentsOf: url, usedEncoding: &detected) else {
                showDictionaryAlert(
                    title: "Không đọc được file",
                    message: "File không phải dạng văn bản hoặc dùng bảng mã không hỗ trợ.")
                return
            }
            content = fallback
        }

        // File .txt: mỗi dòng 1 từ. File .csv: thêm dấu phẩy làm ngăn cách.
        let separators = CharacterSet.newlines.union(CharacterSet(charactersIn: ","))
        let entries = content.components(separatedBy: separators)

        var targetList: [String]
        switch selectedTab {
        case 0: targetList = userAllowWords
        case 1: targetList = userKeepWords
        case 2: targetList = userDenyWords
        default: return
        }

        var addedCount = 0
        for entry in entries {
            let word = entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !word.isEmpty && !targetList.contains(word) {
                targetList.append(word)
                addedCount += 1
            }
        }

        if addedCount > 0 {
            switch selectedTab {
            case 0: userAllowWords = targetList
            case 1: userKeepWords = targetList
            case 2: userDenyWords = targetList
            default: break
            }
        }
        showDictionaryAlert(
            title: "Nhập từ điển",
            message: addedCount > 0
                ? "Đã thêm \(addedCount) từ mới vào danh sách."
                : "Không có từ mới nào (toàn bộ đã có sẵn hoặc file trống).",
            style: .informational)
    }

    private func exportWords() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "vkey_dictionary_export.txt"

        if panel.runModal() == .OK, let url = panel.url {
            let wordsList = currentWordsList()
            let content = wordsList.joined(separator: "\n")
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showDictionaryAlert(
                    title: "Không xuất được file",
                    message: error.localizedDescription)
            }
        }
    }

    private func showDictionaryAlert(
        title: String, message: String, style: NSAlert.Style = .warning
    ) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
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
