const std = @import("std");

/// See the English guide for context.
fn encode(w: *std.Io.Writer, ids: []const u64) !void {
    var prev: u64 = 0;
    for (ids) |id| {
        try w.writeUleb128(id - prev);
        prev = id;
    }
}

fn decode(r: *std.Io.Reader, out: []u64) !void {
    var prev: u64 = 0;
    for (out) |*o| {
        prev += try r.takeLeb128(u64);
        o.* = prev;
    }
}

test "delta + varint" {
    const ids = [_]u64{ 1_000_000, 1_000_003, 1_000_010, 1_000_200 };
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try encode(&w, &ids);
    try std.testing.expectEqual(@as(usize, 3 + 1 + 1 + 2), w.end);

    var r: std.Io.Reader = .fixed(w.buffered());
    var out: [4]u64 = undefined;
    try decode(&r, &out);
    try std.testing.expectEqualSlices(u64, &ids, &out);
}
