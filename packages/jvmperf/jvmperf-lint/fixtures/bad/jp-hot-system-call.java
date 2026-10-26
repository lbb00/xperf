import android.content.Context;
import android.view.accessibility.AccessibilityEvent;
import android.widget.Toast;

class Svc {
    Context ctx;
    public void onAccessibilityEvent(AccessibilityEvent e) {
        Toast.makeText(ctx, "event", Toast.LENGTH_SHORT).show();
    }
}
