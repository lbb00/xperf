package jmhperf.bench;

import jdk.incubator.vector.FloatVector;
import jdk.incubator.vector.VectorOperators;
import jdk.incubator.vector.VectorSpecies;
import org.openjdk.jmh.annotations.*;
import java.util.concurrent.TimeUnit;

/**
 * Comparative: scalar float sum-of-products vs Vector API (incubator).
 * Guide §9.4. Requires --add-modules=jdk.incubator.vector at compile and run.
 * Each op computes sum_i a[i]*b[i] over N floats.
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {
        "-XX:+UseCompactObjectHeaders",
        "--add-modules=jdk.incubator.vector"
})
@State(Scope.Thread)
public class J28_VectorVsScalar {

    static final VectorSpecies<Float> S = FloatVector.SPECIES_PREFERRED;

    @Param({"1024", "1048576"})
    int n;

    float[] a;
    float[] b;

    @Setup
    public void setup() {
        a = new float[n];
        b = new float[n];
        for (int i = 0; i < n; i++) {
            a[i] = 1.0f;
            b[i] = 2.0f;
        }
    }

    @Benchmark
    public float scalarDot() {
        float[] xa = a;
        float[] xb = b;
        float sum = 0f;
        for (int i = 0; i < xa.length; i++) {
            sum += xa[i] * xb[i];
        }
        return sum;
    }

    @Benchmark
    public float vectorDot() {
        float[] xa = a;
        float[] xb = b;
        var acc = FloatVector.zero(S);
        int i = 0;
        int bound = S.loopBound(xa.length);
        for (; i < bound; i += S.length()) {
            var va = FloatVector.fromArray(S, xa, i);
            var vb = FloatVector.fromArray(S, xb, i);
            acc = va.fma(vb, acc);
        }
        float sum = acc.reduceLanes(VectorOperators.ADD);
        for (; i < xa.length; i++) {
            sum += xa[i] * xb[i];
        }
        return sum;
    }
}
