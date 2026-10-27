// See the English guide for context.
const std = @import("std");
const lint = @import("src/lint.zig");
const rules = @import("src/rules.zig");

fn countRule(source: [:0]const u8, id: rules.Id, total: *usize) !usize {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false };
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    total.* = res.findings.len;
    var n: usize = 0;
    for (res.findings) |f| n += @intFromBool(f.rule == id);
    return n;
}

test "每条规则：bad 触发、good 不触发" {
    inline for (rules.all) |r| {
        const bad = @embedFile("fixtures/bad/" ++ r.code ++ ".zig");
        const good = @embedFile("fixtures/good/" ++ r.code ++ ".zig");
        var total: usize = 0;
        const hits = try countRule(bad, r.id, &total);
        if (hits == 0) {
            // zperf-lint: ignore print-in-loop
            std.debug.print("规则 {s} 未在 bad 夹具上触发\n", .{r.code});
            return error.RuleDidNotFire;
        }
        const fp = try countRule(good, r.id, &total);
        if (fp != 0 or total != 0) {
            // zperf-lint: ignore print-in-loop
            std.debug.print("good/{s}.zig 上出现了 {d} 处 {s}（共 {d} 处发现）\n", .{ r.code, fp, r.code, total });
            return error.FalsePositive;
        }
    }
}

test "行内 / 文件级 ignore 注释" {
    var total: usize = 0;
    _ = try countRule(@embedFile("fixtures/ignore.zig"), .print_in_loop, &total);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "--enable 只开指定规则" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var cfg: lint.Config = .{ .enabled = .empty };
    cfg.enabled.insert(.bool_array);
    const res = try lint.lintSource(arena.allocator(), @embedFile("fixtures/bad/zp-alloc-hot.zig"), &cfg);
    try std.testing.expectEqual(@as(usize, 0), res.findings.len);
}

test "语法错误被报告而不是崩溃" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{};
    const res = try lint.lintSource(arena.allocator(), "pub fn (", &cfg);
    try std.testing.expect(res.parse_error != null);
}

test "Zig 0.16 兼容解析：`**` 被归一化，列号不变" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{};
    const res = try lint.lintSource(arena.allocator(), @embedFile("fixtures/compat016.zig"), &cfg);
    try std.testing.expect(res.parse_error == null);
    try std.testing.expect(res.compat);
}

test "热标注 + 本文件调用传播（原因链）" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false }; // zp-per-packet-alloc default off after G3
    const res = try lint.lintSource(arena.allocator(), @embedFile("fixtures/hot_prop.zig"), &cfg);
    var hit: ?lint.Finding = null;
    for (res.findings) |f| if (f.rule == .per_packet_alloc) {
        hit = f;
    };
    try std.testing.expect(hit != null);
    try std.testing.expect(std.mem.find(u8, hit.?.detail, "pump(标注 hot) → stash") != null);
    cfg.propagate = false;
    const res2 = try lint.lintSource(arena.allocator(), @embedFile("fixtures/hot_prop.zig"), &cfg);
    for (res2.findings) |f| try std.testing.expect(f.rule != .per_packet_alloc);
}

test "zp-per-packet-alloc 不把通用 handle 当热路径，具体 handle 前缀仍生效" {
    const source =
        \\const std = @import("std");
        \\fn handle(allocator: std.mem.Allocator) void {
        \\    _ = allocator.create(u8) catch return;
        \\}
        \\fn handleRequest(allocator: std.mem.Allocator) void {
        \\    _ = allocator.create(u8) catch return;
        \\}
        \\fn enqueue(allocator: std.mem.Allocator) void {
        \\    _ = allocator.create(u8) catch return;
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false }; // zp-per-packet-alloc default off after G3
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    var hits: usize = 0;
    for (res.findings) |f| {
        if (f.rule != .per_packet_alloc) continue;
        hits += 1;
        try std.testing.expect(std.mem.find(u8, f.detail, "handleRequest") != null or
            std.mem.find(u8, f.detail, "enqueue") != null);
    }
    try std.testing.expectEqual(@as(usize, 2), hits);

    cfg = .{ .include_off_rules = true, .scope_all = false, .hot_fns = &.{"handle"} };
    const explicitly_hot = try lint.lintSource(arena.allocator(), source, &cfg);
    var handle_hit = false;
    for (explicitly_hot.findings) |f| {
        if (f.rule == .per_packet_alloc and std.mem.find(u8, f.detail, "热: handle]") != null)
            handle_hit = true;
    }
    try std.testing.expect(handle_hit);
}

