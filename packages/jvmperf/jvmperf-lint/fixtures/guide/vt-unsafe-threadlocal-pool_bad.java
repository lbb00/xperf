import java.nio.ByteBuffer;
import java.util.ArrayDeque;
import java.util.Deque;

/**
 * Guide-only vt-unsafe-threadlocal-pool (vt-unsafe-threadlocal-pool) — BAD shape.
 * One ThreadLocal slot holds a fat byte[] / ByteBuffer recycle stack.
 * Under millions of virtual threads this inflates RSS (one fat TL value
 * per VT), even when the buffer is "pooled". Not a shipped lint rule.
 */
final class VtUnsafeThreadlocalPoolBad {
    private static final ThreadLocal<Deque<byte[]>> BUF_POOL =
            ThreadLocal.withInitial(ArrayDeque::new);

    static byte[] acquire(int minCapacity) {
        Deque<byte[]> q = BUF_POOL.get();
        byte[] buf = q.pollFirst();
        if (buf == null || buf.length < minCapacity) {
            buf = new byte[Math.max(minCapacity, 64 * 1024)];
        }
        return buf;
    }

    static void release(byte[] buf) {
        if (buf != null) {
            BUF_POOL.get().offerFirst(buf);
        }
    }

    static ByteBuffer acquireDirect(int minCapacity) {
        // Same anti-pattern: TL cache of direct buffers sized for platform
        // threads, then reused under Loom carriers → leak / RSS blow-up.
        return ByteBuffer.allocateDirect(Math.max(minCapacity, 64 * 1024));
    }
}
