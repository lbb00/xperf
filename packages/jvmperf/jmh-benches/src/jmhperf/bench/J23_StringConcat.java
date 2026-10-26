package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.util.concurrent.TimeUnit;

/**
 * Comparative: s += in loop vs StringBuilder (default vs presized).
 * Guide §6.2. Each op concatenates M short parts.
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J23_StringConcat {
    @Param({"64", "256"})
    int parts;

    String[] tokens;

    @Setup
    public void setup() {
        tokens = new String[parts];
        for (int i = 0; i < parts; i++) {
            tokens[i] = "tok" + (i % 10);
        }
    }

    @Benchmark
    public String plusEquals() {
        String s = "";
        String[] t = tokens;
        for (int i = 0; i < t.length; i++) {
            s += t[i];
        }
        return s;
    }

    @Benchmark
    public String stringBuilderDefault() {
        StringBuilder sb = new StringBuilder();
        String[] t = tokens;
        for (int i = 0; i < t.length; i++) {
            sb.append(t[i]);
        }
        return sb.toString();
    }

    @Benchmark
    public String stringBuilderPresized() {
        String[] t = tokens;
        int cap = 0;
        for (int i = 0; i < t.length; i++) {
            cap += t[i].length();
        }
        StringBuilder sb = new StringBuilder(cap);
        for (int i = 0; i < t.length; i++) {
            sb.append(t[i]);
        }
        return sb.toString();
    }
}
