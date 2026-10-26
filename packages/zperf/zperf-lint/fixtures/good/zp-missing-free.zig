const std = @import("std");
pub fn sum(gpa: std.mem.Allocator, n: usize) !u64 {
    const xs = try gpa.alloc(u64, n);
    defer gpa.free(xs);
    @memset(xs, 1);
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 1);
    var s: u64 = 0;
    for (xs) |x| s += x;
    return s;
}
pub fn makeOwned(gpa: std.mem.Allocator) ![]u8 {
    const buf = try gpa.alloc(u8, 16);
    return buf;
}
pub fn collect(gpa: std.mem.Allocator) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(gpa);
    try list.append(gpa, 1);
    return list.toOwnedSlice(gpa);
}
/// See the English guide for context.
pub fn arenaCollect(arena: std.mem.Allocator) !usize {
    var hits: std.ArrayList(u32) = .empty;
    try hits.append(arena, 1);
    try hits.append(arena, 2);
    return hits.items.len;
}
fn fill(arena: std.mem.Allocator, out: *std.ArrayList(u32)) !void {
    try out.append(arena, 7);
}
pub fn arenaHelper(arena: std.mem.Allocator) !usize {
    var acc: std.ArrayList(u32) = .empty;
    try fill(arena, &acc);
    return acc.items.len;
}
/// create + release handoff
const Attrs = struct {
    fn create(gpa: std.mem.Allocator) !*Attrs {
        return try gpa.create(Attrs);
    }
    fn release(self: *Attrs, gpa: std.mem.Allocator) void {
        gpa.destroy(self);
    }
};
pub fn withRelease(gpa: std.mem.Allocator) !void {
    const attrs = try Attrs.create(gpa);
    defer attrs.release(gpa);
}
/// ArenaAllocator + alloc alias
pub fn arenaAllocAlias(gpa: std.mem.Allocator) !usize {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();
    var list: std.ArrayList(u32) = .empty;
    try list.append(alloc, 1);
    return list.items.len;
}
/// append ownership transfer
pub fn stash(gpa: std.mem.Allocator, out: *std.ArrayList(*u32)) !void {
    const p = try gpa.create(u32);
    p.* = 7;
    try out.append(gpa, p);
}
