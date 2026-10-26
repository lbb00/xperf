const std = @import("std");
pub fn pump(stream: anytype) !void {
    var buf: [64]u8 = undefined;
    _ = try stream.read(&buf);
}
pub fn cleanup(sock: anytype) void {
    // Intentional: close failures are ignored in many codebases.
    sock.close() catch unreachable;
}
test "io in test is skipped" {
    const S = struct {
        fn accept() !void {
            return error.WouldBlock;
        }
    };
    S.accept() catch unreachable;
}
