#!/bin/bash
# 从官方源码重新编译通用版 smartctl（Apple 芯片 + Intel），输出到 Vendor/smartmontools/
# 平时不用运行；只有升级 smartmontools 版本时才需要。
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=7.5
SHA256=690b83ca331378da9ea0d9d61008c4b22dde391387b9bbad7f29387f2595f76e
URL="https://github.com/smartmontools/smartmontools/releases/download/RELEASE_${VERSION//./_}/smartmontools-$VERSION.tar.gz"
OUT="Vendor/smartmontools"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL -o "$WORK/src.tar.gz" "$URL"
echo "$SHA256  $WORK/src.tar.gz" | shasum -a 256 -c -
tar -xzf "$WORK/src.tar.gz" -C "$WORK"
SRC="$WORK/smartmontools-$VERSION"

for ARCH in arm64 x86_64; do
    if [ "$ARCH" = arm64 ]; then MIN=11.0; HOST=aarch64-apple-darwin; else MIN=10.15; HOST=x86_64-apple-darwin; fi
    mkdir -p "$WORK/build-$ARCH"
    (cd "$WORK/build-$ARCH" && "$SRC/configure" --host=$HOST \
        CC="clang -arch $ARCH" CXX="clang++ -arch $ARCH" \
        CFLAGS="-O2 -mmacosx-version-min=$MIN" CXXFLAGS="-O2 -mmacosx-version-min=$MIN" \
        LDFLAGS="-mmacosx-version-min=$MIN" \
        --without-update-smart-drivedb --disable-dependency-tracking >/dev/null && make -j8 smartctl >/dev/null)
done

mkdir -p "$OUT"
lipo -create "$WORK/build-arm64/smartctl" "$WORK/build-x86_64/smartctl" -output "$OUT/smartctl"
cp "$SRC/COPYING" "$OUT/COPYING"
lipo -info "$OUT/smartctl"
