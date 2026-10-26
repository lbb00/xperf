import java.util.BitSet;
import java.util.EnumSet;

/** Flags using bit operations, EnumSet, and BitSet; this is the hybrid-car case study. */
public class J03_Flags {
    enum Fuel { ELECTRIC, BENZINE, DIESEL }

    // 1) One field per flag: three booleans.
    static final class CarBools { boolean electric, benzine, diesel; }

    // 2) Store three flags in one byte; Java requires explicit bit operations.
    static final class CarByte {
        static final int ELECTRIC = 1, BENZINE = 1 << 1, DIESEL = 1 << 2;
        byte flags;
        boolean has(int f) { return (flags & f) != 0; }
        void set(int f) { flags = (byte) (flags | f); }
        void clear(int f) { flags = (byte) (flags & ~f); }
    }

    // 3) Packing saves meaningful memory in arrays: one byte or three bits per car.
    static final class Fleet {
        final byte[] flags;               // Primitive array: one byte per car.
        Fleet(int n) { flags = new byte[n]; }
    }
    static final class PackedFleet {
        final long[] bits;                // Three densely packed bits per car.
        PackedFleet(int n) { bits = new long[(n * 3 + 63) >>> 6]; }
        void set(int car, int fuelBit) { int i = car * 3 + fuelBit; bits[i >>> 6] |= 1L << i; } // long shifts use the low six bits of the distance.
        boolean has(int car, int fuelBit) { int i = car * 3 + fuelBit; return (bits[i >>> 6] & (1L << i)) != 0; }
    }

    public static void main(String[] args) {
        CarByte hybrid = new CarByte();
        hybrid.set(CarByte.ELECTRIC | CarByte.BENZINE);
        check(hybrid.has(CarByte.ELECTRIC) && !hybrid.has(CarByte.DIESEL) && hybrid.flags == 0b011, "byte flags");

        EnumSet<Fuel> fuels = EnumSet.of(Fuel.ELECTRIC, Fuel.BENZINE);   // Up to 64 constants fit in one long.
        check(fuels.contains(Fuel.BENZINE) && fuels.size() == 2, "EnumSet");

        BitSet bs = new BitSet(3000);
        bs.set(5 * 3 + Fuel.BENZINE.ordinal());
        check(bs.get(16) && bs.cardinality() == 1, "BitSet");

        PackedFleet pf = new PackedFleet(1000);
        check(pf.bits.length == 47, "47 longs = 376 bytes of data"); // ceil(3000/64)
        pf.set(999, 2);
        check(pf.has(999, 2) && !pf.has(999, 1), "packed");
        Fleet f = new Fleet(1000);
        f.flags[0] = CarByte.ELECTRIC | CarByte.BENZINE;
        check(Integer.bitCount(f.flags[0]) == 2, "fleet");
        System.out.println("J03 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
