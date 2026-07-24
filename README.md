# turbojpeg-ffm

Panama FFM (jextract) bindings for the **TurboJPEG 3** API with bundled,
from-source **libjpeg-turbo** natives. One Maven coordinate, batteries
included — no user-installed libjpeg-turbo, no JNI.

The point of TurboJPEG for thumbnailing is **DCT scaled decode**
(shrink-on-load): ask for a 1/8..1/1 scaling factor and the decoder never
materializes the full-size image, which is severalfold faster than
decode-then-downscale for baseline JPEG.

```xml
<dependency>
  <groupId>io.github.ghosthack</groupId>
  <artifactId>turbojpeg-ffm</artifactId>
  <version>3.2.0-0.2.0</version>
</dependency>
<dependency>
  <groupId>io.github.ghosthack</groupId>
  <artifactId>turbojpeg-ffm-natives</artifactId>
  <version>3.2.0-0.2.0</version>
  <classifier>macos-arm64</classifier> <!-- and/or windows-x64 -->
  <scope>runtime</scope>
</dependency>
```

```java
import io.github.ghosthack.turbojpegffm.turbojpeg.TurboJpeg;
import io.github.ghosthack.turbojpegffm.turbojpeg.tjscalingfactor;

MemorySegment handle = TurboJpeg.tj3InitVersion(
        TurboJpeg.TJINIT_DECOMPRESS(), TurboJpeg.TURBOJPEG_VERSION_NUMBER());
TurboJpeg.tj3DecompressHeader(handle, jpegBuf, jpegSize);
// pick a tjscalingfactor, tj3SetScalingFactor, then tj3Decompress8 to TJPF_BGRA
```

Requires `--enable-native-access=ALL-UNNAMED` (JDK 22+).

## Library resolution

`TurboJpegLibs.lookup()` resolves, in order:

1. `-Dturbojpegffm.libdir=<dir>` / `TURBOJPEG_FFM_LIBDIR` — bind a host
   libjpeg-turbo install instead of the bundled one (smallest footprint);
2. the platform's `turbojpeg-ffm-natives` classifier jar, self-extracted once
   to `~/.cache/turbojpeg-ffm/<version>-<platform>/`;
3. already-loaded libraries (loader/default lookup).

Classifier jars exist for **macos-arm64** and **windows-x64**.

## Building

- `build-natives/macos-arm64.sh` / `build-natives/windows-x64.sh` (MSYS2
  MINGW64) build libjpeg-turbo from source (cmake + ninja + nasm) and stage
  the shared library under `natives/src/main/resources/turbojpeg-natives/`.
- `jextract/gen-bindings.sh` regenerates the stubs from the built headers and
  re-points the symbol lookup at the runtime loader.
- Releases publish from GitHub Actions (same flow as
  [ffmpeg-ffm](https://github.com/ghosthack/ffmpeg-ffm): bump the pom
  version, push to main).

## Licensing

Binding code is MIT. The natives jars convey libjpeg-turbo binaries
(BSD-3-Clause / IJG / zlib — see THIRD-PARTY.md and the LICENSE.md inside
each jar).
