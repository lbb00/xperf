import java.lang.management.ManagementFactory;

/** 逃逸分析探针：预热后测量每次调用在堆上分配的字节数。对比 -XX:-EliminateAllocations。 */
public class EaProbe {
    record Vec(double x, double y) {
        Vec plus(Vec o) { return new Vec(x + o.x, y + o.y); }
        double len2() { return x * x + y * y; }
    }
    static double sumLen2(double[] xs, double[] ys) {
        double s = 0;
        for (int i = 0; i < xs.length; i++) s += new Vec(xs[i], ys[i]).plus(new Vec(1, 1)).len2();
        return s;
    }
    public static void main(String[] args) {
        var mx = (com.sun.management.ThreadMXBean) ManagementFactory.getThreadMXBean();
        double[] xs = new double[1000], ys = new double[1000];
        double sink = 0;
        for (int i = 0; i < 20_000; i++) sink += sumLen2(xs, ys);          // 预热，触发 C2
        long tid = Thread.currentThread().threadId();
        long before = mx.getThreadAllocatedBytes(tid);
        for (int i = 0; i < 1000; i++) sink += sumLen2(xs, ys);
        long perCall = (mx.getThreadAllocatedBytes(tid) - before) / 1000;
        System.out.println("每次 sumLen2(1000 元素) 分配约 " + perCall + " 字节 (sink=" + sink + ")");
    }
}
