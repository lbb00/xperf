package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;

/**
 * Comparative: unbuffered FileOutputStream vs BufferedOutputStream (8 KiB).
 * Guide §8.3 — prefer buffered writers for many small writes.
 * Each op writes {@code lines} short UTF-8 lines then flushes/closes.
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 3, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J30_BufferedIo {

    @Param({"1000", "10000"})
    int lines;

    Path dir;
    byte[] lineBytes;

    @Setup
    public void setup() throws IOException {
        dir = Files.createTempDirectory("jmh-j30-");
        lineBytes = "0123456789\n".getBytes(StandardCharsets.UTF_8);
    }

    @TearDown
    public void tearDown() throws IOException {
        if (dir != null) {
            try (var stream = Files.list(dir)) {
                stream.forEach(p -> {
                    try {
                        Files.deleteIfExists(p);
                    } catch (IOException ignored) {
                    }
                });
            }
            Files.deleteIfExists(dir);
        }
    }

    @Benchmark
    public int unbuffered() throws IOException {
        Path p = dir.resolve("unbuf-" + Thread.currentThread().threadId() + ".bin");
        try (OutputStream out = new FileOutputStream(p.toFile())) {
            int n = lines;
            byte[] buf = lineBytes;
            for (int i = 0; i < n; i++) {
                out.write(buf);
            }
        }
        long size = Files.size(p);
        Files.deleteIfExists(p);
        return (int) size;
    }

    @Benchmark
    public int buffered8k() throws IOException {
        Path p = dir.resolve("buf-" + Thread.currentThread().threadId() + ".bin");
        try (OutputStream out = new BufferedOutputStream(new FileOutputStream(p.toFile()), 8192)) {
            int n = lines;
            byte[] buf = lineBytes;
            for (int i = 0; i < n; i++) {
                out.write(buf);
            }
        }
        long size = Files.size(p);
        Files.deleteIfExists(p);
        return (int) size;
    }
}
