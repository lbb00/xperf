class JpLogInLoop {
    org.slf4j.Logger log;
    void dump(int[] xs) {
        // diagnostic method name: stdio / log in loop suppressed
        for (int x : xs) System.out.println(x);
        for (int x : xs) log.debug("x=" + x);
    }
    void process(int[] xs) {
        // System.out in loop suppressed unless --strict-stdio-in-loop
        for (int x : xs) System.out.println(x);
        for (int x : xs) {
            if (log.isDebugEnabled()) log.debug("x=" + x);
        }
        // sampled branch
        for (int i = 0; i < xs.length; i++) {
            if (i % 30 == 0) log.debug("x=" + xs[i]);
        }
    }
    public static void main(String[] args) {
        for (String a : args) System.out.println(a);
    }
}
