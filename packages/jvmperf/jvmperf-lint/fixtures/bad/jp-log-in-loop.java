class JpLogInLoop {
    org.slf4j.Logger log;
    void process(int[] xs) {
        for (int x : xs) log.debug("x=" + x);
    }
}
