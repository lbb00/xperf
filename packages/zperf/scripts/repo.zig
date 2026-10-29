const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;

const chapters = [_][]const u8{
    "00_head.md",
    "02_memory.md",
    "03_c.md",
    "05_compute.md",
    "06_concurrency.md",
    "07_build.md",
    "08_measure.md",
    "09_lint.md",
    "10_cheat.md",
    "11_refs.md",
};

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len < 2) return usage(init.io);

    if (std.mem.eql(u8, args[1], "build-guide")) {
        try buildGuide(allocator, init.io);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "lint-all")) {
        return lintAll(allocator, init, args[2..]);
    }
    return usage(init.io);
}

fn usage(io: Io) u8 {
    var buffer: [512]u8 = undefined;
    var writer = Io.File.stderr().writerStreaming(io, &buffer);
    writer.interface.writeAll(
        "Usage: zig run scripts/repo.zig -- <command>\n\n" ++
            "Commands:\n" ++
            "  build-guide   Generate docs/zig-performance-guide.md\n" ++
            "  lint-all      Run zperf-lint and installed community linters\n",
    ) catch {};
    writer.interface.flush() catch {};
    return 2;
}

fn buildGuide(allocator: Allocator, io: Io) !void {
    const linter = "zperf-lint/zig-out/bin/zperf-lint";
    const rules_result = try std.process.run(allocator, io, .{
        .argv = &.{ linter, "--list-rules" },
    });
    defer allocator.free(rules_result.stdout);
    defer allocator.free(rules_result.stderr);
    if (!rules_result.term.success()) return error.LinterFailed;

    const table = try ruleTable(allocator, rules_result.stdout);
    const dir = Io.Dir.cwd();
    var guide: std.ArrayList(u8) = .empty;
    for (chapters, 0..) |chapter, index| {
        const path = try std.fmt.allocPrint(allocator, "docs/guide-src/{s}", .{chapter});
        const source = try dir.readFileAlloc(io, path, allocator, .unlimited);
        defer allocator.free(source);
        const expanded = try expandChapter(allocator, io, source, table);
        defer allocator.free(expanded);
        if (index != 0) try guide.appendSlice(allocator, "\n");
        try guide.appendSlice(allocator, std.mem.trimEnd(u8, expanded, "\r\n"));
        try guide.append(allocator, '\n');
    }
    try dir.writeFile(io, .{
        .sub_path = "docs/zig-performance-guide.md",
        .data = guide.items,
        .flags = .{ .truncate = true },
    });

    var buffer: [256]u8 = undefined;
    var writer = Io.File.stdout().writerStreaming(io, &buffer);
    try writer.interface.print("Generated docs/zig-performance-guide.md ({d} lines)\n", .{std.mem.countScalar(u8, guide.items, '\n')});
    try writer.interface.flush();
}

fn ruleTable(allocator: Allocator, output: []const u8) ![]u8 {
    var rows: std.ArrayList(u8) = .empty;
    try rows.appendSlice(allocator, "| ID | Name | Severity | Detection |\n|---|---|---|---|\n");
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "ZP")) continue;
        var pos: usize = 0;
        const id = nextWord(line, &pos) orelse continue;
        const name = nextWord(line, &pos) orelse continue;
        const severity = nextWord(line, &pos) orelse continue;
        var description = std.mem.trim(u8, line[pos..], " \t");
        if (englishAfterSlash(description)) |english| description = english;
        const escaped = try std.mem.replaceOwned(u8, allocator, description, "|", "\\|");
        defer allocator.free(escaped);
        const row = try std.fmt.allocPrint(allocator, "| {s} | `{s}` | {s} | {s} |\n", .{ id, name, severity, escaped });
        try rows.appendSlice(allocator, row);
    }
    return rows.toOwnedSlice(allocator);
}

fn nextWord(line: []const u8, pos: *usize) ?[]const u8 {
    while (pos.* < line.len and (line[pos.*] == ' ' or line[pos.*] == '\t')) : (pos.* += 1) {}
    if (pos.* == line.len) return null;
    const start = pos.*;
    while (pos.* < line.len and line[pos.*] != ' ' and line[pos.*] != '\t') : (pos.* += 1) {}
    return line[start..pos.*];
}

