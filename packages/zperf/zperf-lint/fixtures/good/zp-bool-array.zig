const std = @import("std");
var seen: std.bit_set.Static(4096) = .empty;
var small: [4]bool = undefined;
pub fn count(flags: *const std.bit_set.Static(4096)) usize {
    return flags.count();
}
