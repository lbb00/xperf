class JpFormatInLoop {
    void render(double[] xs, StringBuilder sb) {
        for (double x : xs) sb.append(String.format("%.2f,", x));
    }
}
