package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.LongAdder;

/**
 * Comparative: adjacent volatile counters (false sharing) vs @Contended padding vs LongAdder.
 * Guide §10.1. Two writer threads bump distinct counters; measure group throughput.
 *
 * Requires runtime -XX:-RestrictContended (set via @Fork) and compile-time
 * --add-exports java.base/jdk.internal.vm.annotation=ALL-UNNAMED.
 */
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {
        "-XX:+UseCompactObjectHeaders",
        "-XX:-RestrictContended"
})
public class J22_FalseSharing {

    @State(Scope.Group)
    public static class Unpadded {
        volatile long a;
        volatile long b;
    }

    @State(Scope.Group)
    public static class ContendedPadded {
        @jdk.internal.vm.annotation.Contended
        volatile long a;
        @jdk.internal.vm.annotation.Contended
        volatile long b;
    }

    /** Manual ~128 B gap between a and b (layout not guaranteed, but typical on HotSpot). */
    @State(Scope.Group)
    public static class ManualPadded {
        volatile long a;
        long p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14;
        volatile long b;
    }

    @State(Scope.Benchmark)
    public static class AdderState {
        final LongAdder adder = new LongAdder();
    }

    @Benchmark
    @Group("unpadded")
    @GroupThreads(1)
    public void unpaddedWriterA(Unpadded s) {
        s.a++;
    }

    @Benchmark
    @Group("unpadded")
    @GroupThreads(1)
    public void unpaddedWriterB(Unpadded s) {
        s.b++;
    }

    @Benchmark
    @Group("contended")
    @GroupThreads(1)
    public void contendedWriterA(ContendedPadded s) {
        s.a++;
    }

    @Benchmark
    @Group("contended")
    @GroupThreads(1)
    public void contendedWriterB(ContendedPadded s) {
        s.b++;
    }

    @Benchmark
    @Group("manualPad")
    @GroupThreads(1)
    public void manualWriterA(ManualPadded s) {
        s.a++;
    }

    @Benchmark
    @Group("manualPad")
    @GroupThreads(1)
    public void manualWriterB(ManualPadded s) {
        s.b++;
    }

    /** Shared LongAdder: Cells are @Contended inside the JDK. Two threads increment. */
    @Benchmark
    @Group("longAdder")
    @GroupThreads(2)
    public void longAdderInc(AdderState s) {
        s.adder.increment();
    }
}
