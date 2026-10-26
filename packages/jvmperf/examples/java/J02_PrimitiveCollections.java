import it.unimi.dsi.fastutil.ints.Int2IntOpenHashMap;
import it.unimi.dsi.fastutil.ints.IntArrayList;
import org.eclipse.collections.api.list.primitive.MutableIntList;
import org.eclipse.collections.impl.factory.primitive.IntLists;
import org.eclipse.collections.impl.map.mutable.primitive.IntIntHashMap;

/** Primitive collections from fastutil and Eclipse Collections avoid boxing and per-entry Node objects. */
public class J02_PrimitiveCollections {
    public static void main(String[] args) {
        int n = 1000;
        Int2IntOpenHashMap counts = new Int2IntOpenHashMap(n);   // Reserve capacity.
        counts.defaultReturnValue(0);
        for (int i = 0; i < n; i++) counts.addTo(i % 10, 1);     // Increment in place without boxing.
        check(counts.get(3) == 100, "fastutil map");

        IntArrayList list = new IntArrayList(n);
        for (int i = 0; i < n; i++) list.add(i);
        check(list.getInt(999) == 999, "fastutil list");

        IntIntHashMap ec = new IntIntHashMap(n);
        for (int i = 0; i < n; i++) ec.addToValue(i % 10, 1);
        MutableIntList ecl = IntLists.mutable.withInitialCapacity(n);
        for (int i = 0; i < n; i++) ecl.add(i);
        check(ec.get(3) == 100 && ecl.sum() == 499500L, "eclipse collections");
        System.out.println("J02 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
