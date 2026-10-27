const std = @import("std");
const Payload = struct { id: u32 };
pub fn good(alloc: std.mem.Allocator, n: u32) !u32 {
    var parsed = try std.json.parseFromSlice(Payload, alloc, "{\"id\":7}", .{});
    defer parsed.deinit();
    var s: u32 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) s += parsed.value.id;
    return s;
}
