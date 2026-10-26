import org.openjdk.jol.info.ClassLayout;
import org.openjdk.jol.info.GraphLayout;
import org.openjdk.jol.vm.VM;
import java.util.*;

/** 用 JOL 实测对象大小。运行：java -cp jol-core.jar:. [-XX:+UseCompactObjectHeaders] JolSizes */
public class JolSizes {
    enum Fuel { ELECTRIC, BENZINE, DIESEL }
    // 视频里的四步
    static final class HybridTwoInts { int electric; int benzine; }   // C: struct { int; int; } = 8 字节
    static final class FlagsInt { int flags; }                         // C: int flags = 4 字节
    static final class FlagsByte { byte flags; }                       // C: uint8_t 位域 = 1 字节
    static final class FlagsBools { boolean electric, benzine, diesel; }
    static final class FlagsEnumSet { final EnumSet<Fuel> fuels = EnumSet.noneOf(Fuel.class); }
    static final class Point { int x; int y; }
    static final class Mixed { byte b; long l; int i; Object ref; boolean z; }

    static void cls(Class<?> c) {
        System.out.printf("%-28s instance=%d%n", c.getSimpleName(), ClassLayout.parseClass(c).instanceSize());
    }
    static void graph(String what, Object o) {
        System.out.printf("%-40s total=%d bytes, objects=%d%n", what, GraphLayout.parseInstance(o).totalSize(),
                GraphLayout.parseInstance(o).totalCount());
    }

    public static void main(String[] args) {
        System.out.println("java.version=" + System.getProperty("java.version"));
        System.out.println(VM.current().details());
        System.out.println(ClassLayout.parseClass(Mixed.class).toPrintable());
        for (Class<?> c : List.of(Object.class, Integer.class, Long.class, Boolean.class, Point.class,
                HybridTwoInts.class, FlagsInt.class, FlagsByte.class, FlagsBools.class, FlagsEnumSet.class, Mixed.class)) cls(c);
        // EnumSet/EnumMap 引用的 Class 对象、枚举常量和 universe 数组是全类型共享的，这里只计每个实例独有的部分
        EnumSet<Fuel> es = EnumSet.of(Fuel.ELECTRIC, Fuel.BENZINE);
        long esSize = ClassLayout.parseInstance(es).instanceSize();
        System.out.printf("%-40s %s=%d bytes (独有部分)%n", "EnumSet.of(ELECTRIC,BENZINE)", es.getClass().getSimpleName(), esSize);
        System.out.printf("%-40s total=%d bytes (持有者 + RegularEnumSet)%n", "FlagsEnumSet 对象", ClassLayout.parseClass(FlagsEnumSet.class).instanceSize() + esSize);
        graph("BitSet(3)", new BitSet(3));
        graph("20 个 ASCII 字符的 String (Latin1)", new String("abcdefghijklmnopqrst"));
        graph("20 个汉字的 String (UTF16)", new String("一二三四五六七八九十一二三四五六七八九十"));
        graph("new int[0]", new int[0]);
        graph("new byte[1000]", new byte[1000]);
        graph("new int[1000]", new int[1000]);
        graph("new long[1000]", new long[1000]);
        HybridTwoInts[] cars = new HybridTwoInts[1000];
        for (int i = 0; i < cars.length; i++) cars[i] = new HybridTwoInts();
        graph("HybridTwoInts[1000] + 1000 objects", cars);
        FlagsByte[] fb = new FlagsByte[1000];
        for (int i = 0; i < fb.length; i++) fb[i] = new FlagsByte();
        graph("FlagsByte[1000] + 1000 objects", fb);
        graph("BitSet(3000) (1000 辆车 × 3 位)", new BitSet(3000));
        List<Integer> boxed = new ArrayList<>(1000);
        for (int i = 0; i < 1000; i++) boxed.add(i + 1000); // 超出 Integer 缓存，确保都是新对象
        graph("ArrayList<Integer> 1000 个 (>=1000)", boxed);
        int[] prim = new int[1000];
        graph("int[1000]", prim);
        Map<Integer, Integer> hm = new HashMap<>();
        for (int i = 0; i < 1000; i++) hm.put(i + 1000, i + 1000);
        graph("HashMap<Integer,Integer> 1000 项", hm);
        var fu = new it.unimi.dsi.fastutil.ints.Int2IntOpenHashMap();
        for (int i = 0; i < 1000; i++) fu.put(i + 1000, i + 1000);
        graph("fastutil Int2IntOpenHashMap 1000 项", fu);
        EnumMap<Fuel, Integer> em = new EnumMap<>(Fuel.class);
        System.out.printf("%-40s total=%d bytes (EnumMap 对象 + 长度 3 的 vals 数组，独有部分)%n", "EnumMap<Fuel,Integer>",
                ClassLayout.parseInstance(em).instanceSize() + ClassLayout.parseInstance(new Object[3]).instanceSize());
    }
}
