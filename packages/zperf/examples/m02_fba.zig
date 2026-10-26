const std = @import("std");

test "FixedBufferAllocator: 零堆分配" {
    var buf: [4096]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    const a = fba.allocator();

    var list: std.ArrayList(u32) = .empty;
    try list.appendSlice(a, &.{ 1, 2, 3 });
    try std.testing.expectEqual(@as(usize, 3), list.items.len);

// See the English guide for context.
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 8192));
    fba.reset();
}