fn englishAfterSlash(text: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (std.mem.indexOfPos(u8, text, i, " / ")) |at| : (i = at + 3) {
        const candidate = text[at + 3 ..];
        var ascii_only = true;
        for (candidate) |byte| if (!std.ascii.isAscii(byte)) {
            ascii_only = false;
            break;
        };
        if (ascii_only) return candidate;
    }
    return null;
}

fn expandChapter(allocator: Allocator, io: Io, source: []const u8, table: []const u8) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    var offset: usize = 0;
    while (offset < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, offset, '\n') orelse source.len;
        const line = std.mem.trimEnd(u8, source[offset..line_end], "\r");
        if (std.mem.eql(u8, line, "@@RULE_TABLE@@")) {
            try output.appendSlice(allocator, table);
        } else if (std.mem.eql(u8, line, "@@LINT_OUTPUT@@")) {
            try output.appendSlice(allocator, lintExample);
            try output.append(allocator, '\n');
        } else if (line.len > 4 and std.mem.startsWith(u8, line, "@@") and std.mem.endsWith(u8, line, "@@")) {
            const name = line[2 .. line.len - 2];
            const path = try std.fmt.allocPrint(allocator, "examples/{s}", .{name});
            const code = try Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
            defer allocator.free(code);
            const how: []const u8 = if (std.mem.eql(u8, name, "m12_gpa_select.zig")) "zig run" else if (std.mem.eql(u8, name, "p12_bench.zig") or std.mem.eql(u8, name, "p14_alloc_shootout.zig") or std.mem.eql(u8, name, "p15_soa_bandwidth.zig") or std.mem.eql(u8, name, "p16_simd_vs_scalar.zig") or std.mem.eql(u8, name, "p17_false_sharing.zig") or std.mem.eql(u8, name, "p18_labeled_switch.zig") or std.mem.eql(u8, name, "p19_io_buffering.zig") or std.mem.eql(u8, name, "p20_buffer_pool.zig")) "zig run -O fast" else if (std.mem.endsWith(u8, name, "build.zig")) "zig build -Doptimize=fast" else "zig test";
            const block = try std.fmt.allocPrint(allocator, "> Example: `examples/{s}` (checked with Zig 0.17.0 using `{s}`).\n\n```zig\n{s}\n```\n", .{ name, how, std.mem.trimEnd(u8, code, "\r\n") });
            try output.appendSlice(allocator, block);
        } else {
            try output.appendSlice(allocator, source[offset..line_end]);
            if (line_end < source.len) try output.append(allocator, '\n');
        }
        offset = if (line_end < source.len) line_end + 1 else source.len;
    }
    return output.toOwnedSlice(allocator);
}

const lintExample = "$ zperf-lint fixtures/bad/zp-alloc-print-hot.zig\n" ++
    "fixtures/bad/zp-alloc-print-hot.zig:6:44: hint[zp-alloc-print-hot alloc-print-in-loop] allocPrint or Allocator.print of a loop-invariant value\n" ++
    "    suggestion: format once outside the loop when the arguments do not change\n\n" ++
    "Checked 1 file; found 1 issue (0 warnings, 0 info, 1 hint)\n$ echo $?\n1";

