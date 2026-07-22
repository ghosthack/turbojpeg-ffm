#!/bin/sh
# Build libjpeg-turbo (shared, TurboJPEG API only) for windows-x64 and stage
# the DLL into natives/src/main/resources/turbojpeg-natives/windows-x64/.
#
# Run from an MSYS2 **MINGW64** shell on the Windows machine:
#   pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake \
#     mingw-w64-x86_64-ninja nasm
#   build-natives/windows-x64.sh [path-to-libjpeg-turbo-source]   (default build/libjpeg-turbo-3.2.0)
#
# Fetch the source first if needed:
#   mkdir -p build && curl -sfL https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0.tar.gz | tar xz -C build
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/libjpeg-turbo-3.2.0}"
PREFIX="$ROOT/build/prefix-windows-x64"
DEST="$ROOT/natives/src/main/resources/turbojpeg-natives/windows-x64"
BUILD="$SRC/build-windows-x64"

cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED=1 -DENABLE_STATIC=0 \
  -DWITH_TURBOJPEG=1
ninja -C "$BUILD" install

rm -rf "$DEST"
mkdir -p "$DEST"

: > "$DEST/manifest.txt"
# mingw runtime DLLs first, if the turbojpeg DLL links them (plain C, usually
# only libgcc; checked by the import gate below either way).
for runtime in libwinpthread-1.dll libgcc_s_seh-1.dll; do
  if [ -f "/mingw64/bin/$runtime" ] \
     && objdump -p "$PREFIX/bin/libturbojpeg.dll" | grep -q "DLL Name: $runtime"; then
    cp "/mingw64/bin/$runtime" "$DEST/$runtime"
    echo "$runtime" >> "$DEST/manifest.txt"
  fi
done

cp "$PREFIX/bin/libturbojpeg.dll" "$DEST/libturbojpeg.dll"
echo "libturbojpeg.dll" >> "$DEST/manifest.txt"

# No import may resolve outside: staged runtime or Windows itself.
ALLOWED='libturbojpeg|libwinpthread|libgcc_s_seh|KERNEL32|USER32|ADVAPI32|msvcrt|ntdll|api-ms-'
for f in "$DEST"/*.dll; do
  if objdump -p "$f" | awk '/DLL Name:/{print $3}' | grep -viE "^($ALLOWED)"; then
    echo "ERROR: $f imports from unexpected DLLs (above)"; exit 1
  fi
done

cp "$SRC/LICENSE.md" "$DEST/LICENSE.md"
{
  echo "libjpeg-turbo 3.2.0 (windows-x64), built from unmodified source with MSYS2 mingw-w64"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "source: https://github.com/libjpeg-turbo/libjpeg-turbo (unmodified)"
  echo "cmake flags: Release, ENABLE_SHARED=1, WITH_TURBOJPEG=1"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l) files into $DEST"
