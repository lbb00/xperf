class JpStringConcatInLoop {
    String join(String[] parts) {
        String s = "";
        for (String p : parts) { s += p; }
        return s;
    }
}
