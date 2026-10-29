// jvmperf-lint: ignore-file jp-format-hot
import java.util.*;
class Ignored {
    org.slf4j.Logger log;
    // jvmperf-lint: ignore jp-boxed-primitive-collection -- The public API requires List<Integer>.
    List<Integer> api;
    void process(int[] xs) {
        for (int x : xs) {
            log.debug("x=" + x); // jvmperf-lint: ignore log-hot
            // jvmperf-lint: ignore
            log.debug("y=" + (x + 1));
            String.format("%d", x);
        }
    }
}
