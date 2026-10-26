const std = @import("std");
pub fn writeAll(io: std.Io, file: std.Io.File, lines: []const []const u8) !void {
    var fw = file.writer(io, &.{});
    for (lines) |l| try fw.interface.writeAll(l);
}
