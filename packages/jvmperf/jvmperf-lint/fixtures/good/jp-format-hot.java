class JpFormatInLoop {
    void render(double[] xs, StringBuilder sb) {
        for (double x : xs) sb.append(Math.round(x * 100) / 100.0).append(',');
        sb.append(String.format("%d items", xs.length));
    }
    void guard(String[] xs) {
        for (String x : xs) {
            if (x == null) throw new IllegalStateException(String.format("bad %s", x));
        }
    }
}
