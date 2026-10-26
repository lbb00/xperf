/** Array of Structures vs Structure of Arrays: SoA is contiguous and header-free when scanning one field. */
public class J04_SoA {
    static final class Particle { double x, y, vx, vy; boolean alive; }   // AoS: each particle is a separate heap object.

    static final class Particles {                                       // SoA: one primitive array per field.
        final double[] x, y, vx, vy;
        final long[] alive;                                              // Store liveness flags out of band in a bitmap.
        int size;
        Particles(int cap) {
            x = new double[cap]; y = new double[cap]; vx = new double[cap]; vy = new double[cap];
            alive = new long[(cap + 63) >>> 6];
        }
        int add(double px, double py, double pvx, double pvy) {
            int i = size++;
            x[i] = px; y[i] = py; vx[i] = pvx; vy[i] = pvy; alive[i >>> 6] |= 1L << i;
            return i;
        }
        void step(double dt) {                                           // The hot loop touches only the needed arrays.
            for (int i = 0; i < size; i++) { x[i] += vx[i] * dt; y[i] += vy[i] * dt; }
        }
    }

    public static void main(String[] args) {
        Particles ps = new Particles(1024);
        for (int i = 0; i < 1000; i++) ps.add(i, 0, 1, 2);
        ps.step(0.5);
        if (ps.x[10] != 10.5 || ps.y[10] != 1.0) throw new AssertionError();
        Particle[] aos = new Particle[1000];
        for (int i = 0; i < aos.length; i++) { aos[i] = new Particle(); aos[i].x = i; aos[i].vx = 1; }
        for (Particle p : aos) p.x += p.vx * 0.5;
        if (aos[10].x != ps.x[10]) throw new AssertionError();
        System.out.println("J04 ok");
    }
}
