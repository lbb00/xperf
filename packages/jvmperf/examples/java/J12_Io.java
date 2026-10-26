import java.io.BufferedWriter;
import java.io.IOException;
import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

/** I/O: buffered writes, line-by-line reads, and mapping to an unrestricted-size MemorySegment. */
public class J12_Io {
    public static void main(String[] args) throws IOException {
        Path p = Files.createTempFile("jvmperf", ".txt");
        try (BufferedWriter w = Files.newBufferedWriter(p, StandardCharsets.UTF_8)) {  // 8 KiB buffer by default.
            for (int i = 0; i < 1000; i++) { w.write(Integer.toString(i)); w.newLine(); }
        }
        long lines;
        try (var s = Files.lines(p)) { lines = s.count(); }
        if (lines != 1000) throw new AssertionError();

        try (FileChannel ch = FileChannel.open(p, StandardOpenOption.READ); Arena arena = Arena.ofConfined()) {
            MemorySegment m = ch.map(FileChannel.MapMode.READ_ONLY, 0, ch.size(), arena);  // JDK 22+
            long newlines = 0;
            for (long i = 0; i < m.byteSize(); i++) if (m.get(ValueLayout.JAVA_BYTE, i) == '\n') newlines++;
            if (newlines != 1000) throw new AssertionError();
        }
        Files.delete(p);
        System.out.println("J12 ok");
    }
}
