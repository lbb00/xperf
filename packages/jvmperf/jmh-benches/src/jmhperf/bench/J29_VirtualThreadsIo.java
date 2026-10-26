package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;
import java.util.concurrent.locks.LockSupport;

/**
 * Comparative: platform-thread pool vs virtual threads for N short parkNanos waits.
 * Guide §10.2 — blocked/I-O-bound style work (local park, no network).
 * Each op submits {@code tasks} parkNanos(100_000) jobs and joins them all.
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.MILLISECONDS)
@Warmup(iterations = 3, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Benchmark)
public class J29_VirtualThreadsIo {

    @Param({"1000", "10000"})
    int tasks;

    static final long PARK_NS = 100_000L; // 0.1 ms

    ExecutorService platformPool;

    @Setup(Level.Trial)
    public void setup() {
        int cores = Math.max(2, Runtime.getRuntime().availableProcessors());
        platformPool = Executors.newFixedThreadPool(cores);
    }

    @TearDown(Level.Trial)
    public void tearDown() {
        if (platformPool != null) {
            platformPool.shutdownNow();
        }
    }

    @Benchmark
    public int platformPoolPark() throws Exception {
        int n = tasks;
        List<Future<?>> futures = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            futures.add(platformPool.submit(() -> LockSupport.parkNanos(PARK_NS)));
        }
        for (Future<?> f : futures) {
            f.get();
        }
        return n;
    }

    @Benchmark
    public int virtualThreadsPark() throws Exception {
        int n = tasks;
        List<Thread> threads = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            threads.add(Thread.startVirtualThread(() -> LockSupport.parkNanos(PARK_NS)));
        }
        for (Thread t : threads) {
            t.join();
        }
        return n;
    }
}
