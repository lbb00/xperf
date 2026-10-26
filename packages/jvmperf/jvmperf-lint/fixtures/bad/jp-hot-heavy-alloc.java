import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.View;

class Marker extends View {
    Marker(android.content.Context c) { super(c); }
    @Override protected void onDraw(Canvas canvas) {
        stamp(canvas);
    }
    private void stamp(Canvas canvas) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        canvas.drawCircle(10f, 10f, 5f, p);
    }
}
