package com.jvmperf.lint;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DynamicTest;
import org.junit.jupiter.api.TestFactory;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;

public class FixtureTest {
    static final Path ROOT = Path.of("").toAbsolutePath();
    static final Path FIX = ROOT.resolve("fixtures");
    static final Set<String> ALL = Rule.RULES.stream().map(Rule::code).collect(java.util.stream.Collectors.toSet());

    static Result lintFile(Path path, Set<String> enabled) throws IOException {
        byte[] src = Files.readAllBytes(path);
        return Engine.lintSource(path.toString(), src, Engine.langOf(path.toString()), enabled);
    }

    record CliRun(int code, String out, String err) {}

    static CliRun runCli(String... args) {
        PrintStream oldOut = System.out, oldErr = System.err;
        ByteArrayOutputStream out = new ByteArrayOutputStream(), err = new ByteArrayOutputStream();
        System.setOut(new PrintStream(out, true, StandardCharsets.UTF_8));
        System.setErr(new PrintStream(err, true, StandardCharsets.UTF_8));
        try {
            int code = Cli.main(args);
            return new CliRun(code, out.toString(StandardCharsets.UTF_8), err.toString(StandardCharsets.UTF_8));
        } finally {
            System.setOut(oldOut);
            System.setErr(oldErr);
        }
    }

    @Test
    void contextSensitiveRulesAreInformational() throws Exception {
        Map<String, Rule> by = Rule.BY_CODE;
        assertEquals("off", by.get("jp-log-hot").severity());
        assertEquals("off", by.get("jp-exception-control-flow").severity());
        for (String code : List.of("jp-exception-control-flow", "jp-log-hot")) {
            var findings = lintFile(FIX.resolve("bad").resolve(code + ".java"), ALL).findings;
            assertFalse(findings.isEmpty());
            assertTrue(findings.stream().allMatch(f -> "off".equals(f.toMap().get("severity"))));
        }
    }

    @Test
    void sourceGroupClassification() {
        assertEquals("production", Engine.sourceGroup("app/src/main/java/Foo.java"));
        assertEquals("test", Engine.sourceGroup("app/src/test/java/FooTest.java"));
        assertEquals("test", Engine.sourceGroup("app/host-test/src/Foo.kt"));
        assertEquals("smoke", Engine.sourceGroup("app/src/main/java/smoke/Foo.kt"));
        assertEquals("test", Engine.sourceGroup("okhttp/samples/guide/PostStreaming.java"));
        assertEquals("test", Engine.sourceGroup("lib/examples/demo/Foo.kt"));
    }

    @Test
    void defaultEnabledSkipsOffRules() {
        assertEquals("off", Rule.BY_CODE.get("jp-unpresized-collection").severity());
        assertEquals("off", Rule.BY_CODE.get("jp-boxed-primitive-collection").severity());
        assertEquals("off", Rule.BY_CODE.get("jp-format-hot").severity());
        assertEquals("error", Rule.BY_CODE.get("jp-data-copy-hot").severity());
        assertEquals("error", Rule.BY_CODE.get("jp-string-concat-hot").severity());
        assertEquals("error", Rule.BY_CODE.get("jp-hot-payload-copy").severity());
        CliRun r = runCli("--no-fail", "-f", "json", FIX.resolve("bad").resolve("jp-unpresized-collection.java").toString());
        JsonObject d = new Gson().fromJson(r.out, JsonObject.class);
        assertEquals(0, d.get("count").getAsInt(), "jp-unpresized-collection off by default: " + r.out);
        CliRun on = runCli("--no-fail", "-f", "json", "--enable", "jp-unpresized-collection", FIX.resolve("bad").resolve("jp-unpresized-collection.java").toString());
        JsonObject d2 = new Gson().fromJson(on.out, JsonObject.class);
        assertTrue(d2.get("count").getAsInt() > 0, on.out);
    }

