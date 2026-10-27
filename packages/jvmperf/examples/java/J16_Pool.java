import java.nio.ByteBuffer;
import java.util.ArrayDeque;

/**
 * Pool only expensive resources such as direct ByteBuffers, large arrays, connections, and threads.
 * Pooling small objects is often slower: TLAB allocation is cheap, while pools add synchronization and leak risks.
 */
public class J16_Pool {
    static final class BufferPool {                       // Single-threaded; use one per thread or add locking for shared use.
        private final ArrayDeque<ByteBuffer> free = new ArrayDeque<>();
        private final int size;
        BufferPool(int size, int prealloc) {
            this.size = size;
            // jvmperf-lint: ignore jp-expensive-alloc-hot -- Pool is preallocated once during construction.
            for (int i = 0; i < prealloc; i++) free.push(ByteBuffer.allocateDirect(size));
        }
        ByteBuffer acquire() { ByteBuffer b = free.poll(); return b != null ? b.clear() : ByteBuffer.allocateDirect(size); }
        void release(ByteBuffer b) { free.push(b); }
    }
    public static void main(String[] args) {
        BufferPool pool = new BufferPool(64 * 1024, 4);
        ByteBuffer b = pool.acquire();
        b.putLong(42L);
        pool.release(b);
        if (pool.acquire() != b) throw new AssertionError();   // Reuses the same off-heap buffer.
        System.out.println("J16 ok");
    }
}
