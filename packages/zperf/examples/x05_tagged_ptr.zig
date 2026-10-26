const std = @import("std");

/// See the English guide for context.
const Tag = enum(u3) { leaf, branch, deleted };

const TaggedPtr = packed struct(usize) {
    tag: Tag,
    addr_hi: @Int(.unsigned, @bitSizeOf(usize) - 3),

    fn init(p: *align(8) u64, tag: Tag) TaggedPtr {
        return .{ .tag = tag, .addr_hi = @intCast(@intFromPtr(p) >> 3) };
    }
    fn ptr(self: TaggedPtr) *align(8) u64 {
        return @ptrFromInt(@as(usize, self.addr_hi) << 3);
    }
};

test "tagged pointer" {
    var x: u64 align(8) = 7;
    const tp: TaggedPtr = .init(&x, .branch);
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(TaggedPtr));
    try std.testing.expectEqual(Tag.branch, tp.tag);
    try std.testing.expectEqual(@as(u64, 7), tp.ptr().*);
}
