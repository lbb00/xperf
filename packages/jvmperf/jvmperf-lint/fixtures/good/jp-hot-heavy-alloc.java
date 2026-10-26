import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.View;

class Marker extends View {
    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    Marker(android.content.Context c) { super(c); }
    @Override protected void onDraw(Canvas canvas) {
        stamp(canvas);
    }
    private void stamp(Canvas canvas) {
        canvas.drawCircle(10f, 10f, 5f, p);
    }
    // Creating Paint in a cold function is fine.
    Paint makeOnce() { return new Paint(); }
    // Propagated heat into error() must not fire JpHotHeavyAlloc.
    void onDrawFrame() {
        for (int i = 0; i < 10; i++) error(i);
    }
    void error(int i) {
        StringBuilder sb = new StringBuilder();
        sb.append(i);
    }
}
