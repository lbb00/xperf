import java.util.concurrent.atomic.AtomicIntegerFieldUpdater;
class JpNonStaticFieldUpdater {
    volatile int x;
    // non-static updater — bad
    final AtomicIntegerFieldUpdater<JpNonStaticFieldUpdater> updater =
            AtomicIntegerFieldUpdater.newUpdater(JpNonStaticFieldUpdater.class, "x");
}
