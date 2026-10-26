package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.util.ArrayList;
import java.util.concurrent.TimeUnit;

/**
 * Comparative: ArrayList grow-from-default vs new ArrayList<>(n).
 * Guide §5.2. Each op fills N Integer elements (boxes intentionally).
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J25_Presize {
    @Param({"10000", "100000"})
    int n;

    @Benchmark
    public int growFromDefault() {
        ArrayList<Integer> list = new ArrayList<>();
        int lim = n;
        for (int i = 0; i < lim; i++) {
            list.add(i);
        }
        return list.size();
    }

    @Benchmark
    public int presized() {
        int lim = n;
        ArrayList<Integer> list = new ArrayList<>(lim);
        for (int i = 0; i < lim; i++) {
            list.add(i);
        }
        return list.size();
    }
}
