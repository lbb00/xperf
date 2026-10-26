// Kotlin version of the flag case study: boolean fields, bit operations, a value class, and arrays.
package k05

import java.util.EnumSet

enum class Fuel { ELECTRIC, BENZINE, DIESEL }

data class HybridBools(val electric: Boolean, val benzine: Boolean, val diesel: Boolean)

// The value class adds a type and operations to Byte; the runtime representation remains a byte.
@JvmInline
value class FuelFlags(val bits: Byte) {
    operator fun contains(f: Fuel): Boolean = (bits.toInt() and (1 shl f.ordinal)) != 0
    operator fun plus(f: Fuel): FuelFlags = FuelFlags((bits.toInt() or (1 shl f.ordinal)).toByte())
    operator fun minus(f: Fuel): FuelFlags = FuelFlags((bits.toInt() and (1 shl f.ordinal).inv()).toByte())
    companion object {
        val NONE = FuelFlags(0)
    }
}

class Car(var fuels: FuelFlags)      // The field is represented as a byte.

fun main() {
    val hybrid = FuelFlags.NONE + Fuel.ELECTRIC + Fuel.BENZINE
    check(Fuel.ELECTRIC in hybrid && Fuel.DIESEL !in hybrid)
    check(hybrid.bits.toInt() == 0b011)
    check((hybrid - Fuel.BENZINE).bits.toInt() == 0b001)
    check(Car::class.java.getDeclaredField("fuels").type == Byte::class.javaPrimitiveType)
    // Kotlin uses infix functions for bit operations: shl, shr, ushr, and, or, xor, inv.
    check((1 shl 2) or 1 == 5 && (0b110 and 0b011) == 0b010 && 5.inv() == -6)
    // For 1,000 cars, ByteArray uses one byte each; Array<FuelFlags> and List<FuelFlags> box every value.
    val fleet = ByteArray(1000)
    fleet[7] = hybrid.bits
    check(Fuel.BENZINE in FuelFlags(fleet[7]))
    val es: EnumSet<Fuel> = EnumSet.of(Fuel.ELECTRIC, Fuel.BENZINE)
    check(es.size == 2 && HybridBools(true, true, false).electric)
    println("K05 ok")
}
