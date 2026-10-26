const std = @import("std");

// See the English guide for context.
test "栈上有界列表" {
    var buffer: [8]i32 = undefined;
    var stack: std.ArrayList(i32) = .initBuffer(&buffer);
    try stack.appendSliceBounded(&.{ 1, 2, 3 });
    try stack.appendBounded(4);
    try std.testing.expectEqual(@as(usize, 4), stack.items.len);
    try stack.appendSliceBounded(&.{ 5, 6, 7, 8 });
    try std.testing.expectError(error.OutOfMemory, stack.appendBounded(9));
}
