//! zperf-lint evidence microbenches (Zig 0.17). Emits cperf-style JSONL to stdout.
//! Build: zig build-exe -Ofast evidence_fill.zig
//! zperf-lint: ignore-file zp-alloc-hot zp-append-without-reserve zp-page-allocator-small zp-print-hot zp-unbuffered-io zp-aos-single-field zp-catch-unreachable-alloc zp-runtime-div-hot zp-queue-ordered-remove zp-per-packet-alloc zp-invariant-float-div zp-map-put-without-ensure zp-arena-reset-free-all zp-create-destroy-hot zp-fixed-size-alloc-hot -- intentional smell/fix pairs

const std = @import("std");
const builtin = @import("builtin");

const trials: usize = 9;
const warm: usize = 2;

fn nowNs(io: std.Io) i128 {
    return @intCast(std.Io.Clock.Timestamp.now(io, .awake).raw.nanoseconds);
}

fn medianNs(samples: []i128) i128 {
    std.mem.sort(i128, samples, {}, comptime std.sort.asc(i128));
    return samples[samples.len / 2];
}

fn emit(
    io: std.Io,
    rule: []const u8,
    case_name: []const u8,
    role: []const u8,
    median_ns: i128,
    ops: u64,
    ratio: f64,
    ts: []const u8,
) !void {
    const median_ms = @as(f64, @floatFromInt(median_ns)) / 1_000_000.0;
    var buf: [512]u8 = undefined;
    var w = std.Io.File.stdout().writerStreaming(io, &buf);
    const out = &w.interface;
    try out.print(
        "{{\"rule\":\"{s}\",\"case\":\"{s}\",\"role\":\"{s}\",\"zig\":\"{s}\",\"optimize\":\"{s}\",\"median_ms\":{d:.6},\"ops\":{d},\"ratio\":{d:.6},\"ts\":\"{s}\"}}\n",
        .{ rule, case_name, role, builtin.zig_version_string, @tagName(builtin.mode), median_ms, ops, ratio, ts },
    );
    try out.flush();
}

fn timeWork(io: std.Io, work: *const fn (*anyopaque) void, ctx: *anyopaque) i128 {
    var i: usize = 0;
    while (i < warm) : (i += 1) work(ctx);
    var samples: [trials]i128 = undefined;
    i = 0;
    while (i < trials) : (i += 1) {
        const t0 = nowNs(io);
        work(ctx);
        samples[i] = nowNs(io) - t0;
    }
    return medianNs(samples[0..]);
}

// ---------- zp-alloc-hot: alloc in loop vs arena ----------
const Zp001 = struct {
    const ops: u64 = 100_000;
    const block: usize = 64;
    gpa: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp001 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            const buf = self.gpa.alloc(u8, block) catch unreachable;
            buf[0] = @truncate(i);
            self.sink +%= buf[0];
            self.gpa.free(buf);
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp001 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            defer _ = self.arena.reset(.retain_capacity);
            const a = self.arena.allocator();
            const buf = a.alloc(u8, block) catch unreachable;
            buf[0] = @truncate(i);
            self.sink +%= buf[0];
        }
    }
};

// ---------- zp-append-without-reserve: append without reserve ----------
const Zp002 = struct {
    const n: usize = 50_000;
    gpa: std.mem.Allocator,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp002 = @ptrCast(@alignCast(ptr));
        var list: std.ArrayList(u32) = .empty;
        defer list.deinit(self.gpa);
        var i: u32 = 0;
        while (i < n) : (i += 1) {
            list.append(self.gpa, i) catch unreachable;
        }
        self.sink +%= list.items[n - 1];
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp002 = @ptrCast(@alignCast(ptr));
        var list: std.ArrayList(u32) = .empty;
        defer list.deinit(self.gpa);
        list.ensureTotalCapacity(self.gpa, n) catch unreachable;
        var i: u32 = 0;
        while (i < n) : (i += 1) {
            list.appendAssumeCapacity(i);
        }
        self.sink +%= list.items[n - 1];
    }
};

// ---------- zp-page-allocator-small: page_allocator small vs smp/c ----------
const Zp003 = struct {
    const ops: u64 = 20_000;
    const block: usize = 64;
    page: std.mem.Allocator,
    fast: std.mem.Allocator,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp003 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            const buf = self.page.alloc(u8, block) catch unreachable;
            buf[0] = @truncate(i);
            self.sink +%= buf[0];
            self.page.free(buf);
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp003 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            const buf = self.fast.alloc(u8, block) catch unreachable;
            buf[0] = @truncate(i);
            self.sink +%= buf[0];
            self.fast.free(buf);
        }
    }
};

