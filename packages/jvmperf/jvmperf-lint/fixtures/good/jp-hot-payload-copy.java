import java.io.IOException;
import java.io.OutputStream;

class Codec {
    OutputStream out;
    final byte[] header = new byte[4];
    @HotPath
    void sendFrame(byte[] payload) throws IOException {
        out.write(header);
        out.write(payload);
    }
}
@interface HotPath {}