    @Test
    void everyRuleHasBadAndGoodFixture() throws Exception {
        for (Rule r : Rule.RULES) {
            for (String kind : List.of("bad", "good")) {
                try (Stream<Path> s = Files.list(FIX.resolve(kind))) {
                    Set<String> exts = s.map(p -> p.getFileName().toString())
                            .filter(f -> f.startsWith(r.code() + "."))
                            .map(f -> f.substring(f.lastIndexOf('.') + 1))
                            .collect(java.util.stream.Collectors.toSet());
                    Set<String> want = r.langs().stream()
                            .map(l -> "java".equals(l) ? "java" : "kt")
                            .collect(java.util.stream.Collectors.toSet());
                    assertEquals(want, exts, kind + "/" + r.code());
                }
            }
        }
    }

    @TestFactory
    Stream<DynamicTest> badFixturesFireTheirRule() throws Exception {
        List<DynamicTest> tests = new ArrayList<>();
        try (Stream<Path> s = Files.list(FIX.resolve("bad")).sorted()) {
            for (Path f : s.toList()) {
                String code = f.getFileName().toString().split("\\.")[0];
                tests.add(DynamicTest.dynamicTest("bad/" + f.getFileName(), () -> {
                    Result res = lintFile(f, ALL);
                    assertTrue(res.findings.stream().anyMatch(x -> code.equals(x.rule())),
                            "bad/" + f.getFileName() + " 没有触发 " + code + " findings=" + res.findings);
                    assertEquals(0, res.syntaxErrors, "bad/" + f.getFileName() + " 解析出错");
                }));
            }
        }
        return tests.stream();
    }

    @TestFactory
    Stream<DynamicTest> goodFixturesAreClean() throws Exception {
        List<DynamicTest> tests = new ArrayList<>();
        try (Stream<Path> s = Files.list(FIX.resolve("good")).sorted()) {
            for (Path f : s.toList()) {
                tests.add(DynamicTest.dynamicTest("good/" + f.getFileName(), () -> {
                    Result res = lintFile(f, ALL);
                    assertEquals(List.of(), res.findings.stream().map(x -> x.rule() + "@" + x.line() + ":" + x.detail()).toList());
                    assertEquals(0, res.syntaxErrors);
                }));
            }
        }
        return tests.stream();
    }

    @Test
    void ignoreComments() throws Exception {
        for (String f : List.of("ignore.java", "ignore.kt")) {
            Result res = lintFile(FIX.resolve(f), ALL);
            assertEquals(List.of(), res.findings.stream().map(x -> x.rule() + "@" + x.line()).toList());
        }
        byte[] src = Files.readAllBytes(FIX.resolve("ignore.java"));
        src = new String(src, StandardCharsets.UTF_8).replace("jvmperf-lint:", "nothing:").getBytes(StandardCharsets.UTF_8);
        assertTrue(Engine.lintSource("x.java", src, "java", ALL).findings.size() >= 4);
    }

    @Test
    void exitCodes() {
        assertEquals(1, runCli(FIX.resolve("bad").toString()).code);
        assertEquals(0, runCli(FIX.resolve("good").toString()).code);
        assertEquals(0, runCli("--no-fail", FIX.resolve("bad").toString()).code);
        assertEquals(2, runCli("--enable", "jp-does-not-exist", FIX.resolve("bad").toString()).code);
        assertEquals(2, runCli(FIX.resolve("does-not-exist.java").toString()).code);
        assertEquals(2, runCli().code);
    }

    @Test
    void disableByName() {
        assertEquals(0, runCli("--disable", "log-in-loop", FIX.resolve("bad/jp-log-hot.java").toString()).code);
    }

