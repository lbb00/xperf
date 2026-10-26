const std = @import("std");

/// See the English guide for context.
fn handleRequests(gpa: std.mem.Allocator, requests: []const []const u8) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();

    var total: usize = 0;
    for (requests) |req| {
// See the English guide for context.
        defer _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();

        const upper = try arena.alloc(u8, req.len);
        for (upper, req) |*d, s| d.* = std.ascii.toUpper(s);
        const msg = try arena.print("{s}!", .{upper}); // 0.17: fmt.allocPrint -> Allocator.print
        total += msg.len;
    }
    return total;
}

test "arena retain_capacity" {
    const reqs = [_][]const u8{ "get", "post", "delete" };
    try std.testing.expectEqual(@as(usize, 16), try handleRequests(std.testing.allocator, &reqs));
}
