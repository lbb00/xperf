const std = @import("std");
const builtin = @import("builtin");

/// Shared metadata + JSONL emission for guide microbenchmarks (Zig 0.17).
/// Fields match the research harness convention used under zig-perf-research/bench-results/.

pub const Result = struct {
    name: []const u8,
    ns_per_op: f64,
    iters: u64,
    note: []const u8 = "",
};

pub fn zigVersion() []const u8 {
    return builtin.zig_version_string;
}

pub fn optimizeMode() []const u8 {
    return @tagName(builtin.mode);
}

pub fn osTag() []const u8 {
    return @tagName(builtin.os.tag);
}

pub fn cpuModel() []const u8 {
    return builtin.cpu.model.name;
}

pub fn cpuArch() []const u8 {
    return @tagName(builtin.cpu.arch);
}

/// Best-of `trials` wall times for a closure that runs `iters` inner operations.
/// `work` must be `fn (*anyopaque) void` or use the typed overload via inline.
pub fn bestNs(
    io: std.Io,
    trials: usize,
    work: *const fn (*anyopaque) void,
    ctx: *anyopaque,
) i96 {
    var best: i96 = std.math.maxInt(i96);
    var t: usize = 0;
    while (t < trials) : (t += 1) {
        const t0: std.Io.Clock.Timestamp = .now(io, .awake);
        work(ctx);
        const dt = t0.untilNow(io);
        best = @min(best, dt.raw.nanoseconds);
    }
    return best;
}

pub fn nsPerOp(total_ns: i96, iters: u64) f64 {
    if (iters == 0) return 0;
    return @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(iters));
}

/// Escape a string for a JSON string value (minimal: \, ", control).
fn writeJsonString(w: *std.Io.Writer, s: []const u8) !void {
    try w.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try w.print("\\u{x:0>4}", .{c});
                } else {
                    try w.writeByte(c);
                }
            },
        }
    }
    try w.writeByte('"');
}

pub fn writeLine(io: std.Io, result: Result) !void {
    var buf: [1024]u8 = undefined;
    var w = std.Io.File.stdout().writerStreaming(io, &buf);
    const out = &w.interface;
    try out.writeByte('{');
    try out.writeAll("\"name\":");
    try writeJsonString(out, result.name);
    try out.print(",\"ns_per_op\":{d:.3}", .{result.ns_per_op});
    try out.print(",\"iters\":{d}", .{result.iters});
    try out.writeAll(",\"zig_version\":");
    try writeJsonString(out, zigVersion());
    try out.writeAll(",\"optimize_mode\":");
    try writeJsonString(out, optimizeMode());
    try out.writeAll(",\"os\":");
    try writeJsonString(out, osTag());
    try out.writeAll(",\"cpu_arch\":");
    try writeJsonString(out, cpuArch());
    try out.writeAll(",\"cpu_model\":");
    try writeJsonString(out, cpuModel());
    try out.writeAll(",\"note\":");
    try writeJsonString(out, result.note);
    try out.writeAll("}\n");
    try out.flush();
}
