/**
 * Escape analysis and scalar replacement: C2 may avoid heap allocation for small objects that do not escape.
 * Verify with -XX:-EliminateAllocations or JMH -prof gc; inspect gc.alloc.rate.norm.
 */
public class J08_EscapeAnalysis {
    record Vec(double x, double y) {
        Vec plus(Vec o) { return new Vec(x + o.x, y + o.y); }
        double len2() { return x * x + y * y; }
    }
    // Vec does not escape and its calls can inline, so C2 may replace it with two local doubles.
    static double sumLen2(double[] xs, double[] ys) {
        double s = 0;
        for (int i = 0; i < xs.length; i++) s += new Vec(xs[i], ys[i]).plus(new Vec(1, 1)).len2();
        return s;
    }
    static Vec last;                          // Storing into a static field makes the object escape.
    static void escapes(double x) { last = new Vec(x, x); }

    public static void main(String[] args) {
        double[] xs = {0, 1, 2}, ys = {0, 1, 2};
        if (sumLen2(xs, ys) != 2 + 8 + 18) throw new AssertionError();
        escapes(1);
        System.out.println("J08 ok");
    }
}
