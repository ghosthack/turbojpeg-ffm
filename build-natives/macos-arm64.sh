#!/bin/sh
# Build libjpeg-turbo (shared, TurboJPEG API only) for macos-arm64 and stage
# the dylib into natives/src/main/resources/turbojpeg-natives/macos-arm64/.
#
# Usage: build-natives/macos-arm64.sh [path-to-libjpeg-turbo-source]   (default build/libjpeg-turbo-3.2.0)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/libjpeg-turbo-3.2.0}"
PREFIX="$ROOT/build/prefix-macos-arm64"
DEST="$ROOT/natives/src/main/resources/turbojpeg-natives/macos-arm64"
BUILD="$SRC/build-macos-arm64"

cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED=1 -DENABLE_STATIC=0 \
  -DWITH_TURBOJPEG=1 \
  -DCMAKE_INSTALL_NAME_DIR='@loader_path'
ninja -C "$BUILD" install

rm -rf "$DEST"
mkdir -p "$DEST"

# Only the TurboJPEG API library ships (it embeds the whole codec); the
# classic libjpeg.dylib is not needed by the bindings.
dylib="$PREFIX/lib/libturbojpeg.dylib"
install_name="$(otool -D "$dylib" | tail -1)"
base="$(basename "$install_name")"          # e.g. libturbojpeg.0.4.0.dylib
cp "$(cd "$PREFIX/lib" && readlink -f libturbojpeg.dylib)" "$DEST/$base"
chmod 644 "$DEST/$base"
printf '%s\n' "$base" > "$DEST/manifest.txt"

cp "$SRC/LICENSE.md" "$DEST/LICENSE.md"
{
  echo "libjpeg-turbo $(cat "$SRC/CMakeLists.txt" | sed -n 's/^set(VERSION \(.*\))$/\1/p' | head -1)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(uname -sm)"
  echo "source: https://github.com/libjpeg-turbo/libjpeg-turbo (unmodified)"
  echo "cmake flags: Release, ENABLE_SHARED=1, WITH_TURBOJPEG=1"
} > "$DEST/BUILD-INFO.txt"

echo "staged:"
ls -la "$DEST"
