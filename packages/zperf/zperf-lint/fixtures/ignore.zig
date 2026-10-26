const std = @import("std");
// zperf-lint: ignore-file zp-packable-bools
pub const Flags = struct { a: bool, b: bool, c: bool };
pub fn dump(xs: []const u32) void {
    for (xs) |x| {
        // zperf-lint: ignore print-in-loop
        std.debug.print("{d}\n", .{x});
        std.debug.print("{d}\n", .{x}); // zperf-lint: ignore zp-print-in-loop
    }
}
