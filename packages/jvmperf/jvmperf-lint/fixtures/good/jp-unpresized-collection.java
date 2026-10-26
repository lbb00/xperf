import java.util.*;
import java.util.regex.*;
class JpUnpresizedCollection {
    List<String> copy(String[] in) {
        List<String> out = new ArrayList<>(in.length);
        for (String s : in) out.add(s);
        Map<String, String> m = HashMap.newHashMap(in.length);
        for (String s : in) m.put(s, s);
        return out;
    }
    // Tiny fixed loop — capacity not worth it.
    List<String> tiny() {
        List<String> xs = new ArrayList<>();
        for (int i = 0; i < 3; i++) xs.add("x");
        return xs;
    }
    // Capacity set before fill.
    List<String> later(int n) {
        List<String> xs = new ArrayList<>();
        xs.ensureCapacity(n);
        for (int i = 0; i < n; i++) xs.add("x");
        return xs;
    }
    // Debug / toString path.
    public String toString() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 10; i++) sb.append(i);
        return sb.toString();
    }
    // Unknowable while(find) fill.
    Set<String> pathParams(String path) {
        Matcher m = Pattern.compile("\\{([^}]+)\\}").matcher(path);
        Set<String> names = new LinkedHashSet<>();
        while (m.find()) names.add(m.group(1));
        return names;
    }
    // Soft collection + unknowable iterable call — demoted
    List<String> fromCsv(String header) {
        List<String> out = new ArrayList<>();
        for (String p : header.split(",")) out.add(p.trim());
        return out;
    }
}
