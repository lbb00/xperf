import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

class Decoder {
    Bitmap last;
    void onFrameAvailable(byte[] jpeg) {
        last = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length);
    }
}
