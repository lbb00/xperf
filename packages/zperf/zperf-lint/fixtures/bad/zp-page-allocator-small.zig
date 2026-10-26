const std = @import("std");
const Node = struct { v: u32 };
pub fn make() !*Node {
    const n = try std.heap.page_allocator.create(Node);
    n.* = .{ .v = 1 };
    return n;
}
pub fn fill(list: *std.ArrayList(u8)) !void {
    try list.append(std.heap.page_allocator, 'x');
}
