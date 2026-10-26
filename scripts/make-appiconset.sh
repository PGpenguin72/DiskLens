#!/bin/bash
# Renders the app icon into Packaging/Assets.xcassets/AppIcon.appiconset for the Xcode build.
set -euo pipefail
cd "$(dirname "$0")/.."
SET="Packaging/Assets.xcassets/AppIcon.appiconset"
rm -rf "$SET"
mkdir -p "$SET"
swift scripts/make-icon.swift "$SET"
cat > Packaging/Assets.xcassets/Contents.json <<'JSON'
{ "info" : { "author" : "xcode", "version" : 1 } }
JSON
{
    echo '{ "images" : ['
    first=1
    for size in 16 32 128 256 512; do
        for scale in 1 2; do
            suffix=""
            if [ "$scale" = 2 ]; then suffix="@2x"; fi
            name="icon_${size}x${size}${suffix}.png"
            [ -f "$SET/$name" ] || { echo "missing $name" >&2; exit 1; }
            [ $first = 1 ] || echo ','
            first=0
            printf '  { "filename" : "%s", "idiom" : "mac", "scale" : "%sx", "size" : "%sx%s" }' "$name" "$scale" "$size" "$size"
        done
    done
    echo ''
    echo '], "info" : { "author" : "xcode", "version" : 1 } }'
} > "$SET/Contents.json"
echo "==> $SET"
