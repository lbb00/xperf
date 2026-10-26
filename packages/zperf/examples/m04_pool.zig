const std = @import("std");

const Node = struct { value: u64, next: ?*Node };

test "MemoryPool: 定长对象 O(1) 分配/回收，free list 复用" {
    const gpa = std.testing.allocator;
    var pool: std.heap.MemoryPool(Node) = try .initCapacity(gpa, 64);
    defer pool.deinit(gpa);

    const a = try pool.create(gpa);
    a.* = .{ .value = 1, .next = null };
    pool.destroy(a);
    const b = try pool.create(gpa);
    try std.testing.expect(a == b);
}
