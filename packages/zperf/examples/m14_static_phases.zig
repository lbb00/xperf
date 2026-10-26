const std = @import("std");

/// Teaching stub: allocator that asserts a lifecycle phase.
/// Inspired by TigerBeetle's StaticAllocator (Apache-2.0); original code for the guide.
const Phase = enum { init, static, deinit };

const PhaseAllocator = struct {
    child: std.mem.Allocator,
    phase: Phase = .init,

    fn allocator(self: *PhaseAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn transitionToStatic(self: *PhaseAllocator) void {
        std.debug.assert(self.phase == .init);
        self.phase = .static;
    }

    fn transitionToDeinit(self: *PhaseAllocator) void {
        std.debug.assert(self.phase == .static);
        self.phase = .deinit;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        // Allow free during init (errdefer) and deinit; forbid during static.
        std.debug.assert(self.phase != .static);
        self.child.rawFree(memory, alignment, ret_addr);
    }
};

test "phase allocator: alloc only in init" {
    var phase: PhaseAllocator = .{ .child = std.testing.allocator };
    const a = phase.allocator();
    const buf = try a.alloc(u8, 32);
    phase.transitionToStatic();
    // Steady-state: no more alloc/resize/free through this wrapper.
    phase.transitionToDeinit();
    a.free(buf);
}
