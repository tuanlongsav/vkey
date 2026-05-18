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
    @Environment(AppState.self) var appState
    @Default(.smartSwitchEnabled) private var smartSwitchEnabled

    let appVersion = Bundle.main.appVersionLong

    var body: some View {
        @Bindable var appState = appState
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
                Toggle("Bật / Tắt gõ TV", isOn: $appState.enabled)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                LaunchAtLogin.Toggle("Mở lúc bật Mac")
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                Picker("Kiểu gõ", selection: $appState.typingMethod) {
                    ForEach(TypingMethods.allCases, id: \.self) { method in
                        Text(method.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Phụ âm z, w, j, f", isOn: $appState.allowedZWJF)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                Toggle("Tự tắt khi mở Spotlight / Raycast", isOn: $smartSwitchEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                LabeledContent("Phím tắt") {
                    FlexibleShortcutRecorder(name: .toggleInputMode)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Text(
                "Version \(appVersion)\nKhông có tính năng gì ngoài gõ Tiếng Việt!\nTuỳ biến bởi longht, dựa trên dự án mã nguồn mở của KhanhIceTea."
            )
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .italic()
            .padding(.top, 8)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 440, height: 540)
    }
}

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView()
            .environment(AppState())
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
            .previewDisplayName("GeneralView preview")
    }
}
