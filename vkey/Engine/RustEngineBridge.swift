//
//  RustEngineBridge.swift
//  vkey
//
//  2.0 (C2): Swift wrapper cho `vkey_core` Rust crate.
//
//  File này KHÔNG biên dịch được cho đến khi:
//  1. `rust-core/build.sh` đã chạy thành công (sinh ra `libvkey_core.a`).
//  2. Xcode project đã link `libvkey_core.a` + bridging header (xem
//     `rust-core/README.md`).
//
//  Trước khi tích hợp, để tránh build error khi build thông thường, toàn bộ
//  bridge wrap trong `#if VKEY_CORE_RUST` flag. Bật flag này trong
//  Build Settings → "Other Swift Flags" → thêm `-D VKEY_CORE_RUST` khi
//  rust-core đã sẵn sàng link.
//

#if VKEY_CORE_RUST

import Foundation

/// Wrapper an toàn quanh `vkey_core::State`. Tự free khi deinit.
/// Struct C export là `vkey_State` — Swift import như OpaquePointer.
final class RustState {
  private var ptr: OpaquePointer?

  init() {
    self.ptr = vkey_state_new()
  }

  deinit {
    if let ptr = ptr {
      vkey_state_free(ptr)
    }
  }

  func push(_ ch: Character) {
    guard let ptr = ptr,
          let ascii = ch.asciiValue
    else { return }
    _ = vkey_state_push(ptr, Int8(bitPattern: ascii))
  }

  var raw: String {
    guard let ptr = ptr else { return "" }
    // Try with a 256-byte buffer first; if needs more, resize.
    var bufSize: Int32 = 256
    var buffer = [Int8](repeating: 0, count: Int(bufSize))
    let written = vkey_state_raw(ptr, &buffer, bufSize)
    if written < 0 { return "" }
    if written > bufSize {
      bufSize = written + 1
      buffer = [Int8](repeating: 0, count: Int(bufSize))
      _ = vkey_state_raw(ptr, &buffer, bufSize)
    }
    return String(cString: buffer)
  }

  var needsRecovery: Bool {
    guard let ptr = ptr else { return false }
    return vkey_state_needs_recovery(ptr) == 1
  }
}

/// ABI version từ Rust core (major << 16 | minor << 8 | patch).
enum RustCore {
  static var version: UInt32 {
    return vkey_core_version()
  }

  static var versionString: String {
    let v = version
    return "\((v >> 16) & 0xFF).\((v >> 8) & 0xFF).\(v & 0xFF)"
  }
}

#endif
