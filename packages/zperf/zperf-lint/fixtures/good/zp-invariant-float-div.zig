pub fn normalize(xs: []f32, n: usize) void {
    const n_f: f32 = @floatFromInt(n);
    const inv = 1.0 / n_f;
    for (xs) |*x| {
        x.* = x.* * inv;
    }
}
pub fn ratios(out: []f32, xs: []const f32) void {
// See the English guide for context.
    for (out, xs) |*o, x| {
        o.* = 1.0 / x;
    }
}
