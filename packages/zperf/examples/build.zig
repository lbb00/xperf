const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const test_step = b.step("test", "Compile and run the guide examples");

    const test_sources = [_][]const u8{
        "c01_enum_width.zig", "c02_bitfield.zig", "c03_layout.zig", "c04_union.zig", "c05_flags.zig", "c06_car_case.zig",
        "m01_arena.zig", "m02_fba.zig", "m03_buffer_first.zig", "m04_pool.zig", "m05_soa.zig", "m06_packed.zig",
        "m07_index.zig", "m08_intern.zig", "m09_reserve_first.zig", "m10_stack_list.zig", "m11_static.zig", "m13_out_of_band.zig", "m14_static_phases.zig", "m15_buffer_pool.zig", "m16_arena_retain_limit.zig", "m17_offset_slab.zig",
        "p01_comptime_lut.zig", "p02_simd.zig", "p03_branchless.zig", "p04_labeled_switch.zig", "p05_hints.zig", "p06_false_sharing.zig",
        "p07_safety.zig", "p08_int_tricks.zig", "p09_hot_loop.zig", "p10_io_writer.zig", "p11_group.zig", "p13_uring.zig",
        "x01_optional.zig", "x02_enum_containers.zig", "x03_zero_copy.zig", "x04_varint.zig", "x05_tagged_ptr.zig", "x06_generation.zig",
        "x07_mmap.zig", "x08_nanbox.zig", "x09_sso.zig",
    };

    for (test_sources) |source| {
        const module = b.createModule(.{
            .root_source_file = b.path(source),
            .target = target,
            .optimize = optimize,
        });
        const test_exe = b.addTest(.{ .root_module = module });
        test_step.dependOn(&b.addRunArtifact(test_exe).step);
    }

    for ([_][]const u8{ "m12_gpa_select.zig", "p12_bench.zig", "p14_alloc_shootout.zig", "p15_soa_bandwidth.zig", "p16_simd_vs_scalar.zig", "p17_false_sharing.zig", "p18_labeled_switch.zig", "p19_io_buffering.zig", "p20_buffer_pool.zig" }) |source| {
        inline for (.{ .debug, .fast }) |mode| {
            const module = b.createModule(.{
                .root_source_file = b.path(source),
                .target = target,
                .optimize = mode,
            });
            const exe = b.addExecutable(.{ .name = b.fmt("{s}-{s}", .{ source, @tagName(mode) }), .root_module = module });
            test_step.dependOn(&b.addRunArtifact(exe).step);
        }
    }

    const build_example = b.addSystemCommand(&.{ "zig", "build", "-Doptimize=fast" });
    build_example.setCwd(b.path("build_example"));
    test_step.dependOn(&build_example.step);
}
