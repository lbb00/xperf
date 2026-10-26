const std = @import("std");

const Kind = enum { int, float, string, bool };

const keywords = std.StaticStringMap(Kind).initComptime(.{
    .{ "int", .int },
    .{ "float", .float },
    .{ "string", .string },
    .{ "bool", .bool },
});

test "EnumArray 代替 HashMap(enum, V)" {
    var counts: std.EnumArray(Kind, u32) = .initFill(0);
    counts.getPtr(.float).* += 1;
    try std.testing.expectEqual(@as(u32, 1), counts.get(.float));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(@TypeOf(counts)));
}

test "StaticStringMap：编译期构建的只读字符串表（按长度分桶），零运行时分配" {
    try std.testing.expectEqual(Kind.float, keywords.get("float").?);
    try std.testing.expect(keywords.get("double") == null);
}
