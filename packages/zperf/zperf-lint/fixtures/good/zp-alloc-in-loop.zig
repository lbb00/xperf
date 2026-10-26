const std = @import("std");
const Blob = struct {
    fn dupe(self: Blob, arena: std.mem.Allocator) !Blob {
        _ = self;
        _ = arena;
        return .{};
    }
};
const Sema = struct { arena: std.mem.Allocator };
pub fn upperAll(gpa: std.mem.Allocator, words: []const []const u8) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    var total: usize = 0;
    for (words) |w| {
        defer _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();
        const tmp = try arena.alloc(u8, w.len);
        total += tmp.len;
    }
    return total;
}
pub fn coerceParams(sema: *Sema, items: []const Blob) !void {
    for (items) |param| {
        // Arena-backed method dupe must not fire zp-alloc-in-loop (aligned with zp-append-without-reserve soft-arena).
        const child = try param.dupe(sema.arena);
        _ = child;
    }
}
