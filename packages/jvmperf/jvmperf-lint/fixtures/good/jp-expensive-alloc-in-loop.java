import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.text.SimpleDateFormat;
import java.util.Locale;
class JpExpensiveAllocInLoop {
    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final ThreadLocal<SimpleDateFormat> TL = ThreadLocal.withInitial(
            () -> new SimpleDateFormat("yyyy-MM-dd", Locale.US));
    void fmt(LocalDate[] ds, StringBuilder sb) {
        byte[] buf = new byte[8192];
        for (LocalDate d : ds) {
            sb.append(FMT.format(d)).append(buf.length);
            int[] row = new int[d.getDayOfMonth()];
            sb.append(row.length);
        }
    }
    // Cache-fill loop: formats[i] = new SimpleDateFormat — not a hot per-request alloc.
    void fillCache(SimpleDateFormat[] formats, String[] patterns) {
        for (int i = 0; i < patterns.length; i++) {
            if (formats[i] == null) {
                formats[i] = new SimpleDateFormat(patterns[i], Locale.US);
            }
        }
    }
}
