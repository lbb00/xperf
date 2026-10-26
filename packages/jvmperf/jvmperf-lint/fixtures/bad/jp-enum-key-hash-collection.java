import java.util.*;
class JpEnumKeyHashCollection {
    enum Color { RED, GREEN }
    Map<Color, Integer> hits = new HashMap<>();
    HashSet<Color> seen = new HashSet<>();
}
