#!/bin/bash
# Packages dist/DiskLens.app into dist/DiskLens-<version>.dmg with an Applications link and install notes.
# Usage: ./scripts/build-app.sh && ./scripts/make-dmg.sh
# The DMG is ad-hoc signed unless the app was signed with a Developer ID and notarized beforehand.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="dist/DiskLens.app"
[ -d "$APP" ] || { echo "error: $APP not found, run scripts/build-app.sh first" >&2; exit 1; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="dist/DiskLens-$VERSION.dmg"
STAGE="$(mktemp -d)/DiskLens"
mkdir -p "$STAGE"

ditto "$APP" "$STAGE/DiskLens.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/README.txt" <<'EOF'
DiskLens — https://github.com/PGpenguin72/DiskLens

Requirements: macOS 26 or later, Apple Silicon or Intel.
系統需求：macOS 26 以上，Apple Silicon 或 Intel。

Install: drag DiskLens into Applications.
安裝：把 DiskLens 拖進「應用程式」。

If macOS says the app can't be verified (builds that aren't notarized):
open System Settings › Privacy & Security, scroll down and click "Open Anyway".
如果 macOS 說無法驗證開發者（尚未公證的版本）：
打開「系統設定 › 隱私權與安全性」，往下捲，按「強制打開」。

For complete results, enable System Settings › Privacy & Security › Full Disk Access for DiskLens.
想看到完整結果，請在「系統設定 › 隱私權與安全性 › 完整磁碟取用權限」開啟 DiskLens。
EOF

rm -f "$DMG"
hdiutil create -volname "DiskLens $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
rm -rf "$(dirname "$STAGE")"
echo "==> $DMG ($(du -h "$DMG" | cut -f1))"
