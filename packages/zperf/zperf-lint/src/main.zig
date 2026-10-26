// See the English guide for context.
// See the English guide for context.
const std = @import("std");
const Io = std.Io;
const lint = @import("lint.zig");
const rules = @import("rules.zig");

/// `--hot-fn-preset=server`: common accept/request/serve entry names (prefix wildcards).
const server_hot_preset = [_][]const u8{
    "accept", "accept*",
    "handleRequest", "handleRequest*", "handleConn", "handleConn*", "handleConnection", "handleConnection*",
    "onRequest", "onRequest*", "processRequest", "processRequest*",
    "serve", "serve*", "serveConn", "serveConn*",
    "readLoop", "readLoop*", "writeLoop", "writeLoop*",
    "workerLoop", "workerLoop*", "keepalive", "keepAlive*",
    "onPacket", "onPacket*", "recvPacket", "recvPacket*",
};


const usage =
    \\用法: zperf-lint [选项] <文件或目录>...
    \\
    \\选项:
    \\  -f, --format <text|json>    输出格式（默认 text）
    \\  --enable <规则,...>         只启用这些规则（zp-alloc-in-loop 或 alloc-in-loop 形式均可）
    \\  --disable <规则,...>        禁用这些规则
    \\  --large-struct-bytes <N>    zp-large-struct-by-value 的阈值（默认 64）
    \\  --hot-fn <名字,...>          zp-per-packet-alloc 额外的热函数名（以 * 结尾为前缀匹配，如 onPkt*）
    \\  --hot-fn-preset <name>      追加热函数名预设：server（accept/handleRequest/serve/…）
    \\  --no-hot-propagation        热度不沿本文件调用传播
    \\  --strict-log-in-loop        zp-print-in-loop 同时报告循环内的 std.log.* / log.*（默认只报 debug.print）
    \\  --include-tests             也检查 build.zig、tests/、*test*.zig、testing/、Build/、*benchmark*.zig、*fuzz*（默认跳过）
    \\  --include-scripts           也检查 scripts/ 下的文件（默认跳过）
    \\  --include-compiler-rt       也检查 compiler_rt / lib/compiler_rt（默认跳过）
    \\  -j, --jobs <N>              并行 worker 数（默认 CPU 核数；输出顺序与 -j 1 一致）
    \\  --profile                   在 stderr 打印读取/解析/规则/输出的累计耗时
    \\  --no-fail                   有发现或解析错误时也返回 0（仍打印 parse 错误；JSON 含 parse_errors）
    \\  --list-rules                列出全部规则
    \\  -h, --help                  显示帮助
    \\
    \\热标注:    // zperf-lint: hot             （，zp-per-packet-alloc ）
    \\行内忽略:  // zperf-lint: ignore zp-alloc-in-loop        （；=）
    \\文件忽略:  // zperf-lint: ignore-file zp-large-struct-by-value
    \\退出码:    0 无发现（或 --no-fail）/ 1 有发现 / 2 用法、I/O 或解析错误（--no-fail 时解析错误不强制 2）
    \\提示:      tip Zig 的 `errdefer |err|` 等语法若无法解析，会记入 parse_errors；其余文件照常检查
    \\
;

const Format = enum { text, json };

const FileFinding = struct {
    file: []const u8,
    f: lint.Finding,
};

const ParseError = struct {
    file: []const u8,
    message: []const u8,
};

/// Skip build scripts, test trees, std.Build graph, and benchmark harnesses by default
/// (see --include-tests). Also see isCompilerRtPath / --include-compiler-rt.
fn isTestOrBuildPath(path: []const u8) bool {
    const base = std.fs.path.basename(path);
    if (std.mem.eql(u8, base, "build.zig")) return true;
    // Common short testing-helper modules (http.zig's t.zig, etc.).
    if (std.mem.eql(u8, base, "t.zig")) return true;
    if (std.mem.find(u8, path, "/tests/") != null or std.mem.startsWith(u8, path, "tests/")) return true;
    if (std.mem.find(u8, path, "/testing/") != null or std.mem.startsWith(u8, path, "testing/")) return true;
    // Basename contains "test" (e.g. foo_test.zig, testing.zig) — not contest.zig-style false positives often.
    if (std.mem.endsWith(u8, base, ".zig") and std.mem.find(u8, base, "test") != null) return true;
    // std.Build graph (lib/std/Build.zig + Build/**) — not a runtime hot path.
    if (std.mem.eql(u8, base, "Build.zig")) return true;
    if (std.mem.find(u8, path, "/Build/") != null or std.mem.startsWith(u8, path, "Build/")) return true;
    // Benchmark harnesses (crypto/benchmark.zig, **/benchmarks/**).
    if (std.mem.find(u8, path, "/benchmarks/") != null or std.mem.startsWith(u8, path, "benchmarks/")) return true;
    if (std.mem.endsWith(u8, base, ".zig") and std.mem.find(u8, base, "benchmark") != null) return true;
    // Fuzz harnesses (tigerbeetle *_fuzz.zig, **/fuzz/**) — not production hot paths.
    if (std.mem.find(u8, path, "/fuzz/") != null or std.mem.startsWith(u8, path, "fuzz/")) return true;
    if (std.mem.endsWith(u8, base, ".zig") and std.mem.find(u8, base, "fuzz") != null) return true;
    return false;
}

