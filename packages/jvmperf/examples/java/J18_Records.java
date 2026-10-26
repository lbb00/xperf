import java.util.Arrays;

/** Immutable values and bulk operations: record arrays vs primitive arrays; Arrays methods use intrinsics. */
public class J18_Records {
    record Sample(long ts, double value) {}
    public static void main(String[] args) {
        int n = 1000;
        long[] ts = new long[n];
        double[] vs = new double[n];
        Arrays.setAll(ts, i -> 1_000L * i);
        Arrays.fill(vs, 1.5);
        double sum = 0;
        for (double v : vs) sum += v;
        long[] copy = Arrays.copyOf(ts, n * 2);                // System.arraycopy intrinsic
        if (sum != 1500 || copy[999] != 999_000L || Arrays.binarySearch(ts, 5_000L) != 5) throw new AssertionError();
        Sample s = new Sample(ts[1], vs[1]);
        if (s.ts() != 1000) throw new AssertionError();
        System.out.println("J18 ok");
    }
}
