import java.util.concurrent.CountDownLatch;
class JpSleepPolling {
    final CountDownLatch ready = new CountDownLatch(1);
    void await() throws InterruptedException { ready.await(); }
    // A periodic task with work on each iteration is not a busy wait.
    volatile boolean running = true;
    void heartbeat(Runnable send) throws InterruptedException {
        while (running) {
            send.run();
            Thread.sleep(2000);
        }
    }
}