/// Skip repo helper scripts by default (see --include-scripts).
fn isScriptsPath(path: []const u8) bool {
    if (std.mem.eql(u8, path, "scripts")) return true;
    if (std.mem.endsWith(u8, path, "/scripts")) return true;
    if (std.mem.find(u8, path, "/scripts/") != null or std.mem.startsWith(u8, path, "scripts/")) return true;
    return false;
}

/// Skip compiler_rt softfloat/helpers by default (see --include-compiler-rt).
fn isCompilerRtPath(path: []const u8) bool {
    const base = std.fs.path.basename(path);
    if (std.mem.eql(u8, base, "compiler_rt.zig")) return true;
    if (std.mem.eql(u8, path, "compiler_rt") or std.mem.eql(u8, path, "lib/compiler_rt")) return true;
    if (std.mem.endsWith(u8, path, "/compiler_rt")) return true;
    if (std.mem.find(u8, path, "/compiler_rt/") != null or std.mem.startsWith(u8, path, "compiler_rt/")) return true;
    if (std.mem.find(u8, path, "/lib/compiler_rt/") != null or std.mem.startsWith(u8, path, "lib/compiler_rt/")) return true;
    return false;
}

pub fn main(init: std.process.Init) !u8 {
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    var out_buf: [64 * 1024]u8 = undefined;
    var out_w = Io.File.stdout().writerStreaming(io, &out_buf);
    const out = &out_w.interface;
    var err_buf: [1024]u8 = undefined;
    var err_w = Io.File.stderr().writerStreaming(io, &err_buf);
    const err = &err_w.interface;
// See the English guide for context.
    defer out.flush() catch {};
    defer err.flush() catch {};

    var cfg: lint.Config = .{};
    var format: Format = .text;
    var fail = true;
    var include_tests = false;
    var include_scripts = false;
    var include_compiler_rt = false;
    var paths: std.ArrayList([]const u8) = .empty;
    var hot_fns: std.ArrayList([]const u8) = .empty;
    try paths.ensureTotalCapacity(arena, args.len);
    try hot_fns.ensureTotalCapacity(arena, args.len + server_hot_preset.len);
    var jobs: ?usize = null;
    var profile = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "-h") or std.mem.eql(u8, a, "--help")) {
            try out.writeAll(usage);
            return 0;
        } else if (std.mem.eql(u8, a, "--list-rules")) {
            try listRules(out);
            return 0;
        } else if (std.mem.eql(u8, a, "--no-fail")) {
            fail = false;
        } else if (std.mem.eql(u8, a, "--strict-log-in-loop")) {
            cfg.strict_log_in_loop = true;
        } else if (std.mem.eql(u8, a, "--include-tests")) {
            include_tests = true;
        } else if (std.mem.eql(u8, a, "--include-scripts")) {
            include_scripts = true;
        } else if (std.mem.eql(u8, a, "--include-compiler-rt")) {
            include_compiler_rt = true;
        } else if (optValue(args, &i, a, "--format", "-f")) |v| {
            format = std.meta.stringToEnum(Format, v) orelse return usageError(err, "未知格式", v);
        } else if (optValue(args, &i, a, "--enable", null)) |v| {
            cfg.enabled = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |r| cfg.enabled.insert(rules.parse(r) orelse return usageError(err, "未知规则", r));
        } else if (optValue(args, &i, a, "--disable", null)) |v| {
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |r| cfg.enabled.remove(rules.parse(r) orelse return usageError(err, "未知规则", r));
        } else if (optValue(args, &i, a, "--hot-fn", null)) |v| {
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |h| hot_fns.appendAssumeCapacity(h);
        } else if (optValue(args, &i, a, "--hot-fn-preset", null)) |v| {
            if (std.mem.eql(u8, v, "server")) {
                for (server_hot_preset) |h| try hot_fns.append(arena, h);
            } else return usageError(err, "未知热函数预设", v);
        } else if (optValue(args, &i, a, "--jobs", "-j")) |v| {
            jobs = std.fmt.parseInt(usize, v, 10) catch return usageError(err, "无效数字", v);
        } else if (std.mem.eql(u8, a, "--profile")) {
            profile = true;
        } else if (std.mem.eql(u8, a, "--no-hot-propagation")) {
            cfg.propagate = false;
        } else if (optValue(args, &i, a, "--large-struct-bytes", null)) |v| {
            cfg.large_struct_bytes = std.fmt.parseInt(u64, v, 10) catch return usageError(err, "无效数字", v);
        } else if (std.mem.startsWith(u8, a, "-")) {
            return usageError(err, "未知选项", a);
        } else {
            paths.appendAssumeCapacity(a);
        }
    }
    cfg.hot_fns = hot_fns.items;
    if (paths.items.len == 0) {
        try err.writeAll(usage);
        return 2;
    }

