import java.io.IOException;
import java.io.OutputStream;

class Codec {
    OutputStream out;
    @HotPath
    void sendFrame(byte[] payload) throws IOException {
        byte[] frame = new byte[4 + payload.length];
        System.arraycopy(payload, 0, frame, 4, payload.length);
        out.write(frame);
    }
}
@interface HotPath {}
