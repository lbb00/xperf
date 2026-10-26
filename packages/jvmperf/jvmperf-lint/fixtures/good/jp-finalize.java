import java.lang.ref.Cleaner;
class JpFinalize implements AutoCloseable {
    private static final Cleaner CLEANER = Cleaner.create();
    private final Cleaner.Cleanable cleanable = CLEANER.register(this, () -> { });
    @Override public void close() { cleanable.clean(); }
}
