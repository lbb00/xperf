import java.util.EnumMap
import java.util.EnumSet

enum class Color { RED, GREEN }
class JpEnumKeyHashCollection {
    val names = EnumMap<Color, String>(Color::class.java)
    val seen: EnumSet<Color> = EnumSet.noneOf(Color::class.java)
}
