const std = @import("std");

// See the English guide for context.
test "memory-mapped file" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile(io, "data.bin", .{ .read = true });
    defer file.close(io);
    try file.writeStreamingAll(io, "hello mmap");

    var map = try file.createMemoryMap(io, .{ .len = 10, .protection = .{ .read = true } });
    defer map.destroy(io);
    try std.testing.expectEqualStrings("hello mmap", map.memory[0..10]);
}
