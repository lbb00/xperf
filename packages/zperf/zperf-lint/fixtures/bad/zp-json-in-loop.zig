const std = @import("std");
const Payload = struct { id: u32 };
pub fn bad(alloc: std.mem.Allocator, n: u32) !u32 {
    var s: u32 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        var parsed = try std.json.parseFromSlice(Payload, alloc, "{\"id\":7}", .{});
        s += parsed.value.id;
        parsed.deinit();
    }
    return s;
}
