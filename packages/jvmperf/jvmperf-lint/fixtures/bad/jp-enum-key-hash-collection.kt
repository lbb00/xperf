enum class Color { RED, GREEN }
class JpEnumKeyHashCollection {
    val hits = HashMap<Color, Int>()
    val seen: MutableSet<Color> = mutableSetOf()
    val m = mutableMapOf<Color, String>()
}
