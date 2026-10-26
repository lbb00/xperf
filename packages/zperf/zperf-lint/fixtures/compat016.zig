// See the English guide for context.
const msg = "a ** b";
pub fn zeros() [8]u8 {
    var buf: [8]u8 = .{0} ** 8;
    buf[0] = msg[0];
    return buf;
}
