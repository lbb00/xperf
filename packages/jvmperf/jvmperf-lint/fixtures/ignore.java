// jvmperf-lint: ignore-file jp-format-in-loop
import java.util.*;
class Ignored {
    org.slf4j.Logger log;
    // jvmperf-lint: ignore JpBoxedPrimitiveCollection -- The public API requires List<Integer>.
    List<Integer> api;
    void process(int[] xs) {
        for (int x : xs) {
            log.debug("x=" + x); // jvmperf-lint: ignore log-in-loop
            // jvmperf-lint: ignore
            log.debug("y=" + (x + 1));
            String.format("%d", x);
        }
    }
}
