const std = @import("std");

/// See the English guide for context.
const Field = struct { key: []const u8, value: []const u8 };

fn parseLine(line: []const u8) ?Field {
    const eq = std.mem.findScalar(u8, line, '=') orelse return null; // 0.16: indexOfScalar -> findScalar
    return .{
        .key = std.mem.trim(u8, line[0..eq], " "),
        .value = std.mem.trim(u8, line[eq + 1 ..], " "),
    };
}

test "zero-copy" {
    const input = "name = zig\nversion= 0.17\n";
    var it = std.mem.splitScalar(u8, input, '\n');
    var n: usize = 0;
    while (it.next()) |line| {
        const f = parseLine(line) orelse continue;
// See the English guide for context.
        try std.testing.expect(@intFromPtr(f.key.ptr) >= @intFromPtr(input.ptr));
        n += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), n);
}
