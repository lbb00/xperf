const std = @import("std");
const Node = struct { x: i32 };
pub fn drip(gpa: std.mem.Allocator, n: usize) !void {
    var pool: std.heap.MemoryPool(Node) = .empty;
    defer pool.deinit(gpa);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const node = try pool.create(gpa);
        defer pool.destroy(node);
        node.* = .{ .x = @intCast(i) };
    }
}
