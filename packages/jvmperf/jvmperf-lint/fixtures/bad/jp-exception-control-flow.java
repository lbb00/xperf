class JpExceptionControlFlow {
    int countInts(String[] xs) {
        int n = 0;
        for (String x : xs) {
            try { Integer.parseInt(x); n++; } catch (NumberFormatException e) { }
        }
        return n;
    }
}
