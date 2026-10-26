const std = @import("std");
pub fn pump(stream: anytype) void {
    var buf: [64]u8 = undefined;
    _ = stream.read(&buf) catch unreachable;
}
