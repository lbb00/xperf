import android.util.ArrayMap;
import android.util.Log;
import android.util.LongSparseArray;
import android.util.SparseArray;
import android.util.SparseBooleanArray;
import android.util.SparseIntArray;

/**
 * Android-only collections. Compile against android.jar stubs; this sample cannot run on a desktop JVM.
 * javac --release 17 -cp $ANDROID_HOME/platforms/android-34/android.jar A01_AndroidCollections.java
 */
public class A01_AndroidCollections {
    private static final String TAG = "Perf";

    static SparseArray<String> namesById(int[] ids, String[] names) {
        SparseArray<String> m = new SparseArray<>(ids.length);   // Replaces HashMap<Integer, String>; no boxing or Entry objects.
        for (int i = 0; i < ids.length; i++) m.put(ids[i], names[i]);
        return m;
    }
    static SparseIntArray histogram(int[] xs) {                  // Replaces HashMap<Integer, Integer>.
        SparseIntArray h = new SparseIntArray();
        for (int x : xs) h.put(x, h.get(x, 0) + 1);
        return h;
    }
    static ArrayMap<String, String> smallMap() {                 // Saves memory for small maps, but lookup uses binary search.
        ArrayMap<String, String> m = new ArrayMap<>(4);
        m.put("k", "v");
        return m;
    }
    static void process(int[] xs) {
        SparseBooleanArray seen = new SparseBooleanArray();
        LongSparseArray<Object> byTs = new LongSparseArray<>();
        for (int x : xs) {
            seen.put(x, true);
            byTs.put(x * 1000L, null);
            // Check the log level before formatting, or move logging out of the loop.
            if (Log.isLoggable(TAG, Log.VERBOSE)) Log.v(TAG, "x=" + x);
        }
        Log.d(TAG, "processed " + xs.length);
    }
}
