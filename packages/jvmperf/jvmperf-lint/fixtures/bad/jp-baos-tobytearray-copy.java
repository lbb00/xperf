import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;

class Enc {
    OutputStream out;
    void onFrameAvailable(byte[] raw) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream(raw.length);
        baos.write(raw);
        out.write(baos.toByteArray());
    }
}
