package com.jvmperf.lint;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public final class Cli {
    public static final int EXIT_OK = 0, EXIT_FINDINGS = 1, EXIT_ERROR = 2;
    static final Set<String> SKIP_DIRS = Set.of(
            ".git", ".gradle", ".idea", "build", "out", "target", "node_modules", ".kotlin");
    static final int PARALLEL_MIN_FILES = 32;

    private Cli() {}

    public static int main(String[] argv) {
        Args args;
        try {
            args = Args.parse(argv);
        } catch (UsageException e) {
            if (e.message != null) System.err.println(e.message);
            return e.exit;
        }
        LintConfig.CONFIG.reset();
        LintConfig.CONFIG.includeTests = args.includeTests;
        LintConfig.CONFIG.strictStdioInLoop = args.strictStdioInLoop;
        LintConfig.CONFIG.scopeAll = args.scopeAll;

        if (args.listRules) {
            listRules(System.out);
            return EXIT_OK;
        }
        if (args.paths.isEmpty()) {
            System.err.println("usage: jvmperf-lint [options] <file-or-directory>...");
            System.err.println("jvmperf-lint: 需要至少一个文件或目录");
            return EXIT_ERROR;
        }

        List<String> bad = new ArrayList<>();
        Set<String> enabled = args.enable.isBlank()
                ? Rule.RULES.stream()
                    .filter(r -> !"off".equals(r.severity()))
                    .map(Rule::code)
                    .collect(Collectors.toCollection(HashSet::new))
                : parseRuleList(args.enable, bad);
        enabled.removeAll(parseRuleList(args.disable, bad));
        if (!bad.isEmpty()) {
            System.err.println("jvmperf-lint: 未知规则: " + String.join(", ", bad));
            return EXIT_ERROR;
        }

        if (!args.hotFn.isBlank()) {
            try {
                HotConfig.CONFIG.hotFnRe = Pattern.compile(args.hotFn);
            } catch (Exception e) {
                System.err.println("jvmperf-lint: --hot-fn 正则无效: " + e.getMessage());
                return EXIT_ERROR;
            }
        }
        for (String x : args.hotCallbacks.split(",")) {
            String t = x.strip();
            if (!t.isEmpty()) HotConfig.CONFIG.callbacks.add(t);
        }
        HotConfig.CONFIG.propagate = !args.noHotPropagation;

        List<Path> files = iterFiles(args.paths, args.includeTests);
        int jobs = args.jobs > 0 ? args.jobs : Math.max(1, Runtime.getRuntime().availableProcessors());
        HotConfig.CONFIG.external = new HashMap<>();
        if (HotConfig.CONFIG.propagate && files.size() > 1) {
            for (Map<HotAnalysis.ClassFn, String> exports : map(files, jobs, Cli::exportJob)) {
                for (var e : exports.entrySet()) HotConfig.CONFIG.external.putIfAbsent(e.getKey(), e.getValue());
            }
        }

        List<Finding> findings = new ArrayList<>();
        List<Path> scanned = new ArrayList<>();
        List<Map<String, Object>> parseDiagnostics = new ArrayList<>();
        List<Map<String, Object>> analysisErrors = new ArrayList<>();
        boolean ioError = false, parseIssue = false;
        List<LintOutcome> outcomes = map(files, jobs, p -> lintJob(p, enabled));
        for (int i = 0; i < files.size(); i++) {
            Path path = files.get(i);
            LintOutcome o = outcomes.get(i);
            if ("skip".equals(o.status)) {
                System.err.println("jvmperf-lint: 跳过不支持的文件: " + path);
                continue;
            }
            if ("ioerr".equals(o.status)) {
                System.err.println("jvmperf-lint: 无法读取 " + path + ": " + o.error);
                Map<String, Object> err = new LinkedHashMap<>();
                err.put("file", path.toString());
                err.put("error", o.error != null ? o.error : "ioerr");
                analysisErrors.add(err);
                if (!args.noFail) ioError = true;
                continue;
            }
            scanned.add(path);
            if (o.syntaxCount > 0) {
                parseIssue = true;
                Map<String, Object> diagnostic = new LinkedHashMap<>();
                diagnostic.put("file", path.toString());
                diagnostic.put("count", o.syntaxCount);
                diagnostic.put("locations", o.locations);
                parseDiagnostics.add(diagnostic);
                System.err.println("jvmperf-lint: 注意 " + path + " 含 " + o.syntaxCount + " 处无法解析的语法（容错解析，结果可能不完整）");
                for (int j = 0; j < Math.min(5, o.locations.size()); j++) {
                    Map<String, Object> loc = o.locations.get(j);
                    System.err.println("  " + path + ":" + loc.get("line") + ":" + loc.get("column") + ": " + loc.get("kind"));
                }
                if (o.syntaxCount > 5) System.err.println("  ……另有 " + (o.syntaxCount - 5) + " 处");
            }
            findings.addAll(o.findings);
        }

        Map<String, Map<String, Integer>> sourceSummary = new LinkedHashMap<>();
        for (String g : Constants.SOURCE_GROUPS) {
            Map<String, Integer> m = new LinkedHashMap<>();
            m.put("files", 0);
            m.put("findings", 0);
            sourceSummary.put(g, m);
        }
        for (Path p : scanned) sourceSummary.get(Engine.sourceGroup(p.toString())).merge("files", 1, Integer::sum);
        for (Finding f : findings) sourceSummary.get(Engine.sourceGroup(f.file())).merge("findings", 1, Integer::sum);

        if ("json".equals(args.format)) {
            Map<String, Object> root = new LinkedHashMap<>();
            root.put("tool", "jvmperf-lint");
            root.put("files", scanned.size());
            root.put("count", findings.size());
            root.put("findings", findings.stream().map(Finding::toMap).toList());
            root.put("source_summary", sourceSummary);
            root.put("parse_issues", parseDiagnostics);
            root.put("analysis_errors", analysisErrors);
            Gson gson = new GsonBuilder().disableHtmlEscaping().setPrettyPrinting().create();
            System.out.println(gson.toJson(root));
        } else {
            for (Finding f : findings) {
                Map<String, Object> d = f.toMap();
                System.out.printf(Locale.ROOT, "%s:%s:%s: %s[%s %s] %s / %s: %s%n    建议: %s%n",
                        d.get("file"), d.get("line"), d.get("column"), d.get("severity"),
                        d.get("rule"), d.get("name"), d.get("message_zh"), d.get("message_en"),
                        d.get("detail"), d.get("fix"));
            }
            long err = findings.stream().filter(f -> "error".equals(Rule.BY_CODE.get(f.rule()).severity())).count();
            long w = findings.stream().filter(f -> "warning".equals(Rule.BY_CODE.get(f.rule()).severity())).count();
            long info = findings.stream().filter(f -> "info".equals(Rule.BY_CODE.get(f.rule()).severity())).count();
            long hint = findings.stream().filter(f -> "hint".equals(Rule.BY_CODE.get(f.rule()).severity())).count();
            System.out.printf(Locale.ROOT, "%n共检查 %d 个文件，发现 %d 处（error %d, warning %d, info %d, hint %d）%n",
                    scanned.size(), findings.size(), err, w, info, hint);
            System.out.println("源码分组：" + Arrays.stream(Constants.SOURCE_GROUPS)
                    .map(g -> g + " " + sourceSummary.get(g).get("files") + " 个文件 / "
                            + sourceSummary.get(g).get("findings") + " 处")
                    .collect(Collectors.joining("；")));
        }

        if (ioError || (args.strictParse && parseIssue)) return EXIT_ERROR;
        if (!findings.isEmpty() && !args.noFail) return EXIT_FINDINGS;
        return EXIT_OK;
    }

    static void listRules(PrintStream out) {
        for (Rule r : Rule.RULES) {
            String langs = r.langs().stream()
                    .map(l -> "java".equals(l) ? "Java" : "Kotlin")
                    .collect(Collectors.joining("/"));
            out.printf(Locale.ROOT, "%s  %-30s %-8s [%s] %s / %s%n",
                    r.code(), r.name(), r.severity(), langs, r.msgZh(), r.msgEn());
            out.println("       修复: " + r.fix());
            out.println("       误报风险: " + r.fpRisk());
        }
    }

    static Set<String> parseRuleList(String spec, List<String> err) {
        Set<String> out = new HashSet<>();
        for (String tok : spec.split(",")) {
            if (tok.isBlank()) continue;
            var r = Rule.parse(tok);
            if (r.isEmpty()) err.add(tok);
            else out.add(r.get().code());
        }
        return out;
    }

    static List<Path> iterFiles(List<String> paths, boolean includeTests) {
        List<Path> out = new ArrayList<>();
        for (String p : paths) {
            Path path = Path.of(p);
            if (Files.isDirectory(path)) {
                try (Stream<Path> s = Files.walk(path)) {
                    s.filter(Files::isRegularFile)
                            .filter(f -> {
                                for (Path part : f) if (SKIP_DIRS.contains(part.toString())) return false;
                                if (Engine.langOf(f.toString()) == null) return false;
                                if (!includeTests && "test".equals(Engine.sourceGroup(f.toString()))) return false;
                                return true;
                            })
                            .sorted()
                            .forEach(out::add);
                } catch (IOException e) {
                    // treat as missing later via lint job
                    out.add(path);
                }
            } else {
                // Explicit file paths are always linted (fixtures, single-file invokes).
                out.add(path);
            }
        }
        return out;
    }

    static Map<HotAnalysis.ClassFn, String> exportJob(Path path) {
        if ("test".equals(Engine.sourceGroup(path.toString()))) return Map.of();
        String lang = Engine.langOf(path.toString());
        if (lang == null) return Map.of();
        try {
            byte[] src = Files.readAllBytes(path);
            return Engine.collectHotExports(path.toString(), src, lang);
        } catch (IOException | RuntimeException e) {
            return Map.of();
        }
    }

    record LintOutcome(String status, List<Finding> findings, int syntaxCount,
                       List<Map<String, Object>> locations, String error) {}

    static LintOutcome lintJob(Path path, Set<String> enabled) {
        String lang = Engine.langOf(path.toString());
        if (lang == null) return new LintOutcome("skip", List.of(), 0, List.of(), null);
        try {
            byte[] src = Files.readAllBytes(path);
            Result res = Engine.lintSource(path.toString(), src, lang, enabled);
            return new LintOutcome("ok", res.findings, res.syntaxErrors, res.syntaxErrorLocations, null);
        } catch (IOException e) {
            return new LintOutcome("ioerr", List.of(), 0, List.of(), e.getMessage());
        } catch (RuntimeException e) {
            return new LintOutcome("ioerr", List.of(), 0, List.of(), e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    static <T, R> List<R> map(List<T> items, int jobs, java.util.function.Function<T, R> fn) {
        if (jobs <= 1 || items.size() < PARALLEL_MIN_FILES) {
            List<R> out = new ArrayList<>(items.size());
            for (T x : items) out.add(fn.apply(x));
            return out;
        }
        ExecutorService pool = Executors.newFixedThreadPool(jobs);
        try {
            List<Future<R>> futures = new ArrayList<>();
            for (T x : items) futures.add(pool.submit((Callable<R>) () -> fn.apply(x)));
            List<R> out = new ArrayList<>(items.size());
            for (Future<R> f : futures) out.add(f.get());
            return out;
        } catch (Exception e) {
            throw new RuntimeException(e);
        } finally {
            pool.shutdownNow();
        }
    }

    static final class UsageException extends Exception {
        final int exit;
        final String message;
        UsageException(int exit, String message) { this.exit = exit; this.message = message; }
    }

    static final class Args {
        List<String> paths = new ArrayList<>();
        String format = "text";
        String enable = "", disable = "";
        boolean noFail, strictParse, listRules, noHotPropagation;
        boolean includeTests, strictStdioInLoop;
        boolean scopeAll = true;
        String hotFn = "", hotCallbacks = "";
        int jobs;

        static Args parse(String[] argv) throws UsageException {
            Args a = new Args();
            for (int i = 0; i < argv.length; i++) {
                String s = argv[i];
                switch (s) {
                    case "-h", "--help" -> throw new UsageException(EXIT_OK, help());
                    case "--list-rules" -> a.listRules = true;
                    case "--no-fail" -> a.noFail = true;
                    case "--strict-parse" -> a.strictParse = true;
                    case "--no-hot-propagation" -> a.noHotPropagation = true;
                    case "--include-tests" -> a.includeTests = true;
                    case "--strict-stdio-in-loop" -> a.strictStdioInLoop = true;
                    case "--scope" -> {
                        String v = need(argv, ++i, s);
                        if ("all".equals(v)) a.scopeAll = true;
                        else if ("loop".equals(v)) a.scopeAll = false;
                        else throw new UsageException(EXIT_ERROR, "jvmperf-lint: --scope all|loop");
                    }
                    case "-f", "--format" -> a.format = need(argv, ++i, s);
                    case "--enable" -> a.enable = need(argv, ++i, s);
                    case "--disable" -> a.disable = need(argv, ++i, s);
                    case "--hot-fn" -> a.hotFn = need(argv, ++i, s);
                    case "--hot-callbacks" -> a.hotCallbacks = need(argv, ++i, s);
                    case "-j", "--jobs" -> a.jobs = Integer.parseInt(need(argv, ++i, s));
                    default -> {
                        if (s.startsWith("-")) throw new UsageException(EXIT_ERROR, "jvmperf-lint: 未知选项: " + s);
                        a.paths.add(s);
                    }
                }
            }
            if (!"text".equals(a.format) && !"json".equals(a.format))
                throw new UsageException(EXIT_ERROR, "jvmperf-lint: -f 仅支持 text|json");
            return a;
        }

        static String need(String[] argv, int i, String opt) throws UsageException {
            if (i >= argv.length) throw new UsageException(EXIT_ERROR, "jvmperf-lint: " + opt + " 需要参数");
            return argv[i];
        }

        static String help() {
            return """
                    usage: jvmperf-lint [options] <file-or-directory>...
                    -f, --format text|json
                    --enable/--disable RULES   (default skips severity=off)
                    --strict-parse --hot-fn REGEX --hot-callbacks NAMES
                    --no-hot-propagation -j N --list-rules --no-fail
                    --include-tests              Also scan source_group=test (skipped by default)
                    --strict-stdio-in-loop       Flag System.out/err and Kotlin print/println in loops
                    --scope all|loop             Default all; loop = former in-loop-only matching
                    """;
        }
    }
}
