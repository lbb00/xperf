const std = @import("std");
const builtin = @import("builtin");

// See the English guide for context.
test "io_uring nop batch" {
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;
    var ring = std.os.linux.IoUring.init(8, 0) catch return error.SkipZigTest;
    defer ring.deinit();
    for (0..4) |i| _ = try ring.nop(@intCast(i));
    try std.testing.expectEqual(@as(u32, 4), try ring.submit());
    var cqes: [4]std.os.linux.io_uring_cqe = undefined;
    const n = try ring.copy_cqes(&cqes, 4);
    try std.testing.expectEqual(@as(u32, 4), n);
}
