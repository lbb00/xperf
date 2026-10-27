class JpStringInternInLoop {
    void load(String[] xs, java.util.Set<String> out) {
        for (String x : xs) out.add(x); // compare by content / use a local Interner
    }
}
