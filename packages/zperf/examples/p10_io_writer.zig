const std = @import("std");

/// See the English guide for context.
fn writeReport(w: *std.Io.Writer, rows: []const u32) !void {
    for (rows, 0..) |r, i| try w.print("{d}: {d}\n", .{ i, r });
    try w.splatByteAll('-', 10);
    try w.writeByte('\n');
}

test "buffered writer to file" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const file = try tmp.dir.createFile(io, "out.txt", .{});
    defer file.close(io);

    var buf: [4096]u8 = undefined;
    var fw = file.writer(io, &buf);
    try writeReport(&fw.interface, &.{ 7, 8, 9 });
    try fw.interface.flush();
}

test "Allocating writer" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try writeReport(&aw.writer, &.{1});
    try std.testing.expectEqualStrings("0: 1\n----------\n", aw.written());
}
