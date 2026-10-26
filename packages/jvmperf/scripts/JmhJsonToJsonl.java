import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.regex.*;

/**
 * Minimal JMH JSON → research JSONL converter (no external JSON lib).
 * Expects JMH -rf json output (array of primary result objects).
 */
public class JmhJsonToJsonl {
    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("usage: JmhJsonToJsonl <jmh.json> <out.jsonl>");
            System.exit(2);
        }
        String raw = Files.readString(Path.of(args[0]), StandardCharsets.UTF_8);
        String jdk = System.getProperty("java.version", "?");
        String vm = System.getProperty("java.vm.version", "?");
        String os = System.getProperty("os.name", "?").toLowerCase(Locale.ROOT).contains("linux")
                ? "linux" : System.getProperty("os.name");
        String arch = System.getProperty("os.arch", "?");
        String cpu = detectCpu();
        String ts = OffsetDateTime.now(ZoneId.of("Asia/Shanghai")).toString();
        String jvmArgs = System.getenv().getOrDefault("JMH_RECORDED_JVM_ARGS",
                "-XX:+UseCompactObjectHeaders (from @Fork jvmArgsAppend)");

        StringBuilder out = new StringBuilder();
        // Split top-level objects crudely: JMH emits [{...},{...}]
        List<String> objs = splitObjects(raw);
        for (String obj : objs) {
            String benchmark = field(obj, "benchmark");
            String mode = field(obj, "mode");
            String unit = field(obj, "scoreUnit");
            String score = field(obj, "score");
            String params = nestedObject(obj, "params");
            String secondary = nestedObject(obj, "secondaryMetrics");
            String alloc = secondaryMetricScore(secondary, "gc.alloc.rate.norm");

            String shortName = benchmark;
            int dot = benchmark.lastIndexOf('.');
            if (dot >= 0) shortName = benchmark.substring(dot + 1);
            // Include class simple name for uniqueness
            String className = benchmark;
            int lastDot = benchmark.lastIndexOf('.');
            if (lastDot > 0) {
                String before = benchmark.substring(0, lastDot);
                int prev = before.lastIndexOf('.');
                className = (prev >= 0 ? before.substring(prev + 1) : before) + "." + shortName;
            }

            String paramSuffix = "";
            if (params != null && !params.isBlank() && !params.equals("{}")) {
                // e.g. "n" : "1000000"
                Matcher pm = Pattern.compile("\"([^\"]+)\"\\s*:\\s*\"([^\"]+)\"").matcher(params);
                List<String> bits = new ArrayList<>();
                while (pm.find()) bits.add(pm.group(1) + "=" + pm.group(2));
                if (!bits.isEmpty()) paramSuffix = "[" + String.join(",", bits) + "]";
            }

            double scoreVal = Double.parseDouble(score);
            Double nsPerOp = null;
            Double opsPerS = null;
            if ("ns/op".equals(unit)) {
                nsPerOp = scoreVal;
            } else if ("ops/s".equals(unit) || "ops/us".equals(unit) || "ops/ms".equals(unit)) {
                // convert to ops/s if needed
                if ("ops/us".equals(unit)) opsPerS = scoreVal * 1_000_000.0;
                else if ("ops/ms".equals(unit)) opsPerS = scoreVal * 1_000.0;
                else opsPerS = scoreVal;
            } else if ("us/op".equals(unit)) {
                nsPerOp = scoreVal * 1_000.0;
            } else if ("ms/op".equals(unit)) {
                nsPerOp = scoreVal * 1_000_000.0;
            } else if ("s/op".equals(unit)) {
                nsPerOp = scoreVal * 1_000_000_000.0;
            }

            StringBuilder line = new StringBuilder();
            line.append('{');
            append(line, "name", className + paramSuffix, true);
            if (nsPerOp != null) {
                line.append(',');
                appendNum(line, "ns_per_op", nsPerOp);
            }
            if (opsPerS != null) {
                line.append(',');
                appendNum(line, "ops_per_s", opsPerS);
            }
            if (alloc != null && !alloc.isBlank()) {
                line.append(',');
                appendNum(line, "alloc_b_per_op", Double.parseDouble(alloc));
            }
            line.append(',');
            append(line, "jmh_mode", mode, false);
            line.append(',');
            append(line, "score_unit", unit, false);
            line.append(',');
            append(line, "jdk_version", jdk + " (" + vm + ")", false);
            line.append(',');
            append(line, "jvm_args", jvmArgs, false);
            line.append(',');
            append(line, "os", os, false);
            line.append(',');
            append(line, "cpu_arch", arch, false);
            line.append(',');
            append(line, "cpu_model", cpu, false);
            line.append(',');
            append(line, "timestamp", ts, false);
            line.append(',');
            append(line, "jmh_version", "1.37", false);
            line.append('}');
            out.append(line).append('\n');
        }
        Files.writeString(Path.of(args[1]), out.toString(), StandardCharsets.UTF_8);
    }

    static String detectCpu() {
        try {
            String info = Files.readString(Path.of("/proc/cpuinfo"));
            Matcher fam = Pattern.compile("cpu family\\s*:\\s*(\\d+)").matcher(info);
            Matcher mod = Pattern.compile("^model\\s*:\\s*(\\d+)", Pattern.MULTILINE).matcher(info);
            if (fam.find() && mod.find()) {
                int f = Integer.parseInt(fam.group(1));
                int m = Integer.parseInt(mod.group(1));
                if (f == 6 && m == 207) return "emeraldrapids";
            }
            Matcher name = Pattern.compile("model name\\s*:\\s*(.+)").matcher(info);
            if (name.find()) return name.group(1).trim().replace(' ', '_');
        } catch (Exception ignored) {}
        return "unknown";
    }

    static List<String> splitObjects(String raw) {
        List<String> out = new ArrayList<>();
        int depth = 0, start = -1;
        boolean inStr = false, esc = false;
        for (int i = 0; i < raw.length(); i++) {
            char c = raw.charAt(i);
            if (inStr) {
                if (esc) esc = false;
                else if (c == '\\') esc = true;
                else if (c == '"') inStr = false;
                continue;
            }
            if (c == '"') { inStr = true; continue; }
            if (c == '{') {
                if (depth == 0) start = i;
                depth++;
            } else if (c == '}') {
                depth--;
                if (depth == 0 && start >= 0) {
                    out.add(raw.substring(start, i + 1));
                    start = -1;
                }
            }
        }
        return out;
    }

    static String field(String obj, String key) {
        Matcher m = Pattern.compile("\"" + Pattern.quote(key) + "\"\\s*:\\s*(\"(?:\\\\.|[^\"\\\\])*\"|-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)")
                .matcher(obj);
        if (!m.find()) return "";
        String v = m.group(1);
        if (v.startsWith("\"")) v = v.substring(1, v.length() - 1).replace("\\\"", "\"");
        return v;
    }

    static String nestedObject(String obj, String key) {
        Matcher m = Pattern.compile("\"" + Pattern.quote(key) + "\"\\s*:\\s*\\{").matcher(obj);
        if (!m.find()) return null;
        int i = m.end() - 1;
        int depth = 0;
        boolean inStr = false, esc = false;
        for (int j = i; j < obj.length(); j++) {
            char c = obj.charAt(j);
            if (inStr) {
                if (esc) esc = false;
                else if (c == '\\') esc = true;
                else if (c == '"') inStr = false;
                continue;
            }
            if (c == '"') { inStr = true; continue; }
            if (c == '{') depth++;
            else if (c == '}') {
                depth--;
                if (depth == 0) return obj.substring(i, j + 1);
            }
        }
        return null;
    }

    static String secondaryMetricScore(String secondary, String metric) {
        if (secondary == null) return null;
        // "gc.alloc.rate.norm" : { ... "score" : 123.0 ... }
        Matcher m = Pattern.compile("\"" + Pattern.quote(metric) + "\"\\s*:\\s*\\{").matcher(secondary);
        if (!m.find()) return null;
        int i = m.end() - 1;
        int depth = 0;
        boolean inStr = false, esc = false;
        int end = -1;
        for (int j = i; j < secondary.length(); j++) {
            char c = secondary.charAt(j);
            if (inStr) {
                if (esc) esc = false;
                else if (c == '\\') esc = true;
                else if (c == '"') inStr = false;
                continue;
            }
            if (c == '"') { inStr = true; continue; }
            if (c == '{') depth++;
            else if (c == '}') {
                depth--;
                if (depth == 0) { end = j + 1; break; }
            }
        }
        if (end < 0) return null;
        return field(secondary.substring(i, end), "score");
    }

    static void append(StringBuilder sb, String k, String v, boolean first) {
        if (!first) { /* comma added by caller */ }
        sb.append('"').append(k).append('"').append(':');
        sb.append('"').append(escape(v)).append('"');
    }

    static void appendNum(StringBuilder sb, String k, double v) {
        sb.append('"').append(k).append('"').append(':');
        if (Double.isFinite(v)) sb.append(String.format(Locale.US, "%.3f", v));
        else sb.append("null");
    }

    static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
