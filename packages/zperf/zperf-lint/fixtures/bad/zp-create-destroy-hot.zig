const std = @import("std");
const Node = struct { x: i32 };
pub fn drip(gpa: std.mem.Allocator, n: usize) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const node = try gpa.create(Node);
        defer gpa.destroy(node);
        node.* = .{ .x = @intCast(i) };
    }
}