// ---------- zp-large-struct-by-value: large struct by value vs *const ----------
const Big = struct {
    a: [24]u64 = @splat(0), // 192 bytes
};
const Zp005 = struct {
    const ops: u64 = 2_000_000;
    item: Big = .{},
    sink: u64 = 0,

    fn sumVal(b: Big) u64 {
        var s: u64 = 0;
        for (b.a) |x| s +%= x;
        return s;
    }
    fn sumPtr(b: *const Big) u64 {
        var s: u64 = 0;
        for (b.a) |x| s +%= x;
        return s;
    }
    fn before(ptr: *anyopaque) void {
        const self: *Zp005 = @ptrCast(@alignCast(ptr));
        self.item.a[0] = 1;
        self.item.a[23] = 2;
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            self.sink +%= sumVal(self.item);
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp005 = @ptrCast(@alignCast(ptr));
        self.item.a[0] = 1;
        self.item.a[23] = 2;
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            self.sink +%= sumPtr(&self.item);
        }
    }
};

// ---------- zp-print-hot: debug.print in loop vs quiet sink ----------
const Zp006 = struct {
    const ops: u64 = 2_000;
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp006 = @ptrCast(@alignCast(ptr));
        // Redirect is not available; keep N small — cost is lock+format+write stderr.
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            std.debug.print(".", .{});
            self.sink +%= 1;
        }
        std.debug.print("\n", .{});
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp006 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            self.sink +%= 1;
        }
        std.mem.doNotOptimizeAway(self.sink);
    }
};

// ---------- zp-unbuffered-io: empty writer vs 4KiB ----------
const Zp007 = struct {
    const n_writes: usize = 50_000;
    const payload = "0123456789abcdef";
    io: std.Io,
    file: std.Io.File,
    buffer: []u8,
    sink: u64 = 0,

    fn run(ptr: *anyopaque) void {
        const self: *Zp007 = @ptrCast(@alignCast(ptr));
        var w = self.file.writerStreaming(self.io, self.buffer);
        var i: usize = 0;
        while (i < n_writes) : (i += 1) {
            w.interface.writeAll(payload) catch {};
            self.sink +%= 1;
        }
        w.interface.flush() catch {};
    }
};

// ---------- zp-aos-single-field: AoS vs SoA sum one field ----------
const Elem = struct {
    hp: u32,
    kind: u8,
    _pad: [3]u8 = .{ 0, 0, 0 },
    pos_x: f32,
    pos_y: f32,
    cold_a: u64,
    cold_b: u64,
};
const Zp013 = struct {
    const n: usize = 1_000_000;
    const passes: u64 = 4;
    aos: []const Elem,
    hps: []const u32,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp013 = @ptrCast(@alignCast(ptr));
        var p: u64 = 0;
        while (p < passes) : (p += 1) {
            var sum: u64 = 0;
            for (self.aos) |e| sum +%= e.hp;
            self.sink +%= sum;
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp013 = @ptrCast(@alignCast(ptr));
        var p: u64 = 0;
        while (p < passes) : (p += 1) {
            var sum: u64 = 0;
            for (self.hps) |hp| sum +%= hp;
            self.sink +%= sum;
        }
    }
};

// ---------- zp-bool-array: []bool vs bit_set.Static ----------
const Zp017 = struct {
    const n: usize = 1 << 16;
    const passes: u64 = 8;
    bools: []bool,
    bits: *std.bit_set.Static(n),
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp017 = @ptrCast(@alignCast(ptr));
        var p: u64 = 0;
        while (p < passes) : (p += 1) {
            var c: u64 = 0;
            for (self.bools) |b| c +%= @intFromBool(b);
            self.sink +%= c;
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp017 = @ptrCast(@alignCast(ptr));
        var p: u64 = 0;
        while (p < passes) : (p += 1) {
            self.sink +%= self.bits.count();
        }
    }
};

// ---------- zp-static-string-map: StringHashMap vs StaticStringMap lookup ----------
const Zp018 = struct {
    const ops: u64 = 200_000;
    const keys = [_][]const u8{ "fn", "const", "var", "pub", "try", "catch", "defer", "errdefer", "struct", "enum", "union", "opaque" };
    map: *std.StringHashMap(u8),
    static_map: *const std.StaticStringMap(u8),
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp018 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            const k = keys[i % keys.len];
            self.sink +%= self.map.get(k) orelse 0;
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp018 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            const k = keys[i % keys.len];
            self.sink +%= self.static_map.get(k) orelse 0;
        }
    }
};

