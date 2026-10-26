import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
class JpLegacySynchronizedType {
    ArrayList<String> v = new ArrayList<>();
    ConcurrentHashMap<String, String> h = new ConcurrentHashMap<>();
    String s() { StringBuilder sb = new StringBuilder(16); return sb.toString(); }
    // OSGi-style Dictionary API — Hashtable is the concrete type
    Dictionary<String, String> osgiProps() {
        Dictionary<String, String> d = new Hashtable<>();
        return d;
    }
}
