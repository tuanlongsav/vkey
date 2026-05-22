# vkey_core (Rust)

**2.0 (C2):** Pure Vietnamese typing engine, ported từ Swift `Engine/` sang Rust + C-ABI FFI.

## Trạng thái

| Phase | Module                                  | Status  |
|-------|-----------------------------------------|---------|
| 1     | State + Parser data types               | ✅ Done |
| 2     | Validator (`TiengVietValidator`)        | ⏳ Todo |
| 3     | Transformer + Telex/VNI                 | ⏳ Todo |
| 4     | Hợp nhất + retire Swift engine          | ⏳ Todo |

Mỗi sub-phase chạy parallel với engine Swift trong test mode để đảm bảo byte-for-byte zero-regression trước khi retire Swift.

## Build

```bash
./build.sh
```

Output:
- `target/universal/libvkey_core.a` — universal static lib (arm64 + x86_64)
- `include/vkey_core.h` — C header

## Tích hợp vào Xcode project

1. Mở `vkey.xcodeproj` trong Xcode.
2. Build Phases → Link Binary With Libraries → "+" → "Add Other..." → chọn `rust-core/target/universal/libvkey_core.a`.
3. Build Phases → New Run Script Phase (đặt TRƯỚC Compile Sources) với content:
   ```bash
   "${PROJECT_DIR}/rust-core/build.sh"
   ```
4. Build Settings → Search Paths → Header Search Paths → thêm `${PROJECT_DIR}/rust-core/include`.
5. Build Settings → Objective-C Bridging Header → tạo file mới `vkey/vkey-Bridging-Header.h` với nội dung:
   ```objc
   #import "vkey_core.h"
   ```

Swift sẽ tự thấy các function `vkey_state_new`, `vkey_state_push`, v.v. nhờ bridging header.

## API surface

Xem `src/lib.rs` cho list đầy đủ. Tóm tắt:

```c
// State lifecycle
struct State* vkey_state_new(void);
void vkey_state_free(struct State* state);

// Mutations
int vkey_state_push(struct State* state, char ch);

// Queries
int vkey_state_raw(const struct State* state, char* buffer, int capacity);
int vkey_state_needs_recovery(const struct State* state);

// ABI version
uint32_t vkey_core_version(void);
```

## Wrapper Swift

File `vkey/Engine/RustEngineBridge.swift` cung cấp wrapper an toàn cho Swift code call vào Rust. Hiện tại bridge wrap quanh `State`; sau Phase 4 sẽ thay thế hoàn toàn `TiengViet*.swift`.

## Test parity với Swift engine

Trong `vkeyTests/`, mỗi sub-phase sẽ thêm test pair: chạy cùng 1 input qua Swift engine + Rust engine, assert output identical. Khi pair 100% pass → sub-phase merge được vào release.
