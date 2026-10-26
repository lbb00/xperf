const std = @import("std");
pub fn bad(io: std.Io, n: u32) !void {
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        const f = try std.Io.Dir.openFileAbsolute(io, "one.txt", .{});
        f.close(io);
    }
}
