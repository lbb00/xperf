const std = @import("std");
pub fn good(io: std.Io, n: u32) !u32 {
    const f = try std.Io.Dir.openFileAbsolute(io, "one.txt", .{});
    defer f.close(io);
    var s: u32 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) s += 1;
    return s;
}
