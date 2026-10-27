class JpStringInternInLoop {
    void load(String[] xs, java.util.Set<String> out) {
        for (String x : xs) out.add(x.intern());
    }
}
