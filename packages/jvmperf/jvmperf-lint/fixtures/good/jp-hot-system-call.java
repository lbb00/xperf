import android.content.Context;
import android.view.accessibility.AccessibilityEvent;
import android.widget.Toast;

class Svc {
    Context ctx;
    int events;
    public void onAccessibilityEvent(AccessibilityEvent e) {
        events++;
    }
    void summary() {
        Toast.makeText(ctx, "events " + events, Toast.LENGTH_SHORT).show();
    }
    void onMeasure() {
        float density = ctx.getResources().getDisplayMetrics().density;
    }
}
