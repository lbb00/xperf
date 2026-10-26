package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.util.concurrent.TimeUnit;

/**
 * Comparative: AoS Particle[] step vs SoA parallel double[] step.
 * Guide §5.1. N particles, one position update per op.
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J21_SoABandwidth {
    @Param({"1000000"})
    int n;

    static final class Particle {
        double x, y, vx, vy;
    }

    Particle[] aos;
    double[] sx, sy, svx, svy;
    double dt = 0.016;

    @Setup
    public void setup() {
        aos = new Particle[n];
        sx = new double[n];
        sy = new double[n];
        svx = new double[n];
        svy = new double[n];
        for (int i = 0; i < n; i++) {
            Particle p = new Particle();
            p.x = i;
            p.y = i * 0.5;
            p.vx = 1.0;
            p.vy = 0.5;
            aos[i] = p;
            sx[i] = p.x;
            sy[i] = p.y;
            svx[i] = p.vx;
            svy[i] = p.vy;
        }
    }

    @Benchmark
    public double aosStep() {
        Particle[] a = aos;
        double d = dt;
        for (int i = 0; i < a.length; i++) {
            Particle p = a[i];
            p.x += p.vx * d;
            p.y += p.vy * d;
        }
        return a[0].x + a[n - 1].y;
    }

    @Benchmark
    public double soaStep() {
        double[] x = sx, y = sy, vx = svx, vy = svy;
        double d = dt;
        int len = n;
        for (int i = 0; i < len; i++) {
            x[i] += vx[i] * d;
            y[i] += vy[i] * d;
        }
        return x[0] + y[len - 1];
    }
}
