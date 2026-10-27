class JpStringConcatInLoop {
    String join(String[] parts) {
        StringBuilder sb = new StringBuilder(parts.length * 8);
        for (String p : parts) sb.append(p);
        int total = 0;
        for (String p : parts) total += p.length();
        return sb.toString() + total;
    }
}
