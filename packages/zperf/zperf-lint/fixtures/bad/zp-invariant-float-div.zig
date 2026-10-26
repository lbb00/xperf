pub fn normalize(xs: []f32, n: usize) void {
    const n_f: f32 = @floatFromInt(n);
    for (xs) |*x| {
        x.* = x.* / n_f;
    }
}
