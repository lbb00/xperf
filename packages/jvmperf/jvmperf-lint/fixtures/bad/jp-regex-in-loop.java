import java.util.regex.Pattern;
class JpRegexInLoop {
    int count(String[] lines) {
        int n = 0;
        for (String l : lines) {
            if (Pattern.compile("\\d+").matcher(l).find()) n++;
            n += l.split("\\s+").length;
            l.replaceAll("a+", "b");
        }
        return n;
    }
}
