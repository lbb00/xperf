/**
 * JIT-friendly code: sealed types, switch pattern matching, small methods, and intrinsics.
 * Inspect inlining with: java -XX:+UnlockDiagnosticVMOptions -XX:+PrintInlining
 */
public class J09_JitFriendly {
    sealed interface Shape permits Circle, Rect {}
    record Circle(double r) implements Shape {}
    record Rect(double w, double h) implements Shape {}

    static double area(Shape s) {
        return switch (s) {                       // Exhaustive switch; no virtual call.
            case Circle c -> Math.PI * c.r() * c.r();
            case Rect r -> r.w() * r.h();
        };
    }
    public static void main(String[] args) {
        Shape[] shapes = {new Circle(1), new Rect(2, 3)};
        double total = 0;
        for (Shape s : shapes) total += area(s);
        if (Math.abs(total - (Math.PI + 6)) > 1e-9) throw new AssertionError();
        // These HotSpot intrinsics compile to a small number of specialized instructions.
        if (Integer.bitCount(0b1011) != 3 || Long.numberOfTrailingZeros(8) != 3) throw new AssertionError();
        if (Math.fma(2.0, 3.0, 1.0) != 7.0) throw new AssertionError();
        if (java.util.Arrays.mismatch(new byte[]{1, 2, 3}, new byte[]{1, 2, 4}) != 2) throw new AssertionError();
        System.out.println("J09 ok");
    }
}
