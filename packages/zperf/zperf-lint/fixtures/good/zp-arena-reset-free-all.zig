const std = @import("std");
pub fn serve(gpa: std.mem.Allocator, n: usize) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var i: usize = 0;
    while (i < n) : (i += 1) {
        _ = try arena.allocator().alloc(u8, 64);
        _ = arena.reset(.{ .retain_with_limit = 4096 });
    }
}