// See the English guide for context.
    var files: std.ArrayList([]const u8) = .empty;
    const cwd = Io.Dir.cwd();
    for (paths.items) |p| {
        const st = cwd.statFile(io, p, .{}) catch |e| {
            try err.print("zperf-lint: 无法访问 {s}: {t}\n", .{ p, e });
            return 2;
        };
        if (st.kind == .directory) {
            if (!include_scripts and isScriptsPath(p)) continue;
            if (!include_compiler_rt and isCompilerRtPath(p)) continue;
            var dir = try cwd.openDir(io, p, .{ .iterate = true });
            defer dir.close(io);
            var walker = try dir.walk(arena);
            defer walker.deinit();
            while (try walker.next(io)) |e| {
                if (e.kind != .file or !std.mem.endsWith(u8, e.path, ".zig")) continue;
                if (std.mem.find(u8, e.path, ".zig-cache") != null or std.mem.find(u8, e.path, "zig-out") != null) continue;
                if (!include_tests and isTestOrBuildPath(e.path)) continue;
                if (!include_compiler_rt and isCompilerRtPath(e.path)) continue;
                const full = try std.fs.path.join(arena, &.{ p, e.path });
                if (!include_scripts and isScriptsPath(full)) continue;
                if (!include_compiler_rt and isCompilerRtPath(full)) continue;
                if (!include_tests and isTestOrBuildPath(full)) continue;
                try files.append(arena, full); // zperf-lint: ignore zp-append-without-reserve -- directory entry count is unknown before walking
            }
        } else {
            if (!include_tests and isTestOrBuildPath(p)) {
                // Explicit path still skipped unless --include-tests (same policy as directory walk).
            } else if (!include_scripts and isScriptsPath(p)) {
                // Explicit path still skipped unless --include-scripts.
            } else if (!include_compiler_rt and isCompilerRtPath(p)) {
                // Explicit path still skipped unless --include-compiler-rt.
            } else {
                try files.append(arena, p); // zperf-lint: ignore zp-append-without-reserve -- the shared files list also receives an unknown number of directory entries
            }
        }
    }
    std.mem.sort([]const u8, files.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lt);

// See the English guide for context.
// See the English guide for context.
// See the English guide for context.
    const slots = try arena.alloc(Slot, files.items.len);
    @memset(slots, .{});
    const n_workers = @max(1, @min(jobs orelse (std.Thread.getCpuCount() catch 1), files.items.len));
    const workers = try arena.alloc(Worker, n_workers);
    var shared: Shared = .{ .io = io, .cfg = &cfg, .files = files.items, .slots = slots, .profile = profile };
    for (workers) |*w| w.* = .{
        .scratch = .init(std.heap.smp_allocator),
        .keep = .init(std.heap.smp_allocator),
        .prof = .{ .io = io },
    };
