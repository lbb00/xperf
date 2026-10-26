class JpSleepPolling {
    volatile boolean ready;
    void await() throws InterruptedException {
        while (!ready) Thread.sleep(10);
    }
}
