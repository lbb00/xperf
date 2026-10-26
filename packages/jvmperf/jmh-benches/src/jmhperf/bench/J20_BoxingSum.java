package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * Comparative: int[] sum vs ArrayList&lt;Integer&gt; sum vs IntStream sum.
 * Guide §3.1. Each op sums N elements (setup builds containers once).
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J20_BoxingSum {

    @Param({"1000", "100000", "1000000"})
    int n;

    int[] prim;
    List<Integer> boxed;

    @Setup
    public void setup() {
        int lim = n;
        prim = new int[lim];
        // Values start at 1000 so Integer cache (-128..127) does not hide boxing cost at build time.
        boxed = new ArrayList<>(lim);
        for (int i = 0; i < lim; i++) {
            int v = i + 1000;
            prim[i] = v;
            boxed.add(v);
        }
    }

    @Benchmark
    public long sumIntArray() {
        int[] xs = prim;
        long s = 0;
        for (int i = 0; i < xs.length; i++) {
            s += xs[i];
        }
        return s;
    }

    @Benchmark
    public long sumArrayList() {
        List<Integer> xs = boxed;
        long s = 0;
        for (int i = 0, lim = xs.size(); i < lim; i++) {
            s += xs.get(i); // unbox
        }
        return s;
    }

    @Benchmark
    public long sumIntStream() {
        return Arrays.stream(prim).asLongStream().sum();
    }
}
