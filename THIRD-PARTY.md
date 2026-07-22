# Third-party notices

## libjpeg-turbo

The `turbojpeg-ffm-natives` classifier jars contain a shared library built
from **unmodified libjpeg-turbo source**
(https://github.com/libjpeg-turbo/libjpeg-turbo), covered by three
permissive licenses (see `LICENSE.md` inside each jar):

- the **IJG (Independent JPEG Group) license** (libjpeg API code),
- the **Modified (3-clause) BSD license** (TurboJPEG API code and parts of
  the build system),
- the **zlib license** (SIMD extensions).

The exact version and build flags ship in each jar's `BUILD-INFO.txt`.
Corresponding source:
`https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/<version>/libjpeg-turbo-<version>.tar.gz`.

The library is dynamically loaded and user-replaceable: point
`TURBOJPEG_FFM_LIBDIR` (or `-Dturbojpegffm.libdir`) at any directory
containing a compatible libjpeg-turbo build to substitute your own copy.
