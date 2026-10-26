import java.util.*;
class JpEnumKeyHashCollection {
    enum Color { RED, GREEN }
    EnumMap<Color, String> names = new EnumMap<>(Color.class);
    EnumSet<Color> seen = EnumSet.noneOf(Color.class);
    Map<String, String> other = new HashMap<>();
}