fn lintAll(allocator: Allocator, init: std.process.Init, requested: []const [:0]const u8) !u8 {
    var paths: std.ArrayList([]const u8) = .empty;
    if (requested.len == 0) {
        try paths.appendSlice(allocator, &.{ "examples", "zperf-lint/src" });
    } else {
        for (requested) |path| try paths.append(allocator, path);
    }
    const env = init.environ_map;
    const tool_dir = env.get("TOOLS") orelse "third-party/bin";
    const zperf = env.get("ZPERF") orelse "zperf-lint/zig-out/bin/zperf-lint";
    const files = try collectZigFiles(allocator, init.io, paths.items);
    defer allocator.free(files);

    var failed = false;
    var zperf_argv: std.ArrayList([]const u8) = .empty;
    try zperf_argv.append(allocator, zperf);
    try zperf_argv.appendSlice(allocator, paths.items);
    failed = !(try runTool(allocator, init.io, "zperf-lint", true, zperf_argv.items)) or failed;
    const zbc = try std.fmt.allocPrint(allocator, "{s}/zbc", .{tool_dir});
    failed = !(try runToolWithFiles(allocator, init.io, "zbc", true, &.{ zbc, "--format=compact", "--no-color" }, files)) or failed;
    const zlint = try std.fmt.allocPrint(allocator, "{s}/zlint", .{tool_dir});
    var zlint_argv: std.ArrayList([]const u8) = .empty;
    try zlint_argv.appendSlice(allocator, &.{ zlint, "-c", "ci/zlint.json", "-f", "github" });
    try zlint_argv.appendSlice(allocator, paths.items);
    failed = !(try runTool(allocator, init.io, "zlint", true, zlint_argv.items)) or failed;
    const ziglint = try std.fmt.allocPrint(allocator, "{s}/ziglint", .{tool_dir});
    var ziglint_argv: std.ArrayList([]const u8) = .empty;
    try ziglint_argv.appendSlice(allocator, &.{ ziglint, "--ignore", "Z024" });
    try ziglint_argv.appendSlice(allocator, paths.items);
    _ = try runTool(allocator, init.io, "ziglint", false, ziglint_argv.items);
    const zwanzig = try std.fmt.allocPrint(allocator, "{s}/zwanzig", .{tool_dir});
    var zwanzig_argv: std.ArrayList([]const u8) = .empty;
    try zwanzig_argv.appendSlice(allocator, &.{ zwanzig, "--skip", "file-as-struct", "--skip", "unused-decl" });
    try zwanzig_argv.appendSlice(allocator, paths.items);
    _ = try runTool(allocator, init.io, "zwanzig", false, zwanzig_argv.items);
    return if (failed) 1 else 0;
}

fn runToolWithFiles(allocator: Allocator, io: Io, name: []const u8, blocking: bool, prefix: []const []const u8, files: []const []const u8) !bool {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(allocator, prefix);
    try argv.appendSlice(allocator, files);
    return runTool(allocator, io, name, blocking, argv.items);
}

fn runTool(allocator: Allocator, io: Io, name: []const u8, blocking: bool, argv: []const []const u8) !bool {
    const result = std.process.run(allocator, io, .{
        .argv = argv,
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(16 * 1024 * 1024),
    }) catch |err| switch (err) {
        error.FileNotFound => {
            try printLine(io, "::notice::Skipping {s} (not installed: {s})\n", .{ name, argv[0] });
            return true;
        },
        else => return err,
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    if (result.stdout.len != 0) try writeStdout(io, result.stdout);
    if (result.stderr.len != 0) try writeStderr(io, result.stderr);
    if (result.term.success()) {
        try printLine(io, "✓ {s} passed\n", .{name});
        return true;
    }
    if (blocking) {
        try printLine(io, "✗ {s} failed ({t})\n", .{ name, result.term });
        return false;
    }
    try printLine(io, "△ {s} reported issues ({t}; advisory only)\n", .{ name, result.term });
    return true;
}

fn collectZigFiles(allocator: Allocator, io: Io, paths: []const []const u8) ![][]const u8 {
    var files: std.ArrayList([]const u8) = .empty;
    const cwd = Io.Dir.cwd();
    for (paths) |path| {
        if (std.mem.endsWith(u8, path, ".zig")) {
            try files.append(allocator, path);
            continue;
        }
        const dir = cwd.openDir(io, path, .{ .iterate = true }) catch continue;
        var walker = try dir.walk(allocator);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".zig")) continue;
            var components = std.mem.tokenizeScalar(u8, entry.path, '/');
            var generated = false;
            while (components.next()) |component| {
                if (std.mem.eql(u8, component, ".zig-cache") or std.mem.eql(u8, component, "zig-out")) {
                    generated = true;
                    break;
                }
            }
            if (generated) continue;
            try files.append(allocator, try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.path }));
        }
    }
    std.mem.sort([]const u8, files.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);
    return files.toOwnedSlice(allocator);
}

fn writeStdout(io: Io, bytes: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    var writer = Io.File.stdout().writerStreaming(io, &buffer);
    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
}

fn writeStderr(io: Io, bytes: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    var writer = Io.File.stderr().writerStreaming(io, &buffer);
    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
}

fn printLine(io: Io, comptime format: []const u8, args: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var writer = Io.File.stdout().writerStreaming(io, &buffer);
    try writer.interface.print(format, args);
    try writer.interface.flush();
}
