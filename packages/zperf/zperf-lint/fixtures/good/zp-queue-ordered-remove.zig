const std = @import("std");
const Item = struct { id: u32, data: []u8 };
/// See the English guide for context.
pub const Ring = struct {
    buf: [64]Item = undefined,
    head: usize = 0,
    len: usize = 0,
    pub fn pop(self: *Ring) ?Item {
        if (self.len == 0) return null;
        const it = self.buf[self.head];
        self.head = (self.head + 1) & 63;
        self.len -= 1;
        return it;
    }
};
pub fn prune(items: *std.ArrayList(Item), limit: u32) void {
// See the English guide for context.
    var w: usize = 0;
    for (items.items) |it| {
        if (it.id >= limit) {
            items.items[w] = it;
            w += 1;
        }
    }
    items.shrinkRetainingCapacity(w);
}
pub fn removeId(items: *std.ArrayList(Item), id: u32) void {
// See the English guide for context.
    for (items.items, 0..) |it, i| {
        if (it.id == id) {
            _ = items.orderedRemove(i);
            break;
        }
    }
}