test "zp-queue-ordered-remove 修复建议要求结合队列上界判断" {
    try std.testing.expect(std.mem.find(u8, rules.get(.queue_ordered_remove).fix, "上界") != null);
    try std.testing.expect(std.mem.find(u8, rules.get(.queue_ordered_remove).fix, "稳定压缩") != null);
    try std.testing.expect(std.mem.find(u8, rules.get(.queue_ordered_remove).fix, "顺序无关") != null);
}

test "zp-shift-on-read 修复建议覆盖按阈值摊销的读游标" {
    const fix = rules.get(.shift_on_read).fix;
    try std.testing.expect(std.mem.find(u8, fix, "读游标") != null);
    try std.testing.expect(std.mem.find(u8, fix, "至少一半") != null);
    try std.testing.expect(std.mem.find(u8, fix, "摊销") != null);
}

test "zp-append-without-reserve 检测循环条件分支中的 append" {
    const source =
        \\const std = @import("std");
        \\fn collect(gpa: std.mem.Allocator, xs: []const u32) !std.ArrayList(u32) {
        \\    var out: std.ArrayList(u32) = .empty;
        \\    errdefer out.deinit(gpa);
        \\    for (xs) |x| {
        \\        if (x != 0) try out.append(gpa, x);
        \\    }
        \\    return out;
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false };
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    for (res.findings) |f| if (f.rule == .append_without_reserve) return;
    return error.ExpectedAppendWithoutReserve;
}

test "zp-append-without-reserve 检测 while 循环中的 append" {
    const source =
        \\const std = @import("std");
        \\fn collect(gpa: std.mem.Allocator, n: usize) !std.ArrayList(u8) {
        \\    var out: std.ArrayList(u8) = .empty;
        \\    errdefer out.deinit(gpa);
        \\    var i: usize = 0;
        \\    while (i < n) : (i += 1) {
        \\        try out.append(gpa, @intCast(i));
        \\    }
        \\    return out;
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false };
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    for (res.findings) |f| if (f.rule == .append_without_reserve) return;
    return error.ExpectedAppendWithoutReserve;
}

test "zp-per-packet-alloc 把 callconv(c) 函数视为热路径入口" {
    const source =
        \\const std = @import("std");
        \\fn callback(allocator: std.mem.Allocator) callconv(.c) void {
        \\    helper(allocator);
        \\}
        \\fn helper(allocator: std.mem.Allocator) void {
        \\    _ = allocator.dupeSentinel(u8, "value", 0) catch return;
        \\}
        \\fn ordinary(allocator: std.mem.Allocator) void {
        \\    _ = allocator.create(u8) catch return;
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false };
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    var callback_hit = false;
    var ordinary_hit = false;
    for (res.findings) |f| {
        if (f.rule != .per_packet_alloc) continue;
        if (std.mem.find(u8, f.detail, "callback(callconv(.c)) → helper") != null) callback_hit = true;
        if (std.mem.find(u8, f.detail, "ordinary") != null) ordinary_hit = true;
    }
    try std.testing.expect(callback_hit);
    try std.testing.expect(!ordinary_hit);
}


test "zp-print-hot 默认不报 log.*，--strict-log-in-loop 才报" {
    const source =
        \\const std = @import("std");
        \\const log = std.log.scoped(.t);
        \\fn loopLog(xs: []const u32) void {
        \\    for (xs) |x| log.debug("{d}", .{x});
        \\}
        \\fn loopPrint(xs: []const u32) void {
        \\    for (xs) |x| std.debug.print("{d}\n", .{x});
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false }; // zp-print-hot default off after G3
    const def = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(def.parse_error == null);
    var log_hits: usize = 0;
    var print_hits: usize = 0;
    for (def.findings) |f| {
        if (f.rule != .print_in_loop) continue;
        if (std.mem.find(u8, f.detail, "debug.print") != null) print_hits += 1 else log_hits += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), print_hits);
    try std.testing.expectEqual(@as(usize, 0), log_hits);

    cfg.strict_log_in_loop = true;
    const strict = try lint.lintSource(arena.allocator(), source, &cfg);
    var strict_total: usize = 0;
    for (strict.findings) |f| strict_total += @intFromBool(f.rule == .print_in_loop);
    try std.testing.expectEqual(@as(usize, 2), strict_total);
}

