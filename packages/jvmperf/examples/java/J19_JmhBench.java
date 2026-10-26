import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * JMH benchmark template. Compilation needs jmh-core and jmh-generator-annprocess to generate benchmark stubs.
 * After packaging with Maven or Gradle, run: java -jar benchmarks.jar J19_JmhBench -prof gc
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Benchmark)
public class J19_JmhBench {
    @Param({"1000", "100000"}) int n;
    int[] prim;
    // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
    List<Integer> boxed;

    @Setup public void setup() {
        prim = new int[n];
        boxed = new ArrayList<>(n);
        for (int i = 0; i < n; i++) { prim[i] = i; boxed.add(i); }
    }
    @Benchmark public long primitive() { long s = 0; for (int x : prim) s += x; return s; }   // Return the result to prevent dead-code elimination.
    @Benchmark public long boxedList() { long s = 0; for (Integer x : boxed) s += x; return s; }
    @Benchmark public void consume(Blackhole bh) { for (int x : prim) bh.consume(x); }
}
