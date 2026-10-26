import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.IntStream;

/** Virtual threads (JDK 21, JEP 444) suit many blocking I/O tasks, not CPU-bound work. */
public class J11_VirtualThreads {
    public static void main(String[] args) {
        AtomicInteger done = new AtomicInteger();
        try (var exec = Executors.newVirtualThreadPerTaskExecutor()) {   // One virtual thread per task; do not pool them.
            IntStream.range(0, 10_000).forEach(i -> exec.submit(() -> {
                try { Thread.sleep(10); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
                done.incrementAndGet();
            }));
        } // close() waits for all tasks to finish.
        if (done.get() != 10_000) throw new AssertionError();
        System.out.println("J11 ok");
    }
}