// See the English guide for context.
    if (n_workers == 1) {
        work(&shared, &workers[0]);
    } else {
        var group: Io.Group = .init;
// See the English guide for context.
        // zwanzig-disable-next-line swallowed-error
        for (workers) |*w| group.concurrent(io, work, .{ &shared, w }) catch work(&shared, w);
        try group.await(io);
    }
    for (workers) |*w| if (w.err) |e| return e;

    var all: std.ArrayList(FileFinding) = .empty;
    var parse_errors: std.ArrayList(ParseError) = .empty;
    var total: usize = 0;
    for (slots) |sl| total += sl.findings.len;
    try all.ensureTotalCapacity(arena, total);
    var had_error = false;
    for (files.items, slots) |path, sl| {
        if (sl.read_err) |e| {
            try err.print("zperf-lint: 读取 {s} 失败: {t}\n", .{ path, e });
            had_error = true;
            continue;
        }
        if (sl.parse_err) |pe| {
            try err.print("{s}:{s}\n", .{ path, pe });
            try parse_errors.append(arena, .{ .file = path, .message = pe });
            had_error = true;
            continue;
        }
        if (sl.compat) try err.print("zperf-lint: 注意 {s} 经兼容改写后解析（Zig 0.16 `**` 和/或 tip `errdefer |err|`）\n", .{path});
        for (sl.findings) |f| all.appendAssumeCapacity(.{ .file = path, .f = f });
    }
    const t_out: Io.Timestamp = .now(io, .awake);

    switch (format) {
        .text => try printText(out, all.items, files.items.len),
        .json => try printJson(out, all.items, files.items.len, parse_errors.items),
    }
    if (profile) {
        try out.flush();
        var read_ns: i96 = 0;
        var parse_ns: i96 = 0;
        var lint_ns: i96 = 0;
        for (workers) |w| {
            read_ns += w.read_ns;
            parse_ns += w.prof.parse_ns;
            lint_ns += w.prof.lint_ns;
        }
        const ms = struct {
            fn f(ns: i96) f64 {
                return @as(f64, @floatFromInt(ns)) / 1e6;
            }
        }.f;
        try err.print("zperf-lint profile: {d} 个文件, {d} 个 worker; 累计 读取 {d:.1} ms, 解析 {d:.1} ms, 规则 {d:.1} ms; 输出 {d:.1} ms\n", .{
            files.items.len, n_workers, ms(read_ns), ms(parse_ns), ms(lint_ns), ms(t_out.untilNow(io, .awake).nanoseconds),
        });
    }
    // With --no-fail, parse/read errors do not force exit 2 so corpus runs stay usable.
    if (had_error and fail) return 2;
    return if (fail and all.items.len > 0) 1 else 0;
}

const Slot = struct {
    findings: []const lint.Finding = &.{},
    compat: bool = false,
    parse_err: ?[]const u8 = null,
    read_err: ?anyerror = null,
};

const Shared = struct {
    io: Io,
    cfg: *const lint.Config,
    files: []const []const u8,
    slots: []Slot,
    profile: bool,
    next: std.atomic.Value(usize) = .init(0),
};

const Worker = struct {
    scratch: std.heap.ArenaAllocator,
    keep: std.heap.ArenaAllocator,
    prof: lint.Prof,
    read_ns: i96 = 0,
    err: ?anyerror = null,
};

fn work(sh: *Shared, w: *Worker) void {
// See the English guide for context.
    // zwanzig-disable-next-line swallowed-error
    workFiles(sh, w) catch |e| {
        w.err = e;
    };
}

fn workFiles(sh: *Shared, w: *Worker) !void {
    const cwd = Io.Dir.cwd();
    const result_arena = w.keep.allocator();
    while (true) {
        const idx = sh.next.fetchAdd(1, .monotonic);
        if (idx >= sh.files.len) return;
        const slot = &sh.slots[idx];
        _ = w.scratch.reset(.retain_capacity);
        const a = w.scratch.allocator();
        const t0: Io.Timestamp = if (sh.profile) .now(sh.io, .awake) else .{ .nanoseconds = 0 };
// See the English guide for context.
        // zwanzig-disable-next-line swallowed-error
        const source = cwd.readFileAllocOptions(sh.io, sh.files[idx], a, .limited(64 << 20), .of(u8), 0) catch |e| {
            slot.read_err = e;
            continue;
        };
        if (sh.profile) w.read_ns += t0.untilNow(sh.io, .awake).nanoseconds;
        var local_cfg = sh.cfg.*;
        local_cfg.path = sh.files[idx];
        const res = try lint.lintSourceProf(a, source, &local_cfg, if (sh.profile) &w.prof else null);
        if (res.parse_error) |pe| {
            slot.parse_err = try result_arena.dupe(u8, pe); // zperf-lint: ignore zp-alloc-in-loop
            continue;
        }
        slot.compat = res.compat;
// See the English guide for context.
// See the English guide for context.
        var text_len: usize = 0;
        for (res.findings) |f| text_len += f.detail.len;
        const fs = try result_arena.alloc(lint.Finding, res.findings.len);
        var text = try result_arena.alloc(u8, text_len);
        for (fs, res.findings) |*d, f| {
            @memcpy(text[0..f.detail.len], f.detail);
            d.* = .{ .rule = f.rule, .line = f.line, .column = f.column, .detail = text[0..f.detail.len] };
            text = text[f.detail.len..];
        }
        slot.findings = fs;
    }
}

