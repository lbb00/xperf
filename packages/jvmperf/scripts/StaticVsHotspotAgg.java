import java.nio.file.*;
import java.util.*;
import java.util.regex.*;
import java.time.*;
import java.time.format.DateTimeFormatter;

public class StaticVsHotspotAgg {
  static String field(String line, String key) {
    Matcher m = Pattern.compile("\"" + Pattern.quote(key) + "\"\\s*:\\s*([0-9.eE+-]+|\"[^\"]*\")").matcher(line);
    if (!m.find()) return null;
    String v = m.group(1);
    return v.startsWith("\"") ? v.substring(1, v.length() - 1) : v;
  }
  static Double findNs(Path jsonl, String nameContains) throws Exception {
    if (!Files.exists(jsonl)) return null;
    Double best = null;
    for (String line : Files.readAllLines(jsonl)) {
      String name = field(line, "name");
      if (name == null || !name.contains(nameContains)) continue;
      String ns = field(line, "ns_per_op");
      if (ns == null) continue;
      best = Double.parseDouble(ns);
    }
    return best;
  }
  static Double findAlloc(Path jsonl, String nameContains) throws Exception {
    if (!Files.exists(jsonl)) return null;
    Double best = null;
    for (String line : Files.readAllLines(jsonl)) {
      String name = field(line, "name");
      if (name == null || !name.contains(nameContains)) continue;
      String a = field(line, "alloc_b_per_op");
      if (a == null) continue;
      best = Double.parseDouble(a);
    }
    return best;
  }
  static String jdk(Path jsonl) throws Exception {
    if (!Files.exists(jsonl)) return "unknown";
    for (String line : Files.readAllLines(jsonl)) {
      String v = field(line, "jdk_version");
      if (v != null) return v;
    }
    return "unknown";
  }
  static void emit(List<String> jsonlOut, StringBuilder jsonArr, boolean first,
                   String id, String rule, String smell, String clean,
                   Double smellNs, Double cleanNs, Double smellB, Double cleanB,
                   String agree, String jitSignal, String source) {
    double ratio = (smellNs != null && cleanNs != null && cleanNs > 0) ? smellNs / cleanNs : Double.NaN;
    double ratioB = (smellB != null && cleanB != null && cleanB > 0) ? smellB / cleanB : Double.NaN;
    String ts = DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(ZonedDateTime.now());
    String line = String.format(Locale.ROOT,
      "{\"case\":\"%s\",\"rule\":\"%s\",\"smell\":\"%s\",\"clean\":\"%s\",\"smell_ns\":%s,\"clean_ns\":%s,\"ratio_time\":%s,\"smell_b_op\":%s,\"clean_b_op\":%s,\"ratio_b\":%s,\"agree\":\"%s\",\"jit_signal\":\"%s\",\"source\":\"%s\",\"ts\":\"%s\"}",
      id, rule, smell, clean,
      smellNs == null ? "null" : String.format(Locale.ROOT, "%.3f", smellNs),
      cleanNs == null ? "null" : String.format(Locale.ROOT, "%.3f", cleanNs),
      Double.isNaN(ratio) ? "null" : String.format(Locale.ROOT, "%.4f", ratio),
      smellB == null ? "null" : String.format(Locale.ROOT, "%.3f", smellB),
      cleanB == null ? "null" : String.format(Locale.ROOT, "%.3f", cleanB),
      Double.isNaN(ratioB) ? "null" : String.format(Locale.ROOT, "%.4f", ratioB),
      agree, jitSignal, source, ts);
    jsonlOut.add(line);
    if (!first) jsonArr.append(",\n");
    jsonArr.append("  ").append(line);
    System.out.printf(Locale.ROOT, "%s  rule=%s  ratio_time=%s  agree=%s%n",
      id, rule, Double.isNaN(ratio) ? "n/a" : String.format(Locale.ROOT, "%.2fx", ratio), agree);
  }
  public static void main(String[] args) throws Exception {
    Path res = Paths.get(args[0]);
    Path outDir = Paths.get(args[1]);
    List<String> lines = new ArrayList<>();
    StringBuilder arr = new StringBuilder("[\n");
    boolean first = true;

    Path j20 = res.resolve("J20_BoxingSum.jsonl");
    Double list = findNs(j20, "sumArrayList[n=1000000]");
    Double arrPrim = findNs(j20, "sumIntArray[n=1000000]");
    emit(lines, arr, first, "1_boxing_sum", "jp-boxed-primitive-collection", "ArrayList<Integer>", "int[]",
      list, arrPrim, findAlloc(j20, "sumArrayList[n=1000000]"), findAlloc(j20, "sumIntArray[n=1000000]"),
      "YES", "NO_noisy_not_gated", "J20_BoxingSum.jsonl");
    first = false;

    Path j25 = res.resolve("J25_Presize.jsonl");
    emit(lines, arr, first, "2_unpresized", "jp-unpresized-collection", "growFromDefault", "presized",
      findNs(j25, "growFromDefault[n=10000]"), findNs(j25, "presized[n=10000]"),
      findAlloc(j25, "growFromDefault[n=10000]"), findAlloc(j25, "presized[n=10000]"),
      "PARTIAL", "NO_resize_not_deopt", "J25_Presize.jsonl");

    Path j27 = res.resolve("J27_FormatHot.jsonl");
    emit(lines, arr, first, "3_format_hot", "jp-format-hot", "stringFormat", "stringBuilderAppend",
      findNs(j27, "stringFormat[reps=1]"), findNs(j27, "stringBuilderAppend[reps=1]"),
      findAlloc(j27, "stringFormat[reps=1]"), findAlloc(j27, "stringBuilderAppend[reps=1]"),
      "YES", "NO_alloc_parser", "J27_FormatHot.jsonl");

    emit(lines, arr, first, "4_escape_analysis", "(none)", "EA_off_alloc", "EA_on_alloc",
      null, null, 96000.0, 0.0,
      "YES_Bop", "EA_flag_probe_not_PrintCompilation", "EaProbe / ea-probe-confirm.txt");

    Path j24 = res.resolve("J24_PoolVsAlloc.jsonl");
    emit(lines, arr, first, "5_pool_vs_tlab", "jp-expensive-alloc-hot-adjacent", "pooled", "tlabAlloc",
      findNs(j24, "pooled[batch=1]"), findNs(j24, "tlabAlloc[batch=1]"),
      findAlloc(j24, "pooled[batch=1]"), findAlloc(j24, "tlabAlloc[batch=1]"),
      "PARTIAL_negative_pool", "NO", "J24_PoolVsAlloc.jsonl");

    Path j28 = res.resolve("J28_VectorVsScalar.jsonl");
    emit(lines, arr, first, "6_vector_control", "(none)", "scalarDot", "vectorDot",
      findNs(j28, "scalarDot[n=1024]"), findNs(j28, "vectorDot[n=1024]"),
      findAlloc(j28, "scalarDot[n=1024]"), findAlloc(j28, "vectorDot[n=1024]"),
      "YES_no_JP", "Vector_API", "J28_VectorVsScalar.jsonl");

    arr.append("\n]\n");
    String meta = String.format(Locale.ROOT,
      "{\n  \"jdk\": \"%s\",\n  \"jmh_results_dir\": \"%s\",\n  \"generated\": \"%s\",\n  \"cases\": %s}\n",
      jdk(j20), res, DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(ZonedDateTime.now()), arr);
    Files.writeString(outDir.resolve("static-vs-hotspot.json"), meta);
    Files.write(outDir.resolve("static-vs-hotspot.jsonl"), lines);
    System.out.println("wrote " + outDir.resolve("static-vs-hotspot.json"));
    System.out.println("wrote " + outDir.resolve("static-vs-hotspot.jsonl"));
  }
}
