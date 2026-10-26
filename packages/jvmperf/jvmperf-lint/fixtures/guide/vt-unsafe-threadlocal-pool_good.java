import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReferenceArray;

/**
 * Guide-only vt-unsafe-threadlocal-pool — GOOD shapes for VT-aware buffer reuse.
 * Prefer a striped pool sized around carrier/platform concurrency
 * (or a Semaphore-limited shared pool), not one ThreadLocal fat slot
 * per virtual thread. Scoped Values for immutable request context.
 */
final class VtUnsafeThreadlocalPoolGood {
    private static final int STRIPES = 64; // ~carrier / core order of magnitude
    private static final AtomicReferenceArray<byte[]> STRIPED =
            new AtomicReferenceArray<>(STRIPES);
    private static final AtomicInteger TICK = new AtomicInteger();

    static byte[] acquire(int minCapacity) {
        int i = Math.floorMod(TICK.getAndIncrement(), STRIPES);
        byte[] buf = STRIPED.getAndSet(i, null);
        if (buf == null || buf.length < minCapacity) {
            buf = new byte[Math.max(minCapacity, 64 * 1024)];
        }
        return buf;
    }

    static void release(byte[] buf) {
        if (buf == null) return;
        int i = Math.floorMod(TICK.getAndIncrement(), STRIPES);
        // Best-effort: drop if stripe busy (bounded RSS).
        STRIPED.compareAndSet(i, null, buf);
    }

    /** Immutable per-request data: ScopedValue, not ThreadLocal. */
    static final java.lang.ScopedValue<String> REQUEST_ID = java.lang.ScopedValue.newInstance();
}
