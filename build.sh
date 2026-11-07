#!/bin/bash
# 编译通用版（Apple 芯片 + Intel），打包成 build/DiskMonitor.app
# 最低系统：Intel 版 macOS 10.15，Apple 芯片版 macOS 11
set -euo pipefail
cd "$(dirname "$0")"

python3 -I tools/gen_strings.py

ARM_TRIPLE=arm64-apple-macosx11.0
X86_TRIPLE=x86_64-apple-macosx10.15
# 两种芯片各用独立的缓存目录，避免增量编译时互相干扰
swift build -c release --triple "$ARM_TRIPLE" --scratch-path .build/arm64
swift build -c release --triple "$X86_TRIPLE" --scratch-path .build/x86_64
ARM_BIN="$(swift build -c release --triple "$ARM_TRIPLE" --scratch-path .build/arm64 --show-bin-path)/DiskMonitor"
X86_BIN="$(swift build -c release --triple "$X86_TRIPLE" --scratch-path .build/x86_64 --show-bin-path)/DiskMonitor"

APP="build/DiskMonitor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/DiskMonitor"
cp Info.plist "$APP/Contents/Info.plist"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

# 内置 smartctl（GPL-2，附许可证和源码说明）
cp Vendor/smartmontools/smartctl "$APP/Contents/MacOS/smartctl"
mkdir -p "$APP/Contents/Resources/Licenses/smartmontools"
cp Vendor/smartmontools/COPYING "$APP/Contents/Resources/Licenses/smartmontools/COPYING.txt"
cp Vendor/smartmontools/README.txt "$APP/Contents/Resources/Licenses/smartmontools/README.txt"

# 先签内层的 smartctl，再签整个应用
codesign --force --sign - "$APP/Contents/MacOS/smartctl"
codesign --force --sign - "$APP"

echo "已生成：$(pwd)/$APP"
