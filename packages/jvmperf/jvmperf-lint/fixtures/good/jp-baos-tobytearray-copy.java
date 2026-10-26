import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;

class Enc {
    OutputStream out;
    final ByteArrayOutputStream baos = new ByteArrayOutputStream(1 << 16);
    void onFrameAvailable(byte[] raw) throws IOException {
        baos.reset();
        baos.write(raw);
        baos.writeTo(out);
    }
}
