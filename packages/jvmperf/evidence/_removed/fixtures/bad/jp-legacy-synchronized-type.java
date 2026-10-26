import java.util.*;
class JpLegacySynchronizedType {
    Vector<String> v = new Vector<>();
    Hashtable<String, String> h = new Hashtable<>();
    String s() { StringBuffer sb = new StringBuffer(); return sb.toString(); }
}
