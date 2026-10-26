pub fn hot(xs: []const u32) u32 {
    var s: u32 = 0;
    {
        @setRuntimeSafety(false);
        for (xs) |x| s +%= x;
    }
    s +%= xs[0];
    s +%= xs[1];
    s +%= xs[2];
    s +%= xs[3];
    s +%= xs[4];
    s +%= xs[5];
    s +%= xs[6];
    s +%= xs[7];
    s +%= xs[8];
    s +%= xs[9];
    s +%= xs[10];
    s +%= xs[11];
    s +%= xs[12];
    s +%= xs[13];
    s +%= xs[14];
    s +%= xs[15];
    s +%= xs[16];
    s +%= xs[17];
    s +%= xs[18];
    s +%= xs[19];
    s +%= xs[20];
    s +%= xs[21];
    s +%= xs[22];
    s +%= xs[23];
    s +%= xs[24];
    s +%= xs[25];
    s +%= xs[26];
    s +%= xs[27];
    s +%= xs[28];
    s +%= xs[29];
    return s;
}
