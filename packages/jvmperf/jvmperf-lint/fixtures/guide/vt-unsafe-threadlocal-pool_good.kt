import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReferenceArray

/**
 * Guide-only vt-unsafe-threadlocal-pool — GOOD: striped / bounded reuse, not per-VT ThreadLocal.
 */
object vt-unsafe-threadlocal-poolGood {
    private const val STRIPES = 64
    private val striped = AtomicReferenceArray<ByteArray?>(STRIPES)
    private val tick = AtomicInteger()

    fun acquire(minCapacity: Int): ByteArray {
        val i = Math.floorMod(tick.getAndIncrement(), STRIPES)
        val existing = striped.getAndSet(i, null)
        return if (existing != null && existing.size >= minCapacity) {
            existing
        } else {
            ByteArray(maxOf(minCapacity, 64 * 1024))
        }
    }

    fun release(buf: ByteArray?) {
        if (buf == null) return
        val i = Math.floorMod(tick.getAndIncrement(), STRIPES)
        striped.compareAndSet(i, null, buf)
    }
}