fn optValue(args: []const [:0]const u8, i: *usize, a: []const u8, long: []const u8, short: ?[]const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, a, long) and a.len > long.len and a[long.len] == '=') return a[long.len + 1 ..];
    const match = std.mem.eql(u8, a, long) or (short != null and std.mem.eql(u8, a, short.?));
    if (match and i.* + 1 < args.len) {
        i.* += 1;
        return args[i.*];
    }
    return null;
}

fn usageError(err: *Io.Writer, what: []const u8, v: []const u8) !u8 {
    try err.print("zperf-lint: {s}: {s}\n\n{s}", .{ what, v, usage });
    return 2;
}

fn listRules(out: *Io.Writer) !void {
    for (rules.all) |r| {
        try out.print("{s}  {s:<24} {s:<7}  {s} / {s}\n", .{ r.code, r.name, r.severity.label(), r.msg_zh, r.msg_en });
        try out.print("       修复: {s}\n       误报风险: {s}\n", .{ r.fix, r.fp_risk });
    }
}

fn printText(out: *Io.Writer, all: []const FileFinding, nfiles: usize) !void {
    var counts: std.EnumArray(rules.Severity, usize) = .initFill(0);
    for (all) |ff| {
        const r = rules.get(ff.f.rule);
        counts.getPtr(r.severity).* += 1;
        try out.print("{s}:{d}:{d}: {s}[{s} {s}] {s} / {s}: {s}\n", .{
            ff.file, ff.f.line, ff.f.column, r.severity.label(), r.code, r.name, r.msg_zh, r.msg_en, ff.f.detail,
        });
        try out.print("    建议: {s}\n", .{r.fix});
    }
    try out.print("\n共检查 {d} 个文件，发现 {d} 处（warning {d}, info {d}, hint {d}）\n", .{
        nfiles, all.len, counts.get(.warning), counts.get(.info), counts.get(.hint),
    });
}

fn printJson(out: *Io.Writer, all: []const FileFinding, nfiles: usize, parse_errors: []const ParseError) !void {
    const J = struct {
        file: []const u8,
        line: u32,
        column: u32,
        rule: []const u8,
        name: []const u8,
        severity: []const u8,
        message_zh: []const u8,
        message_en: []const u8,
        detail: []const u8,
        fix: []const u8,
    };
    const PE = struct {
        file: []const u8,
        @"error": []const u8,
    };
    try out.writeAll("{\"tool\":\"zperf-lint\",");
    try out.print("\"files\":{d},\"count\":{d},\"findings\":[", .{ nfiles, all.len });
    for (all, 0..) |ff, idx| {
        const r = rules.get(ff.f.rule);
        if (idx != 0) try out.writeByte(',');
        try std.json.Stringify.value(J{
            .file = ff.file,
            .line = ff.f.line,
            .column = ff.f.column,
            .rule = r.code,
            .name = r.name,
            .severity = r.severity.label(),
            .message_zh = r.msg_zh,
            .message_en = r.msg_en,
            .detail = ff.f.detail,
            .fix = r.fix,
        }, .{}, out);
    }
    try out.writeAll("],\"parse_errors\":[");
    for (parse_errors, 0..) |pe, idx| {
        if (idx != 0) try out.writeByte(',');
        try std.json.Stringify.value(PE{ .file = pe.file, .@"error" = pe.message }, .{}, out);
    }
    try out.writeAll("]}\n");
}

test {
    _ = lint;
    _ = rules;
}
