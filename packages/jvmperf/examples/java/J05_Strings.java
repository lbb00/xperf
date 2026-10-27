import java.util.List;
import java.util.StringJoiner;

/** Strings: reserve StringBuilder capacity, avoid += in loops, and use join or intern appropriately. */
public class J05_Strings {
    static String joinSlow(List<String> parts) {
        String s = "";
        // jvmperf-lint: ignore jp-string-concat-hot -- Intentional counterexample.
        for (String p : parts) s += p + ",";          // Creates and copies a new String each iteration: O(n²).
        return s;
    }
    static String joinFast(List<String> parts) {
        int cap = 0;
        for (String p : parts) cap += p.length() + 1;
        StringBuilder sb = new StringBuilder(cap);     // Allocate enough capacity once.
        for (String p : parts) sb.append(p).append(',');
        return sb.toString();
    }
    public static void main(String[] args) {
        List<String> parts = List.of("a", "bb", "ccc");
        check(joinSlow(parts).equals(joinFast(parts)), "join");
        check(String.join(",", parts).equals("a,bb,ccc"), "String.join");
        StringJoiner sj = new StringJoiner(",", "[", "]");
        parts.forEach(sj::add);
        check(sj.toString().equals("[a,bb,ccc]"), "joiner");
        // A single + expression is fine: javac 9+ uses invokedynamic and StringConcatFactory (JEP 280).
        String name = "x"; int n = 3;
        check((name + "=" + n).equals("x=3"), "indy concat");
        // Use intern for a small set of long-lived, repeated values; UseStringDeduplication shares backing arrays only.
        String k1 = new String("status-OK").intern(), k2 = "status-OK";
        check(k1 == k2, "intern");
        System.out.println("J05 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
