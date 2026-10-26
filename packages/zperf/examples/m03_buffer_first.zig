const std = @import("std");

/// See the English guide for context.
fn joinPath(gpa: std.mem.Allocator, parts: []const []const u8) !usize {
    var stack_buf: [256]u8 = undefined;
    var sfa: std.heap.BufferFirstAllocator = .init(&stack_buf, gpa);
    const a = sfa.allocator();
    const joined = try std.mem.join(a, "/", parts);
    defer a.free(joined);
    return joined.len;
}

test "BufferFirstAllocator" {
    try std.testing.expectEqual(@as(usize, 7), try joinPath(std.testing.allocator, &.{ "usr", "bin" }));
    const big: [1000]u8 = @splat('x');
    try std.testing.expectEqual(@as(usize, 2001), try joinPath(std.testing.allocator, &.{ &big, &big }));
}
