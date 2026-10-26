const std = @import("std");
pub fn squares(gpa: std.mem.Allocator, xs: []const u32) !std.ArrayList(u32) {
    var out: std.ArrayList(u32) = .empty;
    errdefer out.deinit(gpa);
    try out.ensureUnusedCapacity(gpa, xs.len);
    for (xs) |x| {
        out.appendAssumeCapacity(x * x);
    }
    return out;
}

pub fn arenaSquares(gpa: std.mem.Allocator, xs: []const u32) ![]u32 {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();
    var out: std.ArrayList(u32) = .empty;
    for (xs) |x| {
        try out.append(alloc, x * x);
    }
    return out.toOwnedSlice(alloc);
}
