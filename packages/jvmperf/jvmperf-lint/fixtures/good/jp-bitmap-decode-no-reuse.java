import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

class Decoder {
    Bitmap last;
    final BitmapFactory.Options opts = new BitmapFactory.Options();
    void onFrameAvailable(byte[] jpeg) {
        opts.inMutable = true;
        opts.inBitmap = last;
        last = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length, opts);
    }
}
