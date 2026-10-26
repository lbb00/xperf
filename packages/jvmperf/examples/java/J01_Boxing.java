import java.util.ArrayList;
import java.util.List;
import java.util.stream.IntStream;

/** Boxing costs and pitfalls: List<Integer> vs int[], the Integer cache, and reference equality. */
public class J01_Boxing {
    // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
    static long sumBoxed(List<Integer> xs) {
        long s = 0;
        for (Integer x : xs) s += x;          // Unboxes each value; throws NPE if x is null.
        return s;
    }
    static long sumPrimitive(int[] xs) {
        long s = 0;
        for (int x : xs) s += x;              // Contiguous storage, no pointer chasing; C2 may vectorize it.
        return s;
    }
    public static void main(String[] args) {
        int n = 10_000;
        // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
        List<Integer> boxed = new ArrayList<>(n);
        int[] prim = new int[n];
        for (int i = 0; i < n; i++) { boxed.add(i); prim[i] = i; }
        check(sumBoxed(boxed) == sumPrimitive(prim), "sum");

        // Integer.valueOf caches -128..127; raise the upper bound with -XX:AutoBoxCacheMax.
        Integer a = 127, b = 127, c = 128, d = 128;
        check(a == b, "cached");                   // The same cached object.
        check(c.equals(d), "equals");              // Always use equals for wrapper values.
        // c == d is false with default settings; do not rely on reference identity.

        // Streams: mapToInt keeps primitive values; map(...).reduce(Integer::sum) boxes each step.
        long s1 = IntStream.range(0, n).asLongStream().sum();
        int s2 = boxed.stream().mapToInt(Integer::intValue).sum();
        check(s1 == sumPrimitive(prim) && s2 == (int) s1, "streams");
        System.out.println("J01 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
