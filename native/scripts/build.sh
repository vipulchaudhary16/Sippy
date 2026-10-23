#!/bin/bash
# Builds Sippy.app (and Sippy.dmg) using only the Xcode Command Line Tools.
#   scripts/build.sh            -> dist/Sippy.app + dist/Sippy.dmg
#   scripts/build.sh --install  -> also copies the app to /Applications and launches it
# Env: VERSION=1.2.0 sets the app version; UNIVERSAL=1 builds for Apple silicon + Intel
#      (needs full Xcode, as on GitHub's macOS runners).
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.2.0}"
DIST="dist"
APP="$DIST/Sippy.app"
ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "▸ Checking core logic"
swift run -c release SippyChecks

echo "▸ Building release binary"
swift build -c release --product Sippy ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Sippy"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Sippy"

ICONSET="$(mktemp -d)/Sippy.iconset"
swift scripts/make_icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Sippy.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Sippy</string>
    <key>CFBundleDisplayName</key><string>Sippy</string>
    <key>CFBundleIdentifier</key><string>com.vipulchaudhary.sippy</string>
    <key>CFBundleExecutable</key><string>Sippy</string>
    <key>CFBundleIconFile</key><string>Sippy</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.healthcare-fitness</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>com.vipulchaudhary.sippy</string>
            <key>CFBundleURLSchemes</key><array><string>sippy</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "▸ Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "▸ Making Sippy.zip"
rm -f "$DIST/Sippy.zip"
ditto -c -k --keepParent "$APP" "$DIST/Sippy.zip"

echo "▸ Making Sippy.dmg"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DIST/Sippy.dmg"
hdiutil create -quiet -volname "Sippy" -srcfolder "$STAGE" -ov -format UDZO "$DIST/Sippy.dmg"

if [[ "${1:-}" == "--install" ]]; then
    echo "▸ Installing to /Applications"
    pkill -x Sippy 2>/dev/null || true
    rm -rf /Applications/Sippy.app
    cp -R "$APP" /Applications/
    open /Applications/Sippy.app
fi

lipo -archs "$APP/Contents/MacOS/Sippy" | sed 's/^/▸ Architectures: /'
echo "✓ Done: $APP, $DIST/Sippy.zip and $DIST/Sippy.dmg (v$VERSION)"
