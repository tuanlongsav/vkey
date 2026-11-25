//
//  ModifierFormatting.swift
//  vkey
//
//  Định dạng bitmask modifier thành chuỗi ký hiệu chuẩn macOS (⌃⌥⇧⌘).
//  Đặt tại KeyLayout để Platform (HUD) không phụ thuộc ngược vào tầng View.
//

import AppKit
import Foundation

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