// ---------- zp-runtime-div-hot: runtime div vs mask ----------
const Zp019 = struct {
    const n: usize = 2_000_000;
    mod: u64 = 1024, // power of two
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp019 = @ptrCast(@alignCast(ptr));
        // Keep mod "runtime" by reading from self each iteration.
        var i: u64 = 0;
        var s: u64 = 0;
        while (i < n) : (i += 1) {
            s +%= i % self.mod;
        }
        self.sink +%= s;
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp019 = @ptrCast(@alignCast(ptr));
        const mask = self.mod - 1;
        var i: u64 = 0;
        var s: u64 = 0;
        while (i < n) : (i += 1) {
            s +%= i & mask;
        }
        self.sink +%= s;
    }
};

// ---------- zp-queue-ordered-remove: orderedRemove(0) vs swapRemove / ring ----------
const Zp020 = struct {
    const n: usize = 4_000;
    gpa: std.mem.Allocator,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp020 = @ptrCast(@alignCast(ptr));
        var list: std.ArrayList(u32) = .empty;
        defer list.deinit(self.gpa);
        list.ensureTotalCapacity(self.gpa, n) catch unreachable;
        var i: u32 = 0;
        while (i < n) : (i += 1) list.appendAssumeCapacity(i);
        while (list.items.len > 0) {
            self.sink +%= list.orderedRemove(0);
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp020 = @ptrCast(@alignCast(ptr));
        // Ring-style: head index, no shift.
        var buf: [n]u32 = undefined;
        var i: u32 = 0;
        while (i < n) : (i += 1) buf[i] = i;
        var head: usize = 0;
        var len: usize = n;
        while (len > 0) {
            self.sink +%= buf[head];
            head += 1;
            len -= 1;
        }
    }
};

// ---------- zp-shift-on-read: copyForwards consume vs cursor ----------
const Zp021 = struct {
    const cap: usize = 4096;
    const consume: usize = 64;
    const rounds: usize = 20_000;
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp021 = @ptrCast(@alignCast(ptr));
        var buf: [cap]u8 = undefined;
        @memset(&buf, 1);
        var len: usize = cap;
        var r: usize = 0;
        while (r < rounds) : (r += 1) {
            if (len < consume) {
                @memset(buf[len..], 1);
                len = cap;
            }
            self.sink +%= buf[0];
            std.mem.copyForwards(u8, buf[0 .. len - consume], buf[consume..len]);
            len -= consume;
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp021 = @ptrCast(@alignCast(ptr));
        var buf: [cap]u8 = undefined;
        @memset(&buf, 1);
        var head: usize = 0;
        var len: usize = cap;
        var r: usize = 0;
        while (r < rounds) : (r += 1) {
            if (len < consume) {
                head = 0;
                len = cap;
                @memset(&buf, 1);
            }
            self.sink +%= buf[head];
            head += consume;
            len -= consume;
        }
    }
};

// ---------- zp-invariant-float-div: float div vs reciprocal ----------
const Zp023 = struct {
    const n: usize = 2_000_000;
    denom: f64 = 3.141592653589793,
    sink: f64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp023 = @ptrCast(@alignCast(ptr));
        var i: usize = 0;
        var s: f64 = 0;
        while (i < n) : (i += 1) {
            s += @as(f64, @floatFromInt(i)) / self.denom;
        }
        self.sink += s;
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp023 = @ptrCast(@alignCast(ptr));
        const inv = 1.0 / self.denom;
        var i: usize = 0;
        var s: f64 = 0;
        while (i < n) : (i += 1) {
            s += @as(f64, @floatFromInt(i)) * inv;
        }
        self.sink += s;
    }
};

// ---------- zp-map-put-without-ensure: HashMap put without ensure vs with ----------
const Zp024 = struct {
    const n: u32 = 20_000;
    gpa: std.mem.Allocator,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp024 = @ptrCast(@alignCast(ptr));
        var map = std.AutoHashMap(u32, u32).init(self.gpa);
        defer map.deinit();
        var i: u32 = 0;
        while (i < n) : (i += 1) {
            map.put(i, i *% 3) catch unreachable;
        }
        self.sink +%= map.count();
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp024 = @ptrCast(@alignCast(ptr));
        var map = std.AutoHashMap(u32, u32).init(self.gpa);
        defer map.deinit();
        map.ensureTotalCapacity(n) catch unreachable;
        var i: u32 = 0;
        while (i < n) : (i += 1) {
            map.put(i, i *% 3) catch unreachable;
        }
        self.sink +%= map.count();
    }
};

