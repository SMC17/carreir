const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cobs_dep = b.dependency("cobs", .{
        .target = target,
        .optimize = optimize,
    });
    const cobs_mod = cobs_dep.module("cobs");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("cobs", cobs_mod);

    const exe = b.addExecutable(.{
        .name = "carrier_sovereign_node",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the Carrier Sovereign node");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run all Sovereign Verification tests");

    const main_test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_test_mod.addImport("cobs", cobs_mod);
    const exe_tests = b.addTest(.{ .root_module = main_test_mod });
    const main_test_cmd = b.addRunArtifact(exe_tests);
    test_step.dependOn(&main_test_cmd.step);

    const ingest_test_mod = b.createModule(.{
        .root_source_file = b.path("src/ingest.zig"),
        .target = target,
        .optimize = optimize,
    });
    ingest_test_mod.addImport("cobs", cobs_mod);
    const ingest_tests = b.addTest(.{ .root_module = ingest_test_mod });
    const ingest_test_cmd = b.addRunArtifact(ingest_tests);
    test_step.dependOn(&ingest_test_cmd.step);

    const ptx_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ptx_incursion.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const ptx_test_cmd = b.addRunArtifact(ptx_tests);
    test_step.dependOn(&ptx_test_cmd.step);

    const audit_exe = b.addExecutable(.{
        .name = "carrier_audit",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audit_node.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const audit_run = b.addRunArtifact(audit_exe);
    const audit_step = b.step("audit", "Run hardware invariant audit (Register Pressure & Scientific Intent)");
    audit_step.dependOn(&audit_run.step);
}
