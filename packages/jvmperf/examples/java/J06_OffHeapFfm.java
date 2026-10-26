import java.lang.foreign.Arena;
import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.StructLayout;
import java.lang.foreign.ValueLayout;
import java.lang.invoke.VarHandle;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/** Off-heap memory with the FFM API (final in JDK 22, JEP 454) and direct ByteBuffer. */
public class J06_OffHeapFfm {
    // struct Car { int id; byte flags; [3 bytes padding] } -- explicit layout with no object header.
    static final StructLayout CAR = MemoryLayout.structLayout(
            ValueLayout.JAVA_INT.withName("id"),
            ValueLayout.JAVA_BYTE.withName("flags"),
            MemoryLayout.paddingLayout(3));
    static final VarHandle ID = CAR.varHandle(MemoryLayout.PathElement.groupElement("id"));
    static final VarHandle FLAGS = CAR.varHandle(MemoryLayout.PathElement.groupElement("flags"));

    public static void main(String[] args) {
        check(CAR.byteSize() == 8, "layout size");
        try (Arena arena = Arena.ofConfined()) {               // Deterministic release when the try block ends.
            MemorySegment cars = arena.allocate(CAR, 1000);    // One contiguous block of 1,000 × 8 bytes.
            for (int i = 0; i < 1000; i++) {
                MemorySegment c = cars.asSlice(i * CAR.byteSize(), CAR);
                ID.set(c, 0L, i);
                FLAGS.set(c, 0L, (byte) 0b011);
            }
            MemorySegment c42 = cars.asSlice(42 * CAR.byteSize(), CAR);
            check((int) ID.get(c42, 0L) == 42 && (byte) FLAGS.get(c42, 0L) == 3, "segment");
            check(cars.byteSize() == 8000, "8000 bytes");
        }
        // Legacy API: GC reclaims direct ByteBuffers through Cleaner; capacity is limited by -XX:MaxDirectMemorySize.
        ByteBuffer bb = ByteBuffer.allocateDirect(8 * 1000).order(ByteOrder.nativeOrder());
        bb.putInt(42 * 8, 42).put(42 * 8 + 4, (byte) 3);
        check(bb.getInt(42 * 8) == 42, "direct buffer");
        System.out.println("J06 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
