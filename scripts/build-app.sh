#!/bin/bash
# Builds a release DiskLens.app into dist/ and ad-hoc signs it.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/dist/DiskLens.app"
VERSION="0.2.0"

echo "==> Building release binary"
swift build -c release --product DiskLens --arch arm64 --arch x86_64
BIN="$(swift build -c release --product DiskLens --arch arm64 --arch x86_64 --show-bin-path)/DiskLens"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DiskLens"

ICON_KEY=""
if command -v iconutil >/dev/null; then
    ICONSET="$(mktemp -d)/DiskLens.iconset"
    if swift "$ROOT/scripts/make-icon.swift" "$ICONSET" && iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/DiskLens.icns"; then
        ICON_KEY="<key>CFBundleIconFile</key><string>DiskLens</string>"
    else
        echo "warning: icon generation failed, continuing without an icon" >&2
    fi
    rm -rf "$(dirname "$ICONSET")"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>tw.ncse.disklens</string>
    <key>CFBundleName</key><string>DiskLens</string>
    <key>CFBundleDisplayName</key><string>DiskLens</string>
    <key>CFBundleExecutable</key><string>DiskLens</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleDevelopmentRegion</key><string>zh-Hant</string>
    <key>CFBundleLocalizations</key><array><string>zh-Hant</string></array>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    $ICON_KEY
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> Signing (ad-hoc)"
codesign --force --deep -s - "$APP"
codesign --verify --verbose=1 "$APP"

echo "==> Done: $APP"
