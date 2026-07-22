package io.github.ghosthack.turbojpegffm;

import io.github.ghosthack.turbojpegffm.turbojpeg.TurboJpeg;
import io.github.ghosthack.turbojpegffm.turbojpeg.tjscalingfactor;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** End-to-end: bundled native loads, header parses, full and scaled decode work. */
class TurboJpegSmokeTest {

    @Test
    void decodesHeaderFullAndHalfScale() throws Exception {
        BufferedImage img = new BufferedImage(64, 48, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < 48; y++) {
            for (int x = 0; x < 64; x++) {
                img.setRGB(x, y, (x * 4) << 16 | (y * 5) << 8 | 0x40);
            }
        }
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        assertTrue(ImageIO.write(img, "jpeg", out), "test JPEG encodes");
        byte[] jpeg = out.toByteArray();

        try (Arena arena = Arena.ofConfined()) {
            // tj3Init is a macro over tj3InitVersion since libjpeg-turbo 3.2.
            MemorySegment handle = TurboJpeg.tj3InitVersion(
                    TurboJpeg.TJINIT_DECOMPRESS(), TurboJpeg.TURBOJPEG_VERSION_NUMBER());
            assertNotEquals(MemorySegment.NULL, handle, "tj3Init");
            try {
                MemorySegment buf = arena.allocate(jpeg.length);
                MemorySegment.copy(jpeg, 0, buf, java.lang.foreign.ValueLayout.JAVA_BYTE, 0, jpeg.length);

                assertEquals(0, TurboJpeg.tj3DecompressHeader(handle, buf, jpeg.length), "header");
                assertEquals(64, TurboJpeg.tj3Get(handle, TurboJpeg.TJPARAM_JPEGWIDTH()));
                assertEquals(48, TurboJpeg.tj3Get(handle, TurboJpeg.TJPARAM_JPEGHEIGHT()));

                // Full decode to BGRA.
                MemorySegment full = arena.allocate((long) 64 * 48 * 4);
                assertEquals(0, TurboJpeg.tj3Decompress8(handle, buf, jpeg.length, full, 64 * 4,
                        TurboJpeg.TJPF_BGRA()), "full decode");

                // 1/2-scale decode: 32x24.
                MemorySegment factor = tjscalingfactor.allocate(arena);
                tjscalingfactor.num(factor, 1);
                tjscalingfactor.denom(factor, 2);
                assertEquals(0, TurboJpeg.tj3SetScalingFactor(handle, factor), "set scaling");
                assertEquals(0, TurboJpeg.tj3DecompressHeader(handle, buf, jpeg.length));
                MemorySegment half = arena.allocate((long) 32 * 24 * 4);
                assertEquals(0, TurboJpeg.tj3Decompress8(handle, buf, jpeg.length, half, 32 * 4,
                        TurboJpeg.TJPF_BGRA()), "half-scale decode");
                // Center pixel of the gradient survives the round trip roughly intact.
                int off = (12 * 32 + 16) * 4;
                int b = half.get(java.lang.foreign.ValueLayout.JAVA_BYTE, off) & 0xFF;
                assertTrue(Math.abs(b - 0x40) < 32, "blue channel plausible: " + b);
            } finally {
                TurboJpeg.tj3Destroy(handle);
            }
        }
    }
}
