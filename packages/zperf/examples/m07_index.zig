const std = @import("std");

/// See the English guide for context.
const NodeIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    fn from(i: usize) NodeIndex {
        return @fromBackingInt(@intCast(i));
    }
    fn get(self: NodeIndex) u32 {
        return @backingInt(self);
    }
};

const Node = struct { value: i32, left: NodeIndex, right: NodeIndex };

test "索引代替指针" {
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(Node));
    const nodes = [_]Node{
        .{ .value = 2, .left = .from(1), .right = .none },
        .{ .value = 1, .left = .none, .right = .none },
    };
    try std.testing.expectEqual(@as(i32, 1), nodes[nodes[0].left.get()].value);
}
