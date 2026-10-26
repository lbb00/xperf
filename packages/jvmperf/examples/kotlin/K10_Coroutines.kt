// Each suspend function compiles to a state machine and needs a continuation when suspended; launch/async also allocate objects.
// Split small CPU-bound tasks into chunks instead of creating one coroutine per element.
package k10

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.runBlocking

suspend fun parallelSum(xs: IntArray, chunks: Int = Runtime.getRuntime().availableProcessors()): Long = coroutineScope {
    val size = (xs.size + chunks - 1) / chunks
    (0 until chunks).map { c ->
        async(Dispatchers.Default) {
            var s = 0L
            val end = minOf(xs.size, (c + 1) * size)
            for (i in c * size until end) s += xs[i]     // A regular loop with no suspension point or allocation inside the chunk.
            s
        }
    }.awaitAll().sum()
}

fun main() = runBlocking {
    val xs = IntArray(1_000_000) { 1 }
    check(parallelSum(xs) == 1_000_000L)
    println("K10 ok")
}
