import jdk.incubator.vector.FloatVector;
import jdk.incubator.vector.VectorOperators;
import jdk.incubator.vector.VectorSpecies;

/**
 * Vector API (JDK 25, tenth incubator round, JEP 508). Compile and run with --add-modules jdk.incubator.vector.
 * javac --add-modules jdk.incubator.vector J07_VectorApi.java
 */
public class J07_VectorApi {
    static final VectorSpecies<Float> S = FloatVector.SPECIES_PREFERRED;   // Select a width supported by the CPU.

    static float dot(float[] a, float[] b) {
        var acc = FloatVector.zero(S);
        int i = 0, bound = S.loopBound(a.length);
        for (; i < bound; i += S.length()) {
            var va = FloatVector.fromArray(S, a, i);
            var vb = FloatVector.fromArray(S, b, i);
            acc = va.fma(vb, acc);
        }
        float sum = acc.reduceLanes(VectorOperators.ADD);
        for (; i < a.length; i++) sum += a[i] * b[i];                    // Handle the tail with scalar operations.
        return sum;
    }
    public static void main(String[] args) {
        float[] a = new float[1003], b = new float[1003];
        for (int i = 0; i < a.length; i++) { a[i] = 1; b[i] = 2; }
        if (dot(a, b) != 2006f) throw new AssertionError(dot(a, b));
        System.out.println("J07 ok, lanes=" + S.length());
    }
}
