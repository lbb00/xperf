import java.util.ArrayList;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

/** Reserve collection capacity and use EnumMap/EnumSet for enum keys. */
public class J13_Presize {
    enum Color { RED, GREEN, BLUE }
    public static void main(String[] args) {
        int n = 10_000;
        List<String> names = new ArrayList<>(n);                  // Avoid repeated growth and array copies.
        // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
        Map<String, Integer> idx = HashMap.newHashMap(n);           // JDK 19+: reserve by element count, accounting for the load factor.
        HashSet<String> seen = HashSet.newHashSet(n);               // JDK 19+
        for (int i = 0; i < n; i++) { String s = "k" + i; names.add(s); idx.put(s, i); seen.add(s); }
        // Note: new HashMap<>(n) takes table capacity; inserting n elements may still resize it.
        EnumMap<Color, Integer> hits = new EnumMap<>(Color.class);  // Internally an array indexed by ordinal.
        hits.merge(Color.RED, 1, Integer::sum);
        EnumSet<Color> warm = EnumSet.of(Color.RED, Color.GREEN);
        if (idx.get("k42") != 42 || !warm.contains(Color.RED) || hits.get(Color.RED) != 1 || seen.size() != n)
            throw new AssertionError();
        System.out.println("J13 ok");
    }
}
