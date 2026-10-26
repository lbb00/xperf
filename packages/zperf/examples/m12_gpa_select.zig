const std = @import("std");
const builtin = @import("builtin");

/// See the English guide for context.
/// See the English guide for context.
var safe_state: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});

pub fn main() !void {
    const gpa, const is_safe = switch (builtin.mode) {
        .debug, .safe => .{ safe_state.allocator(), true },
// See the English guide for context.
        .fast, .small => .{ if (builtin.link_libc) std.heap.c_allocator else if (!builtin.single_threaded) std.heap.smp_allocator else std.heap.page_allocator, false },
    };
    defer if (is_safe) {
        const leaks = safe_state.deinit();
        if (leaks != 0) std.process.exit(1);
    };

    const xs = try gpa.alloc(u64, 1000);
    defer gpa.free(xs);
    @memset(xs, 0);
}
