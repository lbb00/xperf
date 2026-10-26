package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.http.HttpClient;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicIntegerFieldUpdater;
import java.util.stream.Collectors;

/**
 * Evidence micros for remaining JP rules (batch). Guide / evidence-policy 2026-10-21.
 * Shorter warmup than J20-series so the batch finishes; still honest before/after.
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 3, time = 300, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 5, time = 400, timeUnit = TimeUnit.MILLISECONDS)
@Fork(value = 1, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J32_RuleEvidenceBatch {

    // ---- jp-boxed-stream boxed-stream ----
    @State(Scope.Thread)
    public static class BoxedStream {
        List<Integer> xs;
        @Setup
        public void setup() {
            xs = new ArrayList<>(10_000);
            for (int i = 0; i < 10_000; i++) xs.add(i + 1000);
        }
    }

    @Benchmark
    public int jp006_boxedReduce(BoxedStream s) {
        return s.xs.stream().map(x -> x * 2).reduce(0, Integer::sum);
    }

    @Benchmark
    public int jp006_mapToInt(BoxedStream s) {
        return s.xs.stream().mapToInt(x -> x * 2).sum();
    }

    @Benchmark
    public long jp006_summingLong(BoxedStream s) {
        return s.xs.stream().collect(Collectors.summingLong(Integer::longValue));
    }

    @Benchmark
    public long jp006_mapToLong(BoxedStream s) {
        return s.xs.stream().mapToLong(Integer::longValue).sum();
    }

    // ---- jp-exception-control-flow exception control flow ----
    @State(Scope.Thread)
    public static class ParseStrings {
        String[] xs;
        @Setup
        public void setup() {
            xs = new String[2000];
            for (int i = 0; i < xs.length; i++) {
                xs[i] = (i % 5 == 0) ? "nope" : Integer.toString(i);
            }
        }
    }

    @Benchmark
    public int jp007_tryParse(ParseStrings s) {
        int n = 0;
        for (String x : s.xs) {
            try {
                Integer.parseInt(x);
                n++;
            } catch (NumberFormatException e) {
                // control flow
            }
        }
        return n;
    }

    @Benchmark
    public int jp007_digitCheck(ParseStrings s) {
        int n = 0;
        for (String x : s.xs) {
            if (isDigits(x)) n++;
        }
        return n;
    }

    private static boolean isDigits(String s) {
        if (s.isEmpty()) return false;
        for (int i = 0; i < s.length(); i++) {
            if (!Character.isDigit(s.charAt(i))) return false;
        }
        return true;
    }

    // ---- jp-legacy-synchronized-type StringBuffer vs StringBuilder / Hashtable ----
    @Benchmark
    public String jp008_stringBuffer() {
        StringBuffer sb = new StringBuffer();
        for (int i = 0; i < 256; i++) sb.append(i).append(',');
        return sb.toString();
    }

    @Benchmark
    public String jp008_stringBuilder() {
        StringBuilder sb = new StringBuilder(1024);
        for (int i = 0; i < 256; i++) sb.append(i).append(',');
        return sb.toString();
    }

    @State(Scope.Thread)
    public static class Maps {
        Hashtable<String, Integer> ht = new Hashtable<>();
        ConcurrentHashMap<String, Integer> chm = new ConcurrentHashMap<>();
        String[] keys;
        @Setup
        public void setup() {
            keys = new String[256];
            for (int i = 0; i < keys.length; i++) keys[i] = "k" + i;
        }
    }

    @Benchmark
    public int jp008_hashtablePut(Maps m) {
        m.ht.clear();
        for (String k : m.keys) m.ht.put(k, 1);
        return m.ht.size();
    }

    @Benchmark
    public int jp008_chmPut(Maps m) {
        m.chm.clear();
        for (String k : m.keys) m.chm.put(k, 1);
        return m.chm.size();
    }

    // ---- jp-enum-key-hash-collection EnumMap vs HashMap ----
    enum Color { RED, GREEN, BLUE, YELLOW, CYAN, MAGENTA, WHITE, BLACK }

    @State(Scope.Thread)
    public static class EnumMaps {
        Map<Color, Integer> hash = new HashMap<>();
        EnumMap<Color, Integer> enm = new EnumMap<>(Color.class);
        Color[] keys = Color.values();
    }

    @Benchmark
    public int jp010_hashMapPutGet(EnumMaps s) {
        s.hash.clear();
        for (Color c : s.keys) s.hash.put(c, c.ordinal());
        int sum = 0;
        for (Color c : s.keys) sum += s.hash.get(c);
        return sum;
    }

    @Benchmark
    public int jp010_enumMapPutGet(EnumMaps s) {
        s.enm.clear();
        for (Color c : s.keys) s.enm.put(c, c.ordinal());
        int sum = 0;
        for (Color c : s.keys) sum += s.enm.get(c);
        return sum;
    }

    // ---- jp-log-in-loop log concat always vs guarded ----
    @State(Scope.Thread)
    public static class FakeLog {
        volatile boolean debug;
        long sink;
        void debug(String msg) { sink += msg.length(); }
        boolean isDebugEnabled() { return debug; }
        int[] xs;
        @Setup
        public void setup() {
            xs = new int[1000];
            for (int i = 0; i < xs.length; i++) xs[i] = i;
            debug = false; // typical production: debug off
        }
    }

    @Benchmark
    public long jp017_concatAlways(FakeLog log) {
        log.sink = 0;
        for (int x : log.xs) log.debug("x=" + x);
        return log.sink;
    }

    @Benchmark
    public long jp017_guarded(FakeLog log) {
        log.sink = 0;
        for (int x : log.xs) {
            if (log.isDebugEnabled()) log.debug("x=" + x);
        }
        return log.sink;
    }

    // ---- jp-baos-tobytearray-copy BAOS toByteArray vs writeTo ----
    @State(Scope.Thread)
    public static class Baos {
        byte[] raw;
        ByteArrayOutputStream reusable = new ByteArrayOutputStream(1 << 16);
        CountingOut sink = new CountingOut();
        @Setup
        public void setup() {
            raw = new byte[4096];
            new Random(1).nextBytes(raw);
        }
    }

    static final class CountingOut extends OutputStream {
        long n;
        @Override public void write(int b) { n++; }
        @Override public void write(byte[] b, int off, int len) { n += len; }
    }

    @Benchmark
    public long jp027_toByteArray(Baos s) throws IOException {
        s.sink.n = 0;
        ByteArrayOutputStream baos = new ByteArrayOutputStream(s.raw.length);
        baos.write(s.raw);
        s.sink.write(baos.toByteArray());
        return s.sink.n;
    }

    @Benchmark
    public long jp027_writeTo(Baos s) throws IOException {
        s.sink.n = 0;
        s.reusable.reset();
        s.reusable.write(s.raw);
        s.reusable.writeTo(s.sink);
        return s.sink.n;
    }

    // ---- jp-hot-payload-copy hot payload copy ----
    @State(Scope.Thread)
    public static class Payload {
        byte[] payload;
        byte[] reuse;
        CountingOut out = new CountingOut();
        @Setup
        public void setup() {
            payload = new byte[1024];
            reuse = new byte[4 + 1024];
            new Random(2).nextBytes(payload);
        }
    }

    @Benchmark
    public long jp028_newFrameEach(Payload s) throws IOException {
        s.out.n = 0;
        byte[] frame = new byte[4 + s.payload.length];
        System.arraycopy(s.payload, 0, frame, 4, s.payload.length);
        s.out.write(frame);
        return s.out.n;
    }

    @Benchmark
    public long jp028_reuseBuffer(Payload s) throws IOException {
        s.out.n = 0;
        System.arraycopy(s.payload, 0, s.reuse, 4, s.payload.length);
        s.out.write(s.reuse, 0, 4 + s.payload.length);
        return s.out.n;
    }

    // ---- jp-client-factory-recreate client factory (real JDK HttpClient) ----
    @Benchmark
    public HttpClient jp030_newEach() {
        HttpClient client = HttpClient.newHttpClient();
        client.close();
        return client;
    }

    @State(Scope.Benchmark)
    public static class SharedClient {
        HttpClient client = HttpClient.newHttpClient();
    }

    @Benchmark
    public HttpClient jp030_reuse(SharedClient s) {
        return s.client;
    }

    // ---- jp-string-intern-in-loop string.intern in loop ----
    @State(Scope.Thread)
    public static class Intern {
        String[] xs;
        Set<String> out = new HashSet<>();
        @Setup
        public void setup() {
            xs = new String[2000];
            for (int i = 0; i < xs.length; i++) {
                // unique strings each setup — intern table pressure
                xs[i] = ("tok-" + i + "-" + System.nanoTime()).substring(0, 12 + (i % 5));
            }
        }
    }

    @Benchmark
    public int jp031_intern(Intern s) {
        s.out.clear();
        for (String x : s.xs) s.out.add(x.intern());
        return s.out.size();
    }

    @Benchmark
    public int jp031_plain(Intern s) {
        s.out.clear();
        for (String x : s.xs) s.out.add(x);
        return s.out.size();
    }

    // ---- jp-non-static-field-updater FieldUpdater non-static vs static ----
    static final class Node {
        volatile int x;
        final AtomicIntegerFieldUpdater<Node> perInstance =
                AtomicIntegerFieldUpdater.newUpdater(Node.class, "x");
    }

    static final AtomicIntegerFieldUpdater<Node> STATIC_UPDATER =
            AtomicIntegerFieldUpdater.newUpdater(Node.class, "x");

    @State(Scope.Thread)
    public static class Updaters {
        Node[] nodes;
        @Setup
        public void setup() {
            nodes = new Node[256];
            for (int i = 0; i < nodes.length; i++) nodes[i] = new Node();
        }
    }

    @Benchmark
    public int jp032_perInstanceInc(Updaters s) {
        int v = 0;
        for (Node n : s.nodes) v += n.perInstance.incrementAndGet(n);
        return v;
    }

    @Benchmark
    public int jp032_staticInc(Updaters s) {
        int v = 0;
        for (Node n : s.nodes) v += STATIC_UPDATER.incrementAndGet(n);
        return v;
    }

    /** Creation cost: new updater each op vs reuse static (the real smell). */
    @Benchmark
    public AtomicIntegerFieldUpdater<Node> jp032_newUpdaterEach() {
        return AtomicIntegerFieldUpdater.newUpdater(Node.class, "x");
    }

    @Benchmark
    public AtomicIntegerFieldUpdater<Node> jp032_staticUpdater() {
        return STATIC_UPDATER;
    }
}
