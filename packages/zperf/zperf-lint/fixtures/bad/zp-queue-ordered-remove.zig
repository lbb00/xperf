const std = @import("std");
const Item = struct { id: u32, data: []u8 };
pub const Queue = struct {
    items: std.ArrayList(Item) = .empty,
    pub fn pop(self: *Queue) ?Item {
        if (self.items.items.len == 0) return null;
        return self.items.orderedRemove(0);
    }
    pub fn prune(self: *Queue, limit: u32) void {
        var i: usize = 0;
        while (i < self.items.items.len) {
            if (self.items.items[i].id < limit) {
                _ = self.items.orderedRemove(i);
            } else i += 1;
        }
    }
};
