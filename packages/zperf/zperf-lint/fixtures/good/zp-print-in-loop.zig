const std = @import("std");
const log = std.log.scoped(.demo);

pub fn dump(w: *std.Io.Writer, xs: []const u32) !void {
    for (xs, 0..) |x, i| {
        try w.print("{d}: {d}\n", .{ i, x });
        // Structured logging is excluded from zp-print-in-loop by default (see --strict-log-in-loop).
        log.debug("item {d}={d}", .{ i, x });
    }
    try w.flush();
    std.debug.print("done\n", .{});
}

/// Diagnostic prints behind `if (log)` are not hot unbuffered I/O.
pub fn gated(xs: []const u32) void {
    const log = false;
    for (xs) |x| {
        if (log) std.debug.print("{d}\n", .{x});
        _ = x;
    }
}