    @Test
    void json() {
        CliRun r = runCli("-f", "json", FIX.resolve("bad/jp-enum-key-hash-collection.kt").toString());
        assertEquals(1, r.code);
        JsonObject d = new Gson().fromJson(r.out, JsonObject.class);
        assertEquals("jvmperf-lint", d.get("tool").getAsString());
        assertEquals(d.get("count").getAsInt(), d.getAsJsonArray("findings").size());
        assertTrue(d.getAsJsonArray("findings").get(0).getAsJsonObject().has("source_group"));
        assertTrue(d.has("source_summary"));
    }

    @Test
    void listRules() {
        CliRun r = runCli("--list-rules");
        assertEquals(0, r.code);
        assertEquals(Rule.RULES.size(), r.out.split("误报风险", -1).length - 1);
    }

    @Test
    void strictParse() throws Exception {
        Path bad = ROOT.resolve("src/test/resources/_broken.java");
        Files.createDirectories(bad.getParent());
        Files.writeString(bad, "class X { void f( { }");
        try {
            assertEquals(0, runCli(bad.toString()).code);
            assertEquals(2, runCli("--strict-parse", bad.toString()).code);
        } finally {
            Files.deleteIfExists(bad);
        }
    }

    @Test
    void hotFnRegex() {
        Path d = FIX.resolve("hot_xfile/Codec.kt");
        CliRun r = runCli("-f", "json", "--no-fail", "--hot-fn", "^write$", d.toString());
        JsonObject js = new Gson().fromJson(r.out, JsonObject.class);
        boolean hit = false;
        for (var el : js.getAsJsonArray("findings")) {
            if ("jp-hot-payload-copy".equals(el.getAsJsonObject().get("rule").getAsString())) hit = true;
        }
        assertTrue(hit, r.out);
        HotConfig.CONFIG.hotFnRe = null;
    }

    @Test
    void crossFilePropagation() {
        Path d = FIX.resolve("hot_xfile");
        CliRun r = runCli("-f", "json", "--no-fail", d.toString());
        JsonObject js = new Gson().fromJson(r.out, JsonObject.class);
        List<JsonObject> hits = new ArrayList<>();
        for (var el : js.getAsJsonArray("findings")) {
            if ("jp-hot-payload-copy".equals(el.getAsJsonObject().get("rule").getAsString())) hits.add(el.getAsJsonObject());
        }
        assertEquals(1, hits.size(), r.out);
        assertTrue(hits.get(0).get("detail").getAsString().contains("onJpeg = {}"));
        assertTrue(hits.get(0).get("detail").getAsString().contains("Codec.write → encode"));
        CliRun r2 = runCli("-f", "json", "--no-fail", "--no-hot-propagation", d.toString());
        JsonObject js2 = new Gson().fromJson(r2.out, JsonObject.class);
        long n = 0;
        for (var el : js2.getAsJsonArray("findings"))
            if ("jp-hot-payload-copy".equals(el.getAsJsonObject().get("rule").getAsString())) n++;
        assertEquals(0, n);
    }

    @Test
    void benchmarkPathsSkippedByDefault() throws Exception {
        Path tmp = Files.createTempDirectory("jvmperf-bench-skip");
        try {
            Path bench = tmp.resolve("benchmark/src/main/java");
            Files.createDirectories(bench);
            Files.writeString(bench.resolve("Bench.java"),
                    "class Bench { java.util.List<Integer> xs; }\n");
            Path jvmTest = tmp.resolve("src/jvmTest/kotlin");
            Files.createDirectories(jvmTest);
            Files.writeString(jvmTest.resolve("Host.kt"),
                    "class Host { val xs: List<Int> = listOf(1) }\n");
            CliRun skipped = runCli("-f", "json", "--no-fail", tmp.toString());
            assertEquals(0, skipped.code, skipped.err);
            var d0 = new Gson().fromJson(skipped.out, JsonObject.class);
            assertEquals(0, d0.get("files").getAsInt(), skipped.out);
            CliRun included = runCli("-f", "json", "--no-fail", "--include-tests", tmp.toString());
            assertEquals(0, included.code, included.err);
            var d1 = new Gson().fromJson(included.out, JsonObject.class);
            assertTrue(d1.get("files").getAsInt() >= 2, included.out);
        } finally {
            try (Stream<Path> s = Files.walk(tmp)) {
                s.sorted(java.util.Comparator.reverseOrder()).forEach(x -> {
                    try { Files.deleteIfExists(x); } catch (IOException ignored) {}
                });
            }
            LintConfig.CONFIG.reset();
        }
    }

