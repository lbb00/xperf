const std = @import("std");

/// Keepalive-style request loop: reset with a byte cap so one huge request
/// does not pin peak RSS forever. See Zig ArenaAllocator.ResetMode.retain_with_limit
/// and http.zig requestDone → retain_with_limit (MIT).
fn handleWithBound(gpa: std.mem.Allocator, bodies: []const []const u8, retain_limit: usize) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();

    var total: usize = 0;
    for (bodies) |body| {
        defer _ = arena_state.reset(.{ .retain_with_limit = retain_limit });
        const arena = arena_state.allocator();
        const copy = try arena.dupe(u8, body);
        total += copy.len;
    }
    return total;
}

test "arena retain_with_limit" {
    var big: [200]u8 = undefined;
    @memset(&big, 'x');
    const bodies = [_][]const u8{ "small", &big, "again" };
    const n = try handleWithBound(std.testing.allocator, &bodies, 64);
    try std.testing.expectEqual(@as(usize, 5 + 200 + 5), n);
}
