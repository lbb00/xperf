const std = @import("std");
const Node = struct { v: u32 };
pub fn make() !*Node {
    const n = try std.heap.smp_allocator.create(Node);
    n.* = .{ .v = 1 };
    return n;
}
pub fn arenaOnPages() void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
}
/// Identifier ending in page_allocator must not trip zp-page-allocator-small.
pub fn hugeOk() ![]u8 {
    const huge_page_allocator = std.heap.smp_allocator;
    return try huge_page_allocator.alloc(u8, 64);
}
