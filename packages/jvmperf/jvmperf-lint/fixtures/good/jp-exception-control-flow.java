class JpExceptionControlFlow {
    static boolean isDigits(String s) {
        if (s.isEmpty()) return false;
        for (int i = 0; i < s.length(); i++) if (!Character.isDigit(s.charAt(i))) return false;
        return true;
    }
    int countInts(String[] xs) {
        int n = 0;
        for (String x : xs) if (isDigits(x)) n++;
        return n;
    }
}
