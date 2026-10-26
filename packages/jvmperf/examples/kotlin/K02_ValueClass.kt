// A value class stays unboxed as its own type, but boxes as a generic, nullable, or interface value.
package k02

@JvmInline
value class UserId(val raw: Int)

class Holder(val id: UserId)            // The field is represented as int.
// jvmperf-lint: ignore jp-value-class-boxing -- Intentional counterexample.
class NullableHolder(val id: UserId?)   // Nullable use boxes the field as UserId.

// Use a sentinel instead of null to avoid boxing.
@JvmInline
value class OptUserId(val raw: Int) {
    val isNone: Boolean get() = raw == NONE
    companion object {
        const val NONE = -1
        val None = OptUserId(NONE)
    }
}
class OptHolder(val id: OptUserId)

fun main() {
    check(Holder::class.java.getDeclaredField("id").type == Int::class.javaPrimitiveType)
    check(NullableHolder::class.java.getDeclaredField("id").type == UserId::class.java)
    check(OptHolder::class.java.getDeclaredField("id").type == Int::class.javaPrimitiveType)
    // jvmperf-lint: ignore jp-value-class-boxing -- Intentional counterexample.
    val ids: List<UserId> = listOf(UserId(1), UserId(2))   // Generic elements are boxed UserId objects.
    check((ids[0] as Any).javaClass == UserId::class.java)
    // Store many IDs in IntArray and wrap them as UserId only when needed.
    val raw = intArrayOf(1, 2, 3)
    val first = UserId(raw[0])
    check(first == UserId(1) && OptHolder(OptUserId.None).id.isNone)
    println("K02 ok")
}
