package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;
import java.util.ArrayDeque;
import java.util.concurrent.TimeUnit;

/**
 * Comparative: TLAB {@code new Point} vs single-thread ArrayDeque object pool.
 * Guide §10.3 — pooling small objects is often slower than young-gen allocation.
 *
 * Objects are consumed via Blackhole so escape analysis cannot scalar-replace them.
 * Pool path resets fields and returns the instance (no synchronization; thread-scoped).
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J24_PoolVsAlloc {

    @Param({"1", "64", "1024"})
    int batch;

    static final class Point {
        int x, y;
        Point(int x, int y) {
            this.x = x;
            this.y = y;
        }
    }

    final ArrayDeque<Point> free = new ArrayDeque<>(256);

    @Setup(Level.Iteration)
    public void setup() {
        free.clear();
        // Pre-fill so pool path is mostly reuse, not first-time alloc.
        for (int i = 0; i < 256; i++) {
            free.push(new Point(0, 0));
        }
    }

    @Benchmark
    public void tlabAlloc(Blackhole bh) {
        int n = batch;
        for (int i = 0; i < n; i++) {
            bh.consume(new Point(i, i + 1));
        }
    }

    @Benchmark
    public void pooled(Blackhole bh) {
        int n = batch;
        ArrayDeque<Point> pool = free;
        for (int i = 0; i < n; i++) {
            Point p = pool.poll();
            if (p == null) {
                p = new Point(0, 0);
            }
            p.x = i;
            p.y = i + 1;
            bh.consume(p);
            pool.offer(p);
        }
    }
}
