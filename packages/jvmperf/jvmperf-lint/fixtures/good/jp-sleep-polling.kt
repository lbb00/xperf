import java.util.concurrent.CountDownLatch
val ready = CountDownLatch(1)
fun await() {
    ready.await()
}

// A periodic task with work on each iteration is not a busy wait: heartbeat, beacon, frame tick, or reconnect backoff.
fun heartbeat(running: java.util.concurrent.atomic.AtomicBoolean, send: () -> Unit) {
    while (running.get()) {
        send()
        try {
            Thread.sleep(2000)
        } catch (e: InterruptedException) {
            break
        }
    }
}
