//
//  VKControls.swift
//  vkey
//
//  Các control đặc thù: `VKAppearanceSegment` (Hệ thống / Sáng / Tối) và
//  `FlexibleShortcutRecorder` (ghi phím tắt chuẩn hoặc chỉ-modifier).
//

import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

// MARK: - Appearance Segment

struct VKAppearanceSegment: View {
  @Default(.appearanceMode) private var mode
  private let opts: [(mode: AppearanceMode, icon: String, label: String)] = [
    (.auto,  "circle.lefthalf.filled", "Hệ thống"),
    (.light, "sun.max.fill",           "Sáng"),
    (.dark,  "moon.fill",              "Tối"),
  ]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(opts, id: \.mode) { opt in
        let active = mode == opt.mode
        Button { mode = opt.mode } label: {
          Image(systemName: opt.icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(active ? Color.white : VK.Color.fgMuted)
            .frame(width: 26, height: 22)
            .background(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(active ? VK.Color.brand : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(opt.label)
      }
    }
  }
}

// MARK: - Flexible Shortcut Recorder

struct FlexibleShortcutRecorder: NSViewRepresentable {
  let name: KeyboardShortcuts.Name

  func makeNSView(context: Context) -> FlexibleShortcutButton {
    FlexibleShortcutButton(name: name)
  }

  func updateNSView(_ nsView: FlexibleShortcutButton, context: Context) {
    nsView.refresh()
  }
}

private func modifierOnlyKey(for name: KeyboardShortcuts.Name) -> Defaults.Key<Int> {
  .modifierOnlyToggleHotkey
}

final class FlexibleShortcutButton: NSButton {
  private let name: KeyboardShortcuts.Name
  private let modifierKey: Defaults.Key<Int>
  private var isRecording = false
  private var monitor: Any?
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
      return self.handle(event) ? nil : event
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

  private func handle(_ event: NSEvent) -> Bool {
    guard isRecording else { return false }

    let modifiers = event.modifierFlags
      .intersection(.deviceIndependentFlagsMask)
      .intersection([.command, .option, .control, .shift])
    let modifierRaw = Int(modifiers.rawValue)

    if event.type == .flagsChanged {
      if modifierRaw > pendingModifiers {
        pendingModifiers = modifierRaw
      } else if modifierRaw == 0 && pendingModifiers != 0 && !anyKeySeen {
        Defaults[modifierKey] = pendingModifiers
        KeyboardShortcuts.reset(name)
        stopRecording()
        return true
      }
      return true
    }

    anyKeySeen = true
    let keyCode = Int(event.keyCode)

    if keyCode == 53 && modifiers.isEmpty {
      stopRecording()
      return true
    }

    if (keyCode == 51 || keyCode == 117) && modifiers.isEmpty {
      KeyboardShortcuts.reset(name)
      Defaults[modifierKey] = 0
      stopRecording()
      return true
    }

    let key = KeyboardShortcuts.Key(rawValue: keyCode)
    let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    KeyboardShortcuts.setShortcut(shortcut, for: name)
    Defaults[modifierKey] = 0
    stopRecording()
    return true
  }
}
