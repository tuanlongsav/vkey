#!/usr/bin/env bash
#
# vkey-core build script. Compile cho cả x86_64 + arm64, lipo thành 1 universal
# static library + generate C header. Output: target/universal/libvkey_core.a
# + include/vkey_core.h
#
# Yêu cầu: Xcode CLT + Rust (rustup), cargo subcommand cbindgen.
#

set -euo pipefail
cd "$(dirname "$0")"

echo "→ Adding macOS targets if missing..."
rustup target add aarch64-apple-darwin x86_64-apple-darwin

echo "→ Building x86_64..."
cargo build --release --target x86_64-apple-darwin

echo "→ Building arm64..."
cargo build --release --target aarch64-apple-darwin

echo "→ Lipo into universal binary..."
mkdir -p target/universal
lipo -create \
  target/x86_64-apple-darwin/release/libvkey_core.a \
  target/aarch64-apple-darwin/release/libvkey_core.a \
  -output target/universal/libvkey_core.a

echo "→ Generating C header..."
mkdir -p include
cargo install cbindgen --version "^0.27" --locked --quiet 2>/dev/null || true
cbindgen --config cbindgen.toml --crate vkey_core --output include/vkey_core.h

echo "✓ Done. Outputs:"
echo "    $(pwd)/target/universal/libvkey_core.a"
echo "    $(pwd)/include/vkey_core.h"
