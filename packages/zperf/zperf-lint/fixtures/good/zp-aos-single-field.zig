const std = @import("std");
const Particle = struct { pos: [3]f32, vel: [3]f32, mass: f32, color: u32 };
pub fn totalMass(list: std.MultiArrayList(Particle)) f32 {
    var m: f32 = 0;
    for (list.items(.mass)) |mass| m += mass;
    return m;
}
pub fn step(list: std.ArrayList(Particle)) void {
    for (list.items) |*p| {
        p.pos[0] += p.vel[0];
    }
}
const Packet = struct { seq: u32, data: []u8, sent_at: i64 };
pub fn deinitQueue(gpa: std.mem.Allocator, q: *std.ArrayList(Packet)) void {
    for (q.items) |pkt| {
        gpa.free(pkt.data);
    }
    q.deinit(gpa);
}
