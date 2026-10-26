const std = @import("std");
const Particle = struct { pos: [3]f32, vel: [3]f32, mass: f32, color: u32 };
pub fn totalMass(list: std.ArrayList(Particle)) f32 {
    var m: f32 = 0;
    for (list.items) |p| m += p.mass;
    return m;
}
