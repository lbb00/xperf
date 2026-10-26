import java.util.regex.Pattern;
class JpRegexInLoop {
    private static final Pattern DIGITS = Pattern.compile("\\d+");
    private static final Pattern WS = Pattern.compile("\\s+");
    int count(String[] lines) {
        int n = 0;
        for (String l : lines) {
            if (DIGITS.matcher(l).find()) n++;
            n += WS.split(l).length;
            n += l.split(",").length;
            n += l.replace(".", "/").length();
        }
        return n;
    }
}
