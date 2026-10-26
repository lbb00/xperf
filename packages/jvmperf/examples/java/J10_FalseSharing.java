import java.util.concurrent.atomic.LongAdder;

/**
 * False sharing occurs when fields frequently written by different threads share a cache line.
 * - The JDK annotation @jdk.internal.vm.annotation.Contended requires the compile-time --add-exports flag
 *   and the runtime option -XX:-RestrictContended in user code.
 * - LongAdder is a ready-made option; its internal Cell counters use @Contended.
 * - Manual padding avoids JVM flags, but field layout is not guaranteed.
 */
public class J10_FalseSharing {
    static final class PaddedCounter {
        @jdk.internal.vm.annotation.Contended volatile long a;
        @jdk.internal.vm.annotation.Contended volatile long b;
    }
    public static void main(String[] args) throws Exception {
        LongAdder adder = new LongAdder();
        Thread[] ts = new Thread[4];
        for (int t = 0; t < ts.length; t++) {
            ts[t] = Thread.ofPlatform().start(() -> { for (int i = 0; i < 100_000; i++) adder.increment(); });
        }
        for (Thread t : ts) t.join();
        if (adder.sum() != 400_000) throw new AssertionError();
        PaddedCounter pc = new PaddedCounter();
        pc.a = 1; pc.b = 2;
        System.out.println("J10 ok");
    }
}
