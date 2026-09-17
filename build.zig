const std = @import("std");

/// Zig 0.16.0's default macOS range still tops out at 15.6. Pin a range that
/// covers Sequoia (15), Tahoe (26), and macOS 27 without marking a native
/// macOS 27 build as minos=27 (which would refuse to run on 15/26).
const macos_min: std.SemanticVersion = .{ .major = 13, .minor = 0, .patch = 0 };
const macos_max: std.SemanticVersion = .{ .major = 27, .minor = 0, .patch = 0 };

pub fn build(b: *std.Build) void {
    const query = withMacosVersionRange(b.standardTargetOptionsQueryOnly(.{
        .default_target = .{
            .os_tag = .macos,
            .os_version_min = .{ .semver = macos_min },
            .os_version_max = .{ .semver = macos_max },
        },
    }));
    const target = b.resolveTargetQuery(query);
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zapmenu",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.linkFramework("CoreGraphics", .{});
    exe.root_module.linkFramework("CoreFoundation", .{});

    addDarwinSdkPaths(b, exe.root_module);

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_exe.addArgs(args);
    }
    const run_step = b.step("run", "Run zapmenu");
    run_step.dependOn(&run_exe.step);

    // Tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/clamp_test.zig"),
            .target = b.graph.host,
        }),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark
    const bench_exe = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });
    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.step.dependOn(b.getInstallStep());
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);
}

fn withMacosVersionRange(query: std.Target.Query) std.Target.Query {
    var q = query;
    const os_tag = q.os_tag orelse @import("builtin").os.tag;
    if (os_tag != .macos) return q;
    if (q.os_version_min == null) q.os_version_min = .{ .semver = macos_min };
    if (q.os_version_max == null) q.os_version_max = .{ .semver = macos_max };
    return q;
}

fn addDarwinSdkPaths(b: *std.Build, module: *std.Build.Module) void {
    if (b.graph.host.result.os.tag == .macos) {
        if (std.zig.system.darwin.getSdk(b.graph.arena, b.graph.io, &b.graph.host.result)) |sdk| {
            module.addFrameworkPath(.{
                .cwd_relative = b.fmt("{s}/System/Library/Frameworks", .{sdk}),
            });
            module.addLibraryPath(.{
                .cwd_relative = b.fmt("{s}/usr/lib", .{sdk}),
            });
        }
    }
}
