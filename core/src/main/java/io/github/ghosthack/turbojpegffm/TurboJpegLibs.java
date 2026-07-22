package io.github.ghosthack.turbojpegffm;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.lang.foreign.Arena;
import java.lang.foreign.Linker;
import java.lang.foreign.SymbolLookup;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;

/**
 * Resolves the libjpeg-turbo shared library the generated {@code TurboJpeg}
 * stubs bind to.
 *
 * <p>Resolution order:
 * <ol>
 *   <li>{@code -Dturbojpegffm.libdir=<dir>} or {@code TURBOJPEG_FFM_LIBDIR} env var — load
 *       an existing libjpeg-turbo install from that directory (e.g. a system package);</li>
 *   <li>bundled natives — the {@code turbojpeg-ffm-natives} classifier jar for this
 *       platform, extracted once to {@code ~/.cache/turbojpeg-ffm/<version>-<platform>/};</li>
 *   <li>{@link SymbolLookup#loaderLookup()} and the native linker's default lookup, so
 *       libraries pre-loaded by the host application still resolve.</li>
 * </ol>
 */
public final class TurboJpegLibs {

    private static final Arena LIBRARY_ARENA = Arena.ofAuto();
    private static volatile SymbolLookup lookup;

    private TurboJpegLibs() {}

    public static SymbolLookup lookup() {
        SymbolLookup l = lookup;
        if (l == null) {
            synchronized (TurboJpegLibs.class) {
                l = lookup;
                if (l == null) {
                    lookup = l = resolve();
                }
            }
        }
        return l;
    }

    private static SymbolLookup resolve() {
        String override = System.getProperty("turbojpegffm.libdir", System.getenv("TURBOJPEG_FFM_LIBDIR"));
        SymbolLookup resolved = override != null ? fromDirectory(Path.of(override)) : fromBundle();
        SymbolLookup fallback = SymbolLookup.loaderLookup()
                .or(Linker.nativeLinker().defaultLookup());
        return resolved != null ? resolved.or(fallback) : fallback;
    }

    /** Chain every turbojpeg-looking shared library in {@code dir}. */
    private static SymbolLookup fromDirectory(Path dir) {
        if (!Files.isDirectory(dir)) {
            throw new IllegalStateException("turbojpegffm.libdir does not exist: " + dir);
        }
        List<Path> libs = new ArrayList<>();
        try (var files = Files.list(dir)) {
            files.filter(TurboJpegLibs::isTurboJpegLibrary).sorted().forEach(libs::add);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        if (libs.isEmpty()) {
            throw new IllegalStateException("no turbojpeg shared library found in " + dir);
        }
        return chain(libs);
    }

    private static boolean isTurboJpegLibrary(Path p) {
        String n = p.getFileName().toString();
        boolean nativeExt = n.endsWith(".dylib") || n.endsWith(".dll") || n.contains(".so");
        return nativeExt && n.contains("turbojpeg");
    }

    /** Extract this platform's bundled library to the cache dir and load it. */
    private static SymbolLookup fromBundle() {
        String classifier = classifier();
        String base = "turbojpeg-natives/" + classifier + "/";
        List<String> manifest = readManifest(base);
        if (manifest == null) {
            return null; // no natives jar on the classpath; fall back to loader/default lookup
        }
        Path cacheDir = Path.of(System.getProperty("user.home"), ".cache", "turbojpeg-ffm",
                Version.VERSION + "-" + classifier);
        try {
            Files.createDirectories(cacheDir);
            List<Path> libs = new ArrayList<>();
            for (String name : manifest) {
                libs.add(extract(base + name, cacheDir.resolve(name)));
            }
            return chain(libs);
        } catch (IOException e) {
            throw new UncheckedIOException("failed to extract bundled turbojpeg native to " + cacheDir, e);
        }
    }

    private static List<String> readManifest(String base) {
        try (InputStream in = TurboJpegLibs.class.getClassLoader().getResourceAsStream(base + "manifest.txt")) {
            if (in == null) {
                return null;
            }
            return new String(in.readAllBytes(), StandardCharsets.UTF_8).lines()
                    .map(String::trim).filter(s -> !s.isEmpty()).toList();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private static Path extract(String resource, Path target) throws IOException {
        try (InputStream in = TurboJpegLibs.class.getClassLoader().getResourceAsStream(resource)) {
            if (in == null) {
                throw new IOException("missing classpath resource " + resource);
            }
            byte[] bytes = in.readAllBytes();
            if (Files.exists(target) && Files.size(target) == bytes.length) {
                return target;
            }
            Path tmp = Files.createTempFile(target.getParent(), target.getFileName().toString(), ".tmp");
            Files.write(tmp, bytes);
            Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
            return target;
        }
    }

    private static SymbolLookup chain(List<Path> libs) {
        SymbolLookup result = null;
        for (Path lib : libs) {
            SymbolLookup one = SymbolLookup.libraryLookup(lib.toAbsolutePath().toString(), LIBRARY_ARENA);
            result = result == null ? one : result.or(one);
        }
        return result;
    }

    static String classifier() {
        String os = System.getProperty("os.name", "").toLowerCase();
        String arch = System.getProperty("os.arch", "").toLowerCase();
        String osPart = os.contains("mac") ? "macos" : os.contains("win") ? "windows" : "linux";
        String archPart = (arch.equals("aarch64") || arch.equals("arm64")) ? "arm64" : "x64";
        return osPart + "-" + archPart;
    }
}
