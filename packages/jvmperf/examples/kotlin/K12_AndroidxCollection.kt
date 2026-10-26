// Primitive collections in androidx.collection 1.4+ work with Kotlin Multiplatform and regular JVM projects.
package k12

import androidx.collection.MutableIntIntMap
import androidx.collection.MutableIntList
import androidx.collection.MutableIntObjectMap
import androidx.collection.SparseArrayCompat
import androidx.collection.mutableIntListOf

fun main() {
    val counts = MutableIntIntMap(64)                 // Open addressing; keys and values are ints.
    for (i in 0 until 1000) counts[i % 10] = counts.getOrDefault(i % 10, 0) + 1
    check(counts[3] == 100)

    val ids: MutableIntList = mutableIntListOf()
    for (i in 0 until 100) ids.add(i)
    var total = 0
    ids.forEach { total += it }                        // Inline; elements are passed as ints.
    check(total == 4950 && ids.size == 100)

    val names = MutableIntObjectMap<String>()
    names[42] = "answer"
    check(names[42] == "answer")

    val sparse = SparseArrayCompat<String>()            // Like android.util.SparseArray, uses sorted arrays and binary search.
    sparse.put(7, "seven")
    check(sparse[7] == "seven")
    println("K12 ok")
}