// ---------- zp-arena-reset-free-all: arena free_all vs retain_capacity ----------
const Zp026 = struct {
    const ops: u64 = 50_000;
    const block: usize = 128;
    arena_free: *std.heap.ArenaAllocator,
    arena_retain: *std.heap.ArenaAllocator,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp026 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            defer _ = self.arena_free.reset(.free_all);
            const a = self.arena_free.allocator();
            const buf = a.alloc(u8, block) catch unreachable;
            buf[0] = @truncate(i);
            self.sink +%= buf[0];
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp026 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            defer _ = self.arena_retain.reset(.retain_capacity);
            const a = self.arena_retain.allocator();
            const buf = a.alloc(u8, block) catch unreachable;
            buf[0] = @truncate(i);
            self.sink +%= buf[0];
        }
    }
};

// ---------- zp-create-destroy-hot: create/destroy vs MemoryPool ----------
const Node = struct { x: i32 };
const Zp027 = struct {
    const ops: u64 = 200_000;
    gpa: std.mem.Allocator,
    pool: *std.heap.MemoryPool(Node),
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp027 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            const node = self.gpa.create(Node) catch unreachable;
            node.* = .{ .x = @intCast(i) };
            self.sink +%= @as(u64, @intCast(node.x));
            self.gpa.destroy(node);
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp027 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            const node = self.pool.create(self.gpa) catch unreachable;
            node.* = .{ .x = @intCast(i) };
            self.sink +%= @as(u64, @intCast(node.x));
            self.pool.destroy(node);
        }
    }
};

// ---------- zp-fixed-size-alloc-hot: fixed-size alloc in loop vs buffer pool ----------
const Zp028 = struct {
    const ops: u64 = 100_000;
    const block: usize = 256;
    gpa: std.mem.Allocator,
    pool_bufs: [][]u8,
    available: usize,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp028 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            const buf = self.gpa.alloc(u8, block) catch unreachable;
            buf[0] = @truncate(i);
            self.sink +%= buf[0];
            self.gpa.free(buf);
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp028 = @ptrCast(@alignCast(ptr));
        var i: u64 = 0;
        while (i < ops) : (i += 1) {
            if (self.available == 0) unreachable;
            self.available -= 1;
            const buf = self.pool_bufs[self.available];
            buf[0] = @truncate(i);
            self.sink +%= buf[0];
            self.pool_bufs[self.available] = buf;
            self.available += 1;
        }
    }
};

// ---------- zp-extern-struct-padding / zp-packable-bools / zp-usize-index-field / zp-optional-scalar-field: layout density walks ----------
const Zp009 = struct {
    const n: usize = 500_000;
    const passes: u64 = 4;
    // Bad: u8, u64, u8, u64 → lots of padding in extern
    const Bad = extern struct { a: u8, b: u64, c: u8, d: u64 };
    const Good = extern struct { b: u64, d: u64, a: u8, c: u8 };
    bad: []const Bad,
    good: []const Good,
    sink: u64 = 0,

    fn before(ptr: *anyopaque) void {
        const self: *Zp009 = @ptrCast(@alignCast(ptr));
        var p: u64 = 0;
        while (p < passes) : (p += 1) {
            var s: u64 = 0;
            for (self.bad) |e| s +%= e.b +% e.d;
            self.sink +%= s;
        }
    }
    fn after(ptr: *anyopaque) void {
        const self: *Zp009 = @ptrCast(@alignCast(ptr));
        var p: u64 = 0;
        while (p < passes) : (p += 1) {
            var s: u64 = 0;
            for (self.good) |e| s +%= e.b +% e.d;
            self.sink +%= s;
        }
    }
};

