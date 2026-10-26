import java.util.regex.Pattern;

/**
 * Lazy initialization with the holder idiom: class initialization is thread-safe and runs once; reads need no synchronization.
 * JDK 25 StableValue (JEP 502, preview) was renamed LazyConstant in JDK 26/27 (JEP 526/531, still preview).
 */
public class J17_LazyInit {
    private static final class Holder {
        static final Pattern EMAIL = Pattern.compile("[^@\\s]+@[^@\\s]+");
    }
    static boolean isEmail(String s) { return Holder.EMAIL.matcher(s).matches(); }

    public static void main(String[] args) {
        if (!isEmail("a@b.c") || isEmail("nope")) throw new AssertionError();
        System.out.println("J17 ok");
    }
}
