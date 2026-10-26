const std = @import("std");

const Untagged = union { i: u32, f: f32 };
const Tagged = union(enum) { i: u32, f: f32 };
const CUnion = extern union { i: u32, f: f32 };

test "union 开销" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Tagged)); // 4 + tag(1) + 3 pad
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(CUnion));
    const u: CUnion = .{ .f = 1.0 };
    try std.testing.expectEqual(@as(u32, 0x3f800000), u.i);
    _ = Untagged;
}

// See the English guide for context.
test "MultiArrayList(tagged union) 拆 tag" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Tagged) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, .{ .i = 1 });
    try list.append(gpa, .{ .f = 2.0 });
    try std.testing.expectEqual(@as(usize, 2), list.items(.tags).len);
    try std.testing.expectEqual(Tagged{ .f = 2.0 }, list.get(1));
}