fn pairAndEmit(
    io: std.Io,
    rule: []const u8,
    before_case: []const u8,
    after_case: []const u8,
    before_ns: i128,
    after_ns: i128,
    ops: u64,
    ts: []const u8,
) !void {
    const ratio = if (after_ns > 0)
        @as(f64, @floatFromInt(before_ns)) / @as(f64, @floatFromInt(after_ns))
    else
        0.0;
    try emit(io, rule, before_case, "before", before_ns, ops, ratio, ts);
    try emit(io, rule, after_case, "after", after_ns, ops, 1.0, ts);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    // Use a fixed label; regen script stamps real UTC.
    const ts_fixed = "2026-10-21T11:30:00Z";

    // zp-alloc-hot
    {
        var arena_state: std.heap.ArenaAllocator = .init(gpa);
        defer arena_state.deinit();
        var ctx: Zp001 = .{ .gpa = gpa, .arena = &arena_state };
        const b = timeWork(io, Zp001.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp001.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-alloc-hot", "gpa_alloc_free_in_loop", "arena_retain_in_loop", b, a, Zp001.ops, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-append-without-reserve
    {
        var ctx: Zp002 = .{ .gpa = gpa };
        const b = timeWork(io, Zp002.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp002.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-append-without-reserve", "append_no_reserve", "ensure_then_assume", b, a, Zp002.n, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-page-allocator-small
    {
        const page = std.heap.page_allocator;
        const fast = gpa; // process Init GPA is smp/c in ReleaseFast
        var ctx: Zp003 = .{ .page = page, .fast = fast };
        const b = timeWork(io, Zp003.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp003.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-page-allocator-small", "page_allocator_64B", "process_gpa_64B", b, a, Zp003.ops, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-large-struct-by-value
    {
        var ctx: Zp005 = .{};
        const b = timeWork(io, Zp005.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp005.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-large-struct-by-value", "large_struct_by_value", "large_struct_by_ptr", b, a, Zp005.ops, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-print-hot (noisy; small N)
    {
        var ctx: Zp006 = .{};
        const b = timeWork(io, Zp006.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp006.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-print-hot", "debug_print_in_loop", "quiet_counter", b, a, Zp006.ops, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-unbuffered-io
    {
        const file = try std.Io.Dir.openFileAbsolute(io, "/dev/null", .{ .mode = .write_only });
        defer file.close(io);
        var empty_buf: [0]u8 = .{};
        var kib4: [4096]u8 = undefined;
        var ctx_e: Zp007 = .{ .io = io, .file = file, .buffer = &empty_buf };
        var ctx_b: Zp007 = .{ .io = io, .file = file, .buffer = kib4[0..] };
        const b = timeWork(io, Zp007.run, @ptrCast(&ctx_e));
        const a = timeWork(io, Zp007.run, @ptrCast(&ctx_b));
        try pairAndEmit(io, "zp-unbuffered-io", "writer_empty_buf", "writer_4kib_buf", b, a, Zp007.n_writes, ts_fixed);
        std.mem.doNotOptimizeAway(ctx_e.sink);
        std.mem.doNotOptimizeAway(ctx_b.sink);
    }

    // zp-extern-struct-padding
    {
        const bad = try gpa.alloc(Zp009.Bad, Zp009.n);
        defer gpa.free(bad);
        const good = try gpa.alloc(Zp009.Good, Zp009.n);
        defer gpa.free(good);
        var i: usize = 0;
        while (i < Zp009.n) : (i += 1) {
            bad[i] = .{ .a = 1, .b = i, .c = 2, .d = i *% 3 };
            good[i] = .{ .b = i, .d = i *% 3, .a = 1, .c = 2 };
        }
        var ctx: Zp009 = .{ .bad = bad, .good = good };
        const b = timeWork(io, Zp009.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp009.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-extern-struct-padding", "extern_padded_walk", "extern_packed_walk", b, a, Zp009.n * Zp009.passes, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-aos-single-field
    {
        const aos = try gpa.alloc(Elem, Zp013.n);
        defer gpa.free(aos);
        const hps = try gpa.alloc(u32, Zp013.n);
        defer gpa.free(hps);
        var i: usize = 0;
        while (i < Zp013.n) : (i += 1) {
            aos[i] = .{
                .hp = @truncate(i *% 17 +% 1),
                .kind = @truncate(i),
                .pos_x = @floatFromInt(i),
                .pos_y = @floatFromInt(i *% 3),
                .cold_a = i,
                .cold_b = ~i,
            };
            hps[i] = aos[i].hp;
        }
        var ctx: Zp013 = .{ .aos = aos, .hps = hps };
        const b = timeWork(io, Zp013.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp013.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-aos-single-field", "aos_sum_hp", "soa_sum_hp", b, a, Zp013.n * Zp013.passes, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-bool-array
    {
        const bools = try gpa.alloc(bool, Zp017.n);
        defer gpa.free(bools);
        var bits: std.bit_set.Static(Zp017.n) = .empty;
        var i: usize = 0;
        while (i < Zp017.n) : (i += 1) {
            const on = (i % 3) == 0;
            bools[i] = on;
            if (on) bits.set(i);
        }
        var ctx: Zp017 = .{ .bools = bools, .bits = &bits };
        const b = timeWork(io, Zp017.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp017.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-bool-array", "bool_array_count", "bitset_count", b, a, Zp017.n * Zp017.passes, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-static-string-map
    {
        var map = std.StringHashMap(u8).init(gpa);
        defer map.deinit();
        const static_map = std.StaticStringMap(u8).initComptime(.{
            .{ "fn", 1 },
            .{ "const", 2 },
            .{ "var", 3 },
            .{ "pub", 4 },
            .{ "try", 5 },
            .{ "catch", 6 },
            .{ "defer", 7 },
            .{ "errdefer", 8 },
            .{ "struct", 9 },
            .{ "enum", 10 },
            .{ "union", 11 },
            .{ "opaque", 12 },
        });
        for (Zp018.keys, 0..) |k, idx| {
            try map.put(k, @intCast(idx + 1));
        }
        var ctx: Zp018 = .{ .map = &map, .static_map = &static_map };
        const b = timeWork(io, Zp018.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp018.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-static-string-map", "string_hashmap_get", "static_string_map_get", b, a, Zp018.ops, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-runtime-div-hot
    {
        var ctx: Zp019 = .{};
        const b = timeWork(io, Zp019.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp019.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-runtime-div-hot", "runtime_mod", "bitmask", b, a, Zp019.n, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-queue-ordered-remove
    {
        var ctx: Zp020 = .{ .gpa = gpa };
        const b = timeWork(io, Zp020.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp020.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-queue-ordered-remove", "ordered_remove_0", "ring_head_advance", b, a, Zp020.n, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-shift-on-read
    {
        var ctx: Zp021 = .{};
        const b = timeWork(io, Zp021.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp021.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-shift-on-read", "copy_forwards_consume", "cursor_head", b, a, Zp021.rounds, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-invariant-float-div
    {
        var ctx: Zp023 = .{};
        const b = timeWork(io, Zp023.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp023.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-invariant-float-div", "float_div_loop", "mul_reciprocal", b, a, Zp023.n, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-map-put-without-ensure
    {
        var ctx: Zp024 = .{ .gpa = gpa };
        const b = timeWork(io, Zp024.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp024.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-map-put-without-ensure", "map_put_grow", "map_ensure_then_put", b, a, Zp024.n, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-arena-reset-free-all
    {
        var arena_free: std.heap.ArenaAllocator = .init(gpa);
        defer arena_free.deinit();
        var arena_retain: std.heap.ArenaAllocator = .init(gpa);
        defer arena_retain.deinit();
        var ctx: Zp026 = .{ .arena_free = &arena_free, .arena_retain = &arena_retain };
        const b = timeWork(io, Zp026.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp026.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-arena-reset-free-all", "arena_reset_free_all", "arena_reset_retain", b, a, Zp026.ops, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-create-destroy-hot
    {
        var pool: std.heap.MemoryPool(Node) = try .initCapacity(gpa, 64);
        defer pool.deinit(gpa);
        var ctx: Zp027 = .{ .gpa = gpa, .pool = &pool };
        const b = timeWork(io, Zp027.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp027.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-create-destroy-hot", "create_destroy_loop", "memory_pool", b, a, Zp027.ops, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // zp-fixed-size-alloc-hot
    {
        const pool_count: usize = 64;
        const pool_bufs = try gpa.alloc([]u8, pool_count);
        defer {
            for (pool_bufs) |b| gpa.free(b);
            gpa.free(pool_bufs);
        }
        for (pool_bufs) |*slot| slot.* = try gpa.alloc(u8, Zp028.block);
        var ctx: Zp028 = .{ .gpa = gpa, .pool_bufs = pool_bufs, .available = pool_count };
        const b = timeWork(io, Zp028.before, @ptrCast(&ctx));
        const a = timeWork(io, Zp028.after, @ptrCast(&ctx));
        try pairAndEmit(io, "zp-fixed-size-alloc-hot", "fixed_alloc_free_loop", "buffer_pool_hit", b, a, Zp028.ops, ts_fixed);
        std.mem.doNotOptimizeAway(ctx.sink);
    }
}
