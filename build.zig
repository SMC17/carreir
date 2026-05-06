const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "carrier_sovereign_node",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
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

    const exe_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const main_test_cmd = b.addRunArtifact(exe_tests);
    test_step.dependOn(&main_test_cmd.step);
    
    const cobs_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cobs.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const cobs_test_cmd = b.addRunArtifact(cobs_tests);
    test_step.dependOn(&cobs_test_cmd.step);

    const ingest_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ingest.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const ingest_test_cmd = b.addRunArtifact(ingest_tests);
    test_step.dependOn(&ingest_test_cmd.step);

    const audit_step = b.step("audit", "Run hardware invariant audit (Causality & Comptime checks)");
    audit_step.dependOn(test_step); 
}
