import java.util.concurrent.atomic.AtomicIntegerFieldUpdater;
class JpNonStaticFieldUpdater {
    volatile int x;
    private static final AtomicIntegerFieldUpdater<JpNonStaticFieldUpdater> UPDATER =
            AtomicIntegerFieldUpdater.newUpdater(JpNonStaticFieldUpdater.class, "x");
}
