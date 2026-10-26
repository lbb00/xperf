@JvmInline
value class UserId(val raw: Int) {
    val isNone: Boolean get() = raw < 0
}

class Session(val owner: UserId)
fun owners(raw: IntArray): UserId = UserId(raw[0])
