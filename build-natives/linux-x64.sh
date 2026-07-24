#!/bin/sh
# Build libjpeg-turbo (shared, TurboJPEG API only) for linux-x64 and stage
# the .so into natives/src/main/resources/turbojpeg-natives/linux-x64/.
#
# Run on an x86-64 Linux machine (gcc, cmake, ninja, nasm, patchelf):
#   build-natives/linux-x64.sh [path-to-libjpeg-turbo-source]   (default build/libjpeg-turbo-3.2.0)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/libjpeg-turbo-3.2.0}"
PREFIX="$ROOT/build/prefix-linux-x64"
DEST="$ROOT/natives/src/main/resources/turbojpeg-natives/linux-x64"
BUILD="$SRC/build-linux-x64"

cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED=1 -DENABLE_STATIC=0 \
  -DWITH_TURBOJPEG=1
ninja -C "$BUILD" install

rm -rf "$DEST"
mkdir -p "$DEST"

# Only the TurboJPEG API library ships (it embeds the whole codec); staged
# under its soname, the Linux analog of the macOS install-name basename.
so="$(readlink -f "$PREFIX/lib/libturbojpeg.so")"
base="$(patchelf --print-soname "$so")"        # e.g. libturbojpeg.so.0
cp "$so" "$DEST/$base"
chmod 644 "$DEST/$base"
# $ORIGIN keeps the lib self-contained wherever the loader extracts it.
patchelf --set-rpath '$ORIGIN' "$DEST/$base"
printf '%s\n' "$base" > "$DEST/manifest.txt"

# No dependency outside glibc may survive.
if readelf -d "$DEST/$base" | awk '/NEEDED/ {print $NF}' | tr -d '[]' \
    | grep -vE '^(libc|libm|libpthread|libdl|librt)\.so|^ld-linux'; then
  echo "ERROR: $base links non-glibc libraries (above)"; exit 1
fi

cp "$SRC/LICENSE.md" "$DEST/LICENSE.md"
{
  echo "libjpeg-turbo $(cat "$SRC/CMakeLists.txt" | sed -n 's/^set(VERSION \(.*\))$/\1/p' | head -1)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(uname -sm)"
  echo "source: https://github.com/libjpeg-turbo/libjpeg-turbo (unmodified)"
  echo "cmake flags: Release, ENABLE_SHARED=1, WITH_TURBOJPEG=1"
} > "$DEST/BUILD-INFO.txt"

echo "staged:"
ls -la "$DEST"
