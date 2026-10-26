/** Do not use exceptions for control flow; frequent exceptions can disable writable stack traces. */
public class J14_Exceptions {
    static final class ParseFailure extends RuntimeException {
        private static final long serialVersionUID = 1L;
        ParseFailure(String msg) { super(msg, null, false, false); }   // Skips stack capture; cheaper but harder to debug.
    }
    // Bad: use an exception to check whether a value is numeric.
    static boolean isIntSlow(String s) {
        try { Integer.parseInt(s); return true; } catch (NumberFormatException e) { return false; }
    }
    // Better: validate before parsing.
    static boolean isIntFast(String s) {
        if (s.isEmpty() || s.length() > 11) return false;          // "-2147483648" is 11 characters.
        int i = (s.charAt(0) == '-' || s.charAt(0) == '+') ? 1 : 0;
        if (i == s.length()) return false;
        for (; i < s.length(); i++) if (!Character.isDigit(s.charAt(i))) return false;
        try { Integer.parseInt(s); return true; } catch (NumberFormatException e) { return false; } // Only rare overflow cases reach the exception.
    }
    public static void main(String[] args) {
        for (String s : new String[]{"12", "-3", "x", "", "-", "99999999999", "-2147483648", "+5", "2147483648"})
            if (isIntSlow(s) != isIntFast(s)) throw new AssertionError(s);
        ParseFailure f = new ParseFailure("bad");
        if (f.getStackTrace().length != 0) throw new AssertionError();
        System.out.println("J14 ok");
    }
}
