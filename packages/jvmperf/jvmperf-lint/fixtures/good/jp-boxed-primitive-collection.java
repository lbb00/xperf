import java.util.*;
import java.util.function.Function;
class JpBoxedPrimitiveCollection {
    int[] ids = new int[16];
    List<String> names = new ArrayList<>(16);
    Map<String, List<String>> groups;
    // method / API signatures — not flagged
    void accept(Map<Integer, String> m) {}
    List<Long> idsOf(Collection<Integer> in) { return List.of(); }
    Function<Map<Long, Object>, String> factory;
    // type-parameter boundary
    Map<E, Integer> counts;
}
class CharEscaperBuilder {
    Map<Character, String> replacement = new HashMap<>();
}
class Http2Settings {
    java.util.Map<Integer, Long> settings;
}
class ImmutableIntArray {
    static ImmutableIntArray copyOf(java.util.Collection<Integer> values) { return null; }
}
class SocksAuth {
    java.util.Map<Byte, Object> factories;
}
class FlagMaps {
    java.util.Map<Class<?>, Boolean> enabled;
    java.util.Map<String, Boolean> flags;
}
