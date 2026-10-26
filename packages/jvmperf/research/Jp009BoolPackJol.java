import org.openjdk.jol.info.ClassLayout;
import org.openjdk.jol.info.GraphLayout;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.time.*;

/** jp-many-boolean-fields many-boolean-fields: footprint of 8 booleans vs bitfield (COH). Not a hot-path wall-clock claim. */
public class Jp009BoolPackJol {
    static class ManyBool {
        boolean a,b,c,d,e,f,g,h;
    }
    static class Packed {
        int flags;
        boolean a() { return (flags & 1) != 0; }
    }
    public static void main(String[] args) throws Exception {
        String resultsDir = System.getenv().getOrDefault("JMH_RESULTS_DIR", "bench-results");
        String out = args.length > 0 ? args[0]
            : resultsDir + "/JP009_BoolPackJol.jsonl";
        System.out.println(ClassLayout.parseClass(ManyBool.class).toPrintable());
        System.out.println(ClassLayout.parseClass(Packed.class).toPrintable());
        ManyBool mb = new ManyBool();
        Packed pk = new Packed();
        long mbSz = GraphLayout.parseInstance(mb).totalSize();
        long pkSz = GraphLayout.parseInstance(pk).totalSize();
        String jdk = System.getProperty("java.runtime.version");
        String ts = OffsetDateTime.now(ZoneId.of("Asia/Shanghai")).toString();
        String coh = args.length > 1 ? args[1] : "true";
        StringBuilder sb = new StringBuilder();
        sb.append("{\"name\":\"JP009_BoolPackJol.ManyBool\",\"total_size_bytes\":").append(mbSz)
          .append(",\"jdk_version\":\"").append(jdk).append("\",\"jvm_args\":\"")
          .append("true".equals(coh) ? "-XX:+UseCompactObjectHeaders" : "(default headers)")
          .append("\",\"coh\":\"").append(coh).append("\",\"timestamp\":\"").append(ts).append("\"}\n");
        sb.append("{\"name\":\"JP009_BoolPackJol.Packed\",\"total_size_bytes\":").append(pkSz)
          .append(",\"jdk_version\":\"").append(jdk).append("\",\"jvm_args\":\"")
          .append("true".equals(coh) ? "-XX:+UseCompactObjectHeaders" : "(default headers)")
          .append("\",\"coh\":\"").append(coh).append("\",\"timestamp\":\"").append(ts).append("\"}\n");
        Files.writeString(Path.of(out), sb.toString(), StandardCharsets.UTF_8);
        System.out.println("ManyBool=" + mbSz + " Packed=" + pkSz + " wrote " + out);
    }
}