test "zp-unbuffered-io 跳过 allocRemaining 与一次性 writeAll" {
    var total: usize = 0;
    const n = try countRule(@embedFile("fixtures/good/zp-unbuffered-io.zig"), .unbuffered_io, &total);
    try std.testing.expectEqual(@as(usize, 0), n);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "zp-unbuffered-io 仍报告循环内空缓冲 writeAll" {
    var total: usize = 0;
    const n = try countRule(@embedFile("fixtures/bad/zp-unbuffered-io.zig"), .unbuffered_io, &total);
    try std.testing.expect(n >= 1);
}


test "zp-unbuffered-io 跳过 test 块内一次性 writeAll" {
    const source =
        \\const std = @import("std");
        \\test "oneshot" {
        \\    const io: std.Io = undefined;
        \\    const file: std.Io.File = undefined;
        \\    var w = file.writer(io, &.{});
        \\    try w.interface.writeAll("hi");
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false };
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    for (res.findings) |f| if (f.rule == .unbuffered_io) return error.UnexpectedUnbufferedIo;
}

test "zp-runtime-div-hot 跳过 capacity 与 std.time 常量除数" {
    var total: usize = 0;
    const n = try countRule(@embedFile("fixtures/good/zp-runtime-div-hot.zig"), .runtime_div_in_loop, &total);
    try std.testing.expectEqual(@as(usize, 0), n);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "zp-optional-scalar-field 跳过 Options/Config，仍报告稠密 Item" {
    var total: usize = 0;
    const good = try countRule(@embedFile("fixtures/good/zp-optional-scalar-field.zig"), .optional_scalar_field, &total);
    try std.testing.expectEqual(@as(usize, 0), good);
    try std.testing.expectEqual(@as(usize, 0), total);
    const bad_n = try countRule(@embedFile("fixtures/bad/zp-optional-scalar-field.zig"), .optional_scalar_field, &total);
    try std.testing.expect(bad_n >= 2);
}

test "zp-missing-free 识别 release 与 ArenaAllocator+alloc" {
    var total: usize = 0;
    const n = try countRule(@embedFile("fixtures/good/zp-missing-free.zig"), .missing_free, &total);
    try std.testing.expectEqual(@as(usize, 0), n);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "tip Zig errdefer payload normalize" {
    const source =
        \\pub fn init() !void {
        \\    errdefer |err| switch (err) {
        \\        error.Foo => {},
        \\        else => {},
        \\    };
        \\    _ = 1;
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false };
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    try std.testing.expect(res.compat);
}


test "zp-append-without-reserve 跳过 arena alloc 参数" {
    var total: usize = 0;
    const n = try countRule(@embedFile("fixtures/good/zp-append-without-reserve.zig"), .append_without_reserve, &total);
    try std.testing.expectEqual(@as(usize, 0), n);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "zp-map-put-without-ensure map put without ensure" {
    var total: usize = 0;
    const bad = try countRule(@embedFile("fixtures/bad/zp-map-put-without-ensure.zig"), .map_put_without_ensure, &total);
    try std.testing.expect(bad >= 1);
    const good = try countRule(@embedFile("fixtures/good/zp-map-put-without-ensure.zig"), .map_put_without_ensure, &total);
    try std.testing.expectEqual(@as(usize, 0), good);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "zp-catch-unreachable-io catch unreachable io" {
    var total: usize = 0;
    const bad = try countRule(@embedFile("fixtures/bad/zp-catch-unreachable-io.zig"), .catch_unreachable_io, &total);
    try std.testing.expect(bad >= 1);
    const good = try countRule(@embedFile("fixtures/good/zp-catch-unreachable-io.zig"), .catch_unreachable_io, &total);
    try std.testing.expectEqual(@as(usize, 0), good);
}

test "zp-unbuffered-io caller-buffer 与同行 buffer 注释豁免" {
    var total: usize = 0;
    const n = try countRule(@embedFile("fixtures/good/zp-unbuffered-io.zig"), .unbuffered_io, &total);
    try std.testing.expectEqual(@as(usize, 0), n);
    try std.testing.expectEqual(@as(usize, 0), total);
}


test "zp-arena-reset-free-all arena reset free_all — cost adds up even off a hot path" {
    var total: usize = 0;
    const bad = try countRule(@embedFile("fixtures/bad/zp-arena-reset-free-all.zig"), .arena_reset_free_all, &total);
    try std.testing.expect(bad >= 1);
    const good = try countRule(@embedFile("fixtures/good/zp-arena-reset-free-all.zig"), .arena_reset_free_all, &total);
    try std.testing.expectEqual(@as(usize, 0), good);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "zp-create-destroy-hot create destroy — cost adds up even off a hot path" {
    var total: usize = 0;
    const bad = try countRule(@embedFile("fixtures/bad/zp-create-destroy-hot.zig"), .create_destroy_in_loop, &total);
    try std.testing.expect(bad >= 1);
    const good = try countRule(@embedFile("fixtures/good/zp-create-destroy-hot.zig"), .create_destroy_in_loop, &total);
    try std.testing.expectEqual(@as(usize, 0), good);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "zp-fixed-size-alloc-hot fixed size alloc — cost adds up even off a hot path" {
    var total: usize = 0;
    const bad = try countRule(@embedFile("fixtures/bad/zp-fixed-size-alloc-hot.zig"), .fixed_size_alloc_in_loop, &total);
    try std.testing.expect(bad >= 1);
    const good = try countRule(@embedFile("fixtures/good/zp-fixed-size-alloc-hot.zig"), .fixed_size_alloc_in_loop, &total);
    try std.testing.expectEqual(@as(usize, 0), good);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test {
    _ = lint;
}


test "zp-alloc-hot 跳过 method.dupe(sema.arena)" {
    var total: usize = 0;
    const n = try countRule(@embedFile("fixtures/good/zp-alloc-hot.zig"), .alloc_in_loop, &total);
    try std.testing.expectEqual(@as(usize, 0), n);
    try std.testing.expectEqual(@as(usize, 0), total);
}

test "zp-runtime-div-hot 跳过 crypto 路径" {
    const source =
        \\pub fn gcd(a0: u64, b0: u64) u64 {
        \\    var a = a0;
        \\    var b = b0;
        \\    while (b != 0) {
        \\        const q = a / b;
        \\        const t = a;
        \\        a = b;
        \\        b = t % b;
        \\        _ = q;
        \\    }
        \\    return a;
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var cfg: lint.Config = .{ .path = "lib/std/crypto/ml_kem.zig", .include_off_rules = true, .scope_all = false };
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    for (res.findings) |f| if (f.rule == .runtime_div_in_loop) return error.UnexpectedZp019;

    cfg.path = null;
    const res2 = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res2.parse_error == null);
    var n: usize = 0;
    for (res2.findings) |f| n += @intFromBool(f.rule == .runtime_div_in_loop);
    try std.testing.expect(n >= 1);
}

test "zp-runtime-div-hot 跳过 soft-div 函数名" {
    const source =
        \\pub fn udivmodei4(u: u64, v: u64) u64 {
        \\    var q: u64 = 0;
        \\    var i: u64 = 0;
        \\    while (i < 8) : (i += 1) {
        \\        q = u / v;
        \\    }
        \\    return q;
        \\}
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false };
    const res = try lint.lintSource(arena.allocator(), source, &cfg);
    try std.testing.expect(res.parse_error == null);
    for (res.findings) |f| if (f.rule == .runtime_div_in_loop) return error.UnexpectedZp019;
}

test "zp-alloc-print-hot 只报循环内不变的格式化" {
    const changing =
        \\const std = @import("std");
        \\fn each(gpa: std.mem.Allocator, n: u32) !void {
        \\    var i: u32 = 0;
        \\    while (i < n) : (i += 1) {
        \\        const text = try std.fmt.allocPrint(gpa, "{d}", .{i});
        \\        gpa.free(text);
        \\    }
        \\}
        \\fn payloads(gpa: std.mem.Allocator, xs: []const u32) !void {
        \\    for (xs) |x| {
        \\        const text = try gpa.print("{d}", .{x});
        \\        gpa.free(text);
        \\    }
        \\}
        \\fn fresh(gpa: std.mem.Allocator, n: usize) !void {
        \\    var i: usize = 0;
        \\    while (i < n) : (i += 1) {
        \\        const upper = try gpa.alloc(u8, 4);
        \\        const text = try gpa.print("{s}", .{upper});
        \\        gpa.free(upper);
        \\        gpa.free(text);
        \\    }
        \\}
    ;
    const invariant =
        \\const std = @import("std");
        \\fn keep(gpa: std.mem.Allocator, n: u32, id: u32) !void {
        \\    var i: u32 = 0;
        \\    while (i < n) : (i += 1) {
        \\        const text = try gpa.print("{d}", .{id});
        \\        gpa.free(text);
        \\    }
        \\}
        \\fn hello(gpa: std.mem.Allocator, n: u32) !void {
        \\    var i: u32 = 0;
        \\    while (i < n) : (i += 1) {
        \\        const text = try gpa.print("hello", .{});
        \\        gpa.free(text);
        \\    }
        \\}
        \\fn arenaKeep(arena: std.mem.Allocator, n: u32, id: u32) !void {
        \\    var i: u32 = 0;
        \\    while (i < n) : (i += 1) {
        \\        const text = try arena.print("{d}", .{id});
        \\        arena.free(text);
        \\    }
        \\}
    ;
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const cfg: lint.Config = .{ .include_off_rules = true, .scope_all = false };
    const quiet = try lint.lintSource(arena_state.allocator(), changing, &cfg);
    try std.testing.expect(quiet.parse_error == null);
    for (quiet.findings) |f| try std.testing.expect(f.rule != .alloc_print_in_loop);
    const hit = try lint.lintSource(arena_state.allocator(), invariant, &cfg);
    try std.testing.expect(hit.parse_error == null);
    var n: usize = 0;
    for (hit.findings) |f| n += @intFromBool(f.rule == .alloc_print_in_loop);
    try std.testing.expectEqual(@as(usize, 3), n);
}
