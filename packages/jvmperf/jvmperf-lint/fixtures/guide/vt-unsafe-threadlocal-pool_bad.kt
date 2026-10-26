/**
 * Guide-only vt-unsafe-threadlocal-pool — BAD: ThreadLocal recycle stack of large buffers.
 * Unsafe under many virtual threads (RSS × VT count).
 */
object vt-unsafe-threadlocal-poolBad {
    private val pool = ThreadLocal.withInitial { ArrayDeque<ByteArray>() }

    fun acquire(minCapacity: Int): ByteArray {
        val q = pool.get()
        val existing = q.removeFirstOrNull()
        return if (existing != null && existing.size >= minCapacity) {
            existing
        } else {
            ByteArray(maxOf(minCapacity, 64 * 1024))
        }
    }

    fun release(buf: ByteArray?) {
        if (buf != null) pool.get().addFirst(buf)
    }
}
