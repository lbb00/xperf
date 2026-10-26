const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{}); // -Dtarget=... -Dcpu=native
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize != .debug,
            .single_threaded = false,
            .unwind_tables = .none,
            .omit_frame_pointer = true,
        }),
    });
    exe.lto = .full;
    b.installArtifact(exe);
}
