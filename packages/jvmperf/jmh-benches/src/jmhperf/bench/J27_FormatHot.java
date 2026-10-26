package jmhperf.bench;

import org.openjdk.jmh.annotations.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.TimeUnit;

/**
 * Comparative: String.format vs StringBuilder append vs precompiled DateTimeFormatter.
 * Guide §6.4. Same output shape: yyyy-MM-dd'T'HH:mm:ss (ISO local without nanos).
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Thread)
public class J27_FormatHot {

    private static final DateTimeFormatter ISO_LOCAL =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");

    @Param({"1", "64"})
    int reps;

    LocalDateTime when;

    @Setup
    public void setup() {
        when = LocalDateTime.of(2026, 10, 21, 18, 28, 0);
    }

    @Benchmark
    public String stringFormat() {
        LocalDateTime t = when;
        int n = reps;
        String last = null;
        for (int i = 0; i < n; i++) {
            last = String.format("%04d-%02d-%02dT%02d:%02d:%02d",
                    t.getYear(), t.getMonthValue(), t.getDayOfMonth(),
                    t.getHour(), t.getMinute(), t.getSecond());
        }
        return last;
    }

    @Benchmark
    public String stringBuilderAppend() {
        LocalDateTime t = when;
        int n = reps;
        String last = null;
        for (int i = 0; i < n; i++) {
            StringBuilder sb = new StringBuilder(19);
            pad4(sb, t.getYear());
            sb.append('-');
            pad2(sb, t.getMonthValue());
            sb.append('-');
            pad2(sb, t.getDayOfMonth());
            sb.append('T');
            pad2(sb, t.getHour());
            sb.append(':');
            pad2(sb, t.getMinute());
            sb.append(':');
            pad2(sb, t.getSecond());
            last = sb.toString();
        }
        return last;
    }

    @Benchmark
    public String dateTimeFormatter() {
        LocalDateTime t = when;
        int n = reps;
        String last = null;
        for (int i = 0; i < n; i++) {
            last = ISO_LOCAL.format(t);
        }
        return last;
    }

    private static void pad2(StringBuilder sb, int v) {
        if (v < 10) sb.append('0');
        sb.append(v);
    }

    private static void pad4(StringBuilder sb, int v) {
        if (v < 1000) sb.append('0');
        if (v < 100) sb.append('0');
        if (v < 10) sb.append('0');
        sb.append(v);
    }
}
