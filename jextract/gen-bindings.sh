#!/bin/sh
# Generate the TurboJPEG 3 FFM stubs from the headers of the from-source build,
# then re-point the generated SYMBOL_LOOKUP at the runtime loader (TurboJpegLibs).
#
# Run once, on macOS, after build-natives/macos-arm64.sh. The TurboJPEG API is
# platform-portable (plain ints, size_t, and one two-int struct), so a single
# generation serves every platform.
#
# Prereq: a jextract-22 install; default taken from the sibling ffmpeg-ffm repo.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JX="${JEXTRACT:-$ROOT/../ffmpeg-ffm/tools/jextract-22/bin/jextract}"
PREFIX="$ROOT/build/prefix-macos-arm64"
OUT="$ROOT/core/src/main/java"
PKG="io.github.ghosthack.turbojpegffm.turbojpeg"
SDK=$(xcrun --show-sdk-path)

[ -x "$JX" ] || { echo "jextract not found at $JX (set JEXTRACT=)"; exit 1; }
[ -d "$PREFIX/include" ] || { echo "run build-natives/macos-arm64.sh first"; exit 1; }

GEN_DIR="$OUT/$(echo "$PKG" | tr . /)"
rm -rf "$GEN_DIR"

# The -l path only seeds the generated SYMBOL_LOOKUP, which is replaced below —
# the loader owns library resolution at runtime.
"$JX" --output "$OUT" -t "$PKG" \
  --header-class-name TurboJpeg \
  -I "$SDK/usr/include" \
  -I "$PREFIX/include" \
  -l ":$PREFIX/lib/libturbojpeg.dylib" \
  --include-function tj3InitVersion \
  --include-constant TURBOJPEG_VERSION_NUMBER \
  --include-function tj3Destroy \
  --include-function tj3DecompressHeader \
  --include-function tj3Get \
  --include-function tj3Set \
  --include-function tj3SetScalingFactor \
  --include-function tj3GetScalingFactors \
  --include-function tj3Decompress8 \
  --include-function tj3GetErrorStr \
  --include-function tj3GetErrorCode \
  --include-struct tjscalingfactor \
  --include-typedef tjscalingfactor \
  --include-constant TJINIT_DECOMPRESS \
  --include-constant TJPARAM_JPEGWIDTH \
  --include-constant TJPARAM_JPEGHEIGHT \
  --include-constant TJPARAM_SUBSAMP \
  --include-constant TJPARAM_COLORSPACE \
  --include-constant TJPARAM_PRECISION \
  --include-constant TJPARAM_PROGRESSIVE \
  --include-constant TJPARAM_LOSSLESS \
  --include-constant TJPF_BGRA \
  --include-constant TJPF_GRAY \
  --include-constant TJCS_RGB \
  --include-constant TJCS_YCbCr \
  --include-constant TJCS_GRAY \
  --include-constant TJCS_CMYK \
  --include-constant TJCS_YCCK \
  --include-constant TJERR_WARNING \
  --include-constant TJERR_FATAL \
  "$ROOT/jextract/turbojpeg_api.h"

# Replace the baked absolute-path lookup chain with the runtime loader.
perl -0777 -pi -e \
  's/static final SymbolLookup SYMBOL_LOOKUP = .*?;/static final SymbolLookup SYMBOL_LOOKUP = io.github.ghosthack.turbojpegffm.TurboJpegLibs.lookup();/s' \
  "$GEN_DIR/TurboJpeg.java"

if grep -rn "$PREFIX" "$GEN_DIR" >/dev/null; then
  echo "ERROR: build-prefix paths survived in generated stubs"; exit 1
fi
grep -q "TurboJpegLibs.lookup()" "$GEN_DIR/TurboJpeg.java" || { echo "ERROR: lookup patch did not apply"; exit 1; }

echo "Generated $(ls "$GEN_DIR" | wc -l | tr -d ' ') files into $GEN_DIR"
