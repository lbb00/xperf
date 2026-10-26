// const val and @JvmField change generated getters and companion-object indirection.
package k07

import java.lang.reflect.Modifier

class Limits {
    companion object {
        const val MAX = 1024                      // Compile-time constant, inlined at use sites.
        @JvmField val DEFAULT_NAMES = listOf("a")  // Public static final field on the outer class; no getter.
        val viaGetter = listOf("b")                // Private static field plus Companion.getViaGetter().
    }
}

object Registry {
    @JvmField val items = ArrayList<String>()     // @JvmField lets Java access Registry.items directly.
}

class Point(@JvmField val x: Int, @JvmField val y: Int)   // Java callers access the fields directly.

fun main() {
    val f = Limits::class.java.getDeclaredField("DEFAULT_NAMES")
    check(Modifier.isPublic(f.modifiers) && Modifier.isStatic(f.modifiers))
    check(!Modifier.isPublic(Limits::class.java.getDeclaredField("viaGetter").modifiers))
    check(Limits.MAX == 1024 && Point(1, 2).x == 1)
    Registry.items.add("x")
    println("K07 ok")
}
