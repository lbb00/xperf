const std = @import("std");

/// See the English guide for context.
const Monster = struct { hp: u32, x: u32, y: u32 };

const World = struct {
    alive: std.ArrayList(Monster) = .empty,
    dead: std.ArrayList(Monster) = .empty,

    fn kill(w: *World, gpa: std.mem.Allocator, i: usize) !void {
        try w.dead.ensureUnusedCapacity(gpa, 1);
        w.dead.appendAssumeCapacity(w.alive.swapRemove(i));
    }
    fn tick(w: *World) void {
        // zperf-lint: ignore zp-aos-single-field
        for (w.alive.items) |*m| m.hp -|= 1;
    }
};

/// See the English guide for context.
const Hot = struct { pos: [2]f32, vel: [2]f32 };
const Cold = struct { name: []const u8, created_ms: u64 };

test "out-of-band bool + hot/cold split" {
    const gpa = std.testing.allocator;
    var w: World = .{};
    defer w.alive.deinit(gpa);
    defer w.dead.deinit(gpa);
    try w.alive.appendSlice(gpa, &.{ .{ .hp = 3, .x = 0, .y = 0 }, .{ .hp = 5, .x = 1, .y = 1 } });
    try w.kill(gpa, 0);
    w.tick();
    try std.testing.expectEqual(@as(usize, 1), w.alive.items.len);
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(Monster));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Hot));
    _ = Cold;
}