    @Test
    void includeTestsFlag() throws Exception {
        Path tmp = Files.createTempDirectory("jvmperf-include-tests");
        try {
            Path testDir = tmp.resolve("src/test/java");
            Files.createDirectories(testDir);
            Path f = testDir.resolve("Noise.java");
            Files.writeString(f, """
                    class Noise {
                      String build(int n) {
                        String s = "";
                        for (int i = 0; i < n; i++) s += i;
                        return s;
                      }
                    }
                    """);
            CliRun skipped = runCli("-f", "json", "--no-fail", tmp.toString());
            assertEquals(0, skipped.code, skipped.err);
            var d0 = new Gson().fromJson(skipped.out, JsonObject.class);
            assertEquals(0, d0.get("files").getAsInt(), skipped.out);
            CliRun included = runCli("-f", "json", "--no-fail", "--include-tests", tmp.toString());
            assertEquals(0, included.code, included.err);
            var d1 = new Gson().fromJson(included.out, JsonObject.class);
            assertEquals(1, d1.get("files").getAsInt(), included.out);
            assertTrue(d1.get("count").getAsInt() >= 1, included.out);
        } finally {
            try (Stream<Path> s = Files.walk(tmp)) {
                s.sorted(java.util.Comparator.reverseOrder()).forEach(x -> {
                    try { Files.deleteIfExists(x); } catch (IOException ignored) {}
                });
            }
            LintConfig.CONFIG.reset();
        }
    }

    @Test
    void noFailIgnoresIoErrors() {
        CliRun r = runCli("--no-fail", "-f", "json", FIX.resolve("does-not-exist.java").toString());
        assertEquals(0, r.code, r.err);
        JsonObject d = new Gson().fromJson(r.out, JsonObject.class);
        assertTrue(d.has("analysis_errors"));
        assertTrue(d.getAsJsonArray("analysis_errors").size() >= 1);
    }

    @Test
    void strictStdioInLoop() throws Exception {
        Path f = Files.createTempFile("stdio", ".java");
        try {
            Files.writeString(f, """
                    class StdioHot {
                        void process(int[] xs) {
                            for (int x : xs) System.out.println(x);
                        }
                    }
                    """);
            CliRun off = runCli("--no-fail", "-f", "json", f.toString());
            JsonObject d0 = new Gson().fromJson(off.out, JsonObject.class);
            assertEquals(0, d0.get("count").getAsInt(), off.out);
            CliRun on = runCli("--no-fail", "-f", "json", "--enable", "jp-log-hot", "--strict-stdio-in-loop", f.toString());
            JsonObject d1 = new Gson().fromJson(on.out, JsonObject.class);
            assertTrue(d1.get("count").getAsInt() >= 1, on.out);
        } finally {
            Files.deleteIfExists(f);
            LintConfig.CONFIG.reset();
        }
    }


    @Test
    void jp005TinyAndToStringSkipped() throws Exception {
        Result res = lintFile(FIX.resolve("good/jp-unpresized-collection.java"), ALL);
        assertTrue(res.findings.stream().noneMatch(f -> "jp-unpresized-collection".equals(f.rule())), res.findings.toString());
    }


    @Test
    void jp004ThrowFormatSkipped() throws Exception {
        Result res = lintFile(FIX.resolve("good/jp-format-hot.java"), ALL);
        assertTrue(res.findings.stream().noneMatch(f -> "jp-format-hot".equals(f.rule())), res.findings.toString());
    }


}
