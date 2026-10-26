@JvmInline
value class UserId(val raw: Int)

class Session(val owner: UserId?)
fun all(ids: List<UserId>): Array<UserId> = ids.toTypedArray()
