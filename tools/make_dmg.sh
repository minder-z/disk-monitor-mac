#!/bin/bash
# 编译应用并打包成发布用的 DMG：build/DiskMonitor-<版本>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

./build.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/DiskMonitor.app/Contents/Info.plist)"
DMG="build/DiskMonitor-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

ditto build/DiskMonitor.app "$STAGE/DiskMonitor.app"
ln -s /Applications "$STAGE/Applications"
cp "dist/How to open - 首次打开说明.txt" "$STAGE/"

rm -f "$DMG"
# HFS+ 格式，兼容 macOS 10.15
hdiutil create -volname "Disk Monitor $VERSION" -srcfolder "$STAGE" \
    -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null

shasum -a 256 "$DMG"
echo "已生成：$(pwd)/$DMG"
