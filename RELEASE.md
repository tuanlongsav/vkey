# Build Guide for vkey

This fork is configured for personal/local builds. It does not include
auto-update support.

## Local Debug Build

Install the full Xcode app first, then build with:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project vkey.xcodeproj -scheme vkey -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/vkey-derived \
  clean build
```

If Xcode requires a signing team, open `vkey.xcodeproj`, choose your Apple ID
team under Signing & Capabilities, then run the build again.

## Install For Testing

```bash
ditto /tmp/vkey-derived/Build/Products/Debug/vkey.app /Applications/vkey.app
open /Applications/vkey.app
```

If `/Applications` is not writable, install temporarily to `~/Applications`.

## Manual Release Build

Only use this when you want to create a manually distributed app build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project vkey.xcodeproj -scheme vkey -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/vkey-derived \
  clean build
```

Then package the app yourself, for example with `create-dmg` or `hdiutil`.
Developer ID distribution and notarization are not configured in this personal
fork yet.
