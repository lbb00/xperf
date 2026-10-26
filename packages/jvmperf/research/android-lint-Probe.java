import android.util.Log;
import java.util.HashMap;
class Probe {
    HashMap<Integer, String> m = new HashMap<Integer, String>();
    void f(int[] xs) { for (int x : xs) Log.d("T", "x=" + x); Integer i = new Integer(3); }
}
