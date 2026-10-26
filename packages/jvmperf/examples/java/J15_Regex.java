import java.util.regex.Pattern;

/** Compile and reuse Pattern; String.split has a single-character fast path; replace(CharSequence) is literal. */
public class J15_Regex {
    private static final Pattern WS = Pattern.compile("\\s+");     // Compile once.

    static int countWordsSlow(String[] lines) {
        int n = 0;
        // jvmperf-lint: ignore jp-regex-in-loop -- Intentional counterexample.
        for (String l : lines) n += l.trim().split("\\s+").length;   // Compiles the regex on each call.
        return n;
    }
    static int countWordsFast(String[] lines) {
        int n = 0;
        for (String l : lines) n += WS.split(l.trim()).length;
        return n;
    }
    public static void main(String[] args) {
        String[] lines = {"a b  c", " d e "};
        if (countWordsSlow(lines) != countWordsFast(lines)) throw new AssertionError();
        // A single non-metacharacter such as "," takes String.split's fast path without regex compilation.
        if ("a,b,c".split(",").length != 3) throw new AssertionError();
        // replace(CharSequence, CharSequence) is literal; replaceAll treats its first argument as a regex.
        if (!"a.b.c".replace(".", "/").equals("a/b/c")) throw new AssertionError();
        System.out.println("J15 ok");
    }
}
