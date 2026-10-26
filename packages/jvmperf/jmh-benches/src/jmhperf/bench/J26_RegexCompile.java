package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;

/**
 * Comparative: Pattern.compile inside the hot path vs static final Pattern.
 * Guide §6.3. Each op splits {@code lines} strings on whitespace.
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J26_RegexCompile {

    private static final Pattern WS = Pattern.compile("\\s+");

    @Param({"64", "1024"})
    int lines;

    String[] input;

    @Setup
    public void setup() {
        input = new String[lines];
        for (int i = 0; i < lines; i++) {
            input[i] = "word" + (i % 10) + "  mid" + (i % 7) + "\tend";
        }
    }

    @Benchmark
    public int compileEachCall() {
        String[] in = input;
        int n = 0;
        for (int i = 0; i < in.length; i++) {
            n += Pattern.compile("\\s+").split(in[i]).length;
        }
        return n;
    }

    @Benchmark
    public int staticFinalPattern() {
        String[] in = input;
        int n = 0;
        for (int i = 0; i < in.length; i++) {
            n += WS.split(in[i]).length;
        }
        return n;
    }
}
