import java.text.SimpleDateFormat;
import java.util.Date;
class JpExpensiveAllocInLoop {
    void fmt(long[] ts, StringBuilder sb) {
        for (long t : ts) {
            sb.append(new SimpleDateFormat("yyyy-MM-dd").format(new Date(t)));
            byte[] buf = new byte[8192];
            sb.append(buf.length);
        }
    }
}
