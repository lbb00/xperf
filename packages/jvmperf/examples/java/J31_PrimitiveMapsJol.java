import androidx.collection.MutableIntIntMap;
import it.unimi.dsi.fastutil.ints.Int2IntOpenHashMap;
import org.eclipse.collections.impl.map.mutable.primitive.IntIntHashMap;
import org.openjdk.jol.info.GraphLayout;
import org.openjdk.jol.vm.VM;

import java.io.BufferedWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * JOL GraphLayout sizes for boxed HashMap vs primitive int-int maps.
 * Guide §3.2. Keys/values start at 1000 so Integer cache does not share instances.
 *
 * Usage:
 *   java -cp jol:fastutil:ec:androidx:. [-XX:+UseCompactObjectHeaders] J31_PrimitiveMapsJol [out.jsonl] [out.txt]
 */
public class J31_PrimitiveMapsJol {

    static final int[] NS = {1000, 100_000};

    public static void main(String[] args) throws Exception {
        Path jsonl = Path.of(args.length > 0 ? args[0] : System.getProperty("java.io.tmpdir") + "/J31_PrimitiveMapsJol.jsonl");
        Path txt = Path.of(args.length > 1 ? args[1] : System.getProperty("java.io.tmpdir") + "/J31_PrimitiveMapsJol.txt");
        String jdk = System.getProperty("java.version") + " (" + System.getProperty("java.vm.version") + ")";
        String jvmArgs = detectCoh() ? "-XX:+UseCompactObjectHeaders" : "(default headers)";
        boolean coh = detectCoh();
        String os = System.getProperty("os.name", "unknown").toLowerCase(Locale.ROOT).contains("linux") ? "linux" : System.getProperty("os.name");
        String arch = System.getProperty("os.arch");
        String cpu = detectCpu();
        String ts = OffsetDateTime.now(ZoneId.of("Asia/Shanghai")).toString();

        StringBuilder human = new StringBuilder();
        human.append("java.version=").append(System.getProperty("java.version")).append('\n');
        human.append("coh=").append(coh).append(" jvm_args=").append(jvmArgs).append('\n');
        human.append(VM.current().details()).append('\n');

        try (BufferedWriter out = Files.newBufferedWriter(jsonl, StandardCharsets.UTF_8)) {
            for (int n : NS) {
                emit(out, human, "HashMap", n, buildHashMap(n), jdk, jvmArgs, coh, os, arch, cpu, ts);
                emit(out, human, "fastutil_Int2IntOpenHashMap", n, buildFastutil(n), jdk, jvmArgs, coh, os, arch, cpu, ts);
                emit(out, human, "eclipse_IntIntHashMap", n, buildEclipse(n), jdk, jvmArgs, coh, os, arch, cpu, ts);
                emit(out, human, "androidx_MutableIntIntMap", n, buildAndroidx(n), jdk, jvmArgs, coh, os, arch, cpu, ts);
            }
        }
        Files.writeString(txt, human.toString(), StandardCharsets.UTF_8);
        System.out.println("J31 ok wrote " + jsonl.toAbsolutePath() + " and " + txt.toAbsolutePath());
    }

    static Map<Integer, Integer> buildHashMap(int n) {
        Map<Integer, Integer> m = new HashMap<>(n);
        for (int i = 0; i < n; i++) {
            int v = i + 1000;
            m.put(v, v);
        }
        return m;
    }

    static Int2IntOpenHashMap buildFastutil(int n) {
        Int2IntOpenHashMap m = new Int2IntOpenHashMap(n);
        for (int i = 0; i < n; i++) {
            int v = i + 1000;
            m.put(v, v);
        }
        return m;
    }

    static IntIntHashMap buildEclipse(int n) {
        IntIntHashMap m = new IntIntHashMap(n);
        for (int i = 0; i < n; i++) {
            int v = i + 1000;
            m.put(v, v);
        }
        return m;
    }

    static MutableIntIntMap buildAndroidx(int n) {
        MutableIntIntMap m = new MutableIntIntMap(n);
        for (int i = 0; i < n; i++) {
            int v = i + 1000;
            m.set(v, v);
        }
        return m;
    }

    static void emit(BufferedWriter out, StringBuilder human, String kind, int n, Object o,
                     String jdk, String jvmArgs, boolean coh, String os, String arch, String cpu, String ts)
            throws Exception {
        GraphLayout gl = GraphLayout.parseInstance(o);
        long total = gl.totalSize();
        long count = gl.totalCount();
        String name = "J31_PrimitiveMapsJol." + kind + "[n=" + n + "]";
        human.append(String.format(Locale.ROOT, "%-48s total=%d bytes objects=%d%n", name, total, count));

        StringBuilder line = new StringBuilder(256);
        line.append('{');
        append(line, "name", name, true);
        line.append(',');
        appendNum(line, "total_size_bytes", total);
        line.append(',');
        appendNum(line, "total_count", count);
        line.append(',');
        appendNum(line, "n", n);
        line.append(',');
        append(line, "map_kind", kind, false);
        line.append(',');
        append(line, "jdk_version", jdk, false);
        line.append(',');
        append(line, "jvm_args", jvmArgs, false);
        line.append(',');
        append(line, "coh", String.valueOf(coh), false);
        line.append(',');
        append(line, "os", os, false);
        line.append(',');
        append(line, "cpu_arch", arch, false);
        line.append(',');
        append(line, "cpu_model", cpu, false);
        line.append(',');
        append(line, "timestamp", ts, false);
        line.append(',');
        append(line, "jol_version", "0.17", false);
        line.append('}');
        out.write(line.toString());
        out.newLine();
    }

    static boolean detectCoh() {
        String prop = System.getProperty("jvmperf.coh");
        if (prop != null) return Boolean.parseBoolean(prop);
        String details = VM.current().details();
        return details.toLowerCase(Locale.ROOT).contains("compact object headers")
                || details.contains("+UseCompactObjectHeaders");
    }

    static String detectCpu() {
        try {
            String info = Files.readString(Path.of("/proc/cpuinfo"));
            var fam = java.util.regex.Pattern.compile("cpu family\\s*:\\s*(\\d+)").matcher(info);
            var mod = java.util.regex.Pattern.compile("^model\\s*:\\s*(\\d+)", java.util.regex.Pattern.MULTILINE).matcher(info);
            if (fam.find() && mod.find()) {
                int f = Integer.parseInt(fam.group(1));
                int m = Integer.parseInt(mod.group(1));
                if (f == 6 && m == 207) return "emeraldrapids";
            }
            var name = java.util.regex.Pattern.compile("model name\\s*:\\s*(.+)").matcher(info);
            if (name.find()) return name.group(1).trim().replace(' ', '_');
        } catch (Exception ignored) {}
        return "unknown";
    }

    static void append(StringBuilder sb, String k, String v, boolean first) {
        if (!first) { /* already commas from caller */ }
        sb.append('"').append(k).append("\":\"").append(esc(v)).append('"');
    }

    static void appendNum(StringBuilder sb, String k, long v) {
        sb.append('"').append(k).append("\":").append(v);
    }

    static String esc(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
