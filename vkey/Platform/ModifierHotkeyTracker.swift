//
//  ModifierHotkeyTracker.swift
//  vkey
//
//  Máy trạng thái phát hiện phím tắt chỉ-modifier (mặc định ⇧⌥) trong event tap.
//

import AppKit
import CoreGraphics
import Foundation

struct ModifierHotkeyTracker {
  /// Bit mask các modifier được theo dõi (khớp cả `CGEventFlags` và `NSEvent.ModifierFlags`).
  static let trackedModifierMask: UInt64 =
    UInt64(NSEvent.ModifierFlags.command.rawValue) |
    UInt64(NSEvent.ModifierFlags.option.rawValue) |
    UInt64(NSEvent.ModifierFlags.control.rawValue) |
    UInt64(NSEvent.ModifierFlags.shift.rawValue)

  var armedMask: UInt64 = 0
  var keyUsedDuringArm = false

  mutating func reset() {
    armedMask = 0
    keyUsedDuringArm = false
  }

  /// Armed khi `currentMods == modifierTarget`, huỷ nếu có phím/click xen giữa
  /// hoặc thêm modifier lạ, bắn khi thả sạch (`currentMods == 0`).
  @discardableResult
  mutating func handle(
    type: CGEventType,
    currentMods: UInt64,
    modifierTarget: UInt64
  ) -> Bool {
    guard modifierTarget != 0 else { return false }

    if type == .flagsChanged {
      if armedMask == 0 {
        if currentMods == modifierTarget {
          armedMask = modifierTarget
          keyUsedDuringArm = false
        }
        return false
      }

      let hasExtraModifier = (currentMods & ~armedMask) != 0
      if hasExtraModifier {
        reset()
        return false
      }

      if currentMods == 0 {
        let fire = !keyUsedDuringArm && armedMask == modifierTarget
        reset()
        return fire
      }

      return false
    }

    let usesHeldModifiers =
      type == .keyDown || type == .leftMouseDown || type == .rightMouseDown
    if usesHeldModifiers && armedMask != 0 {
      keyUsedDuringArm = true
    }

    return false
  }
}
