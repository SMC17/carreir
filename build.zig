const std = @import("std");

// carreir build — substrate-only.
//
// The main build path covers the three composable hulls under `src/`:
//   psychrometric/   ASHRAE 2021 moist-air primitives
//   refrigerant/     NIST-cited P-T saturation tables
//   coldchain/       HMAC-signed append-only reefer log
//
// The `experimental/` directory holds `sketch`-level scaffolds and is
// opt-in via `-Dexperimental=true`. Those files are NOT substrate and
// must not be confused with the hulls under src/.

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const experimental = b.option(bool, "experimental", "Include sketch-level experimental/ scaffolds (default false)") orelse false;

    const test_step = b.step("test", "Run all substrate tests");

    // --- psychrometric hull ---
    const psychro_mod = b.createModule(.{
        .root_source_file = b.path("src/psychrometric/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    const psychro_tests = b.addTest(.{ .root_module = psychro_mod });
    test_step.dependOn(&b.addRunArtifact(psychro_tests).step);

    // Cross-check fixtures against ASHRAE 2021 reference values.
    const psychro_fixtures_mod = b.createModule(.{
        .root_source_file = b.path("src/psychrometric/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const psychro_fixtures = b.addTest(.{ .root_module = psychro_fixtures_mod });
    test_step.dependOn(&b.addRunArtifact(psychro_fixtures).step);

    // --- refrigerant hull ---
    const refrigerant_mod = b.createModule(.{
        .root_source_file = b.path("src/refrigerant/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    const refrigerant_tests = b.addTest(.{ .root_module = refrigerant_mod });
    test_step.dependOn(&b.addRunArtifact(refrigerant_tests).step);

    const refrigerant_fixtures_mod = b.createModule(.{
        .root_source_file = b.path("src/refrigerant/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const refrigerant_fixtures = b.addTest(.{ .root_module = refrigerant_fixtures_mod });
    test_step.dependOn(&b.addRunArtifact(refrigerant_fixtures).step);

    // --- coldchain hull ---
    const coldchain_mod = b.createModule(.{
        .root_source_file = b.path("src/coldchain/log.zig"),
        .target = target,
        .optimize = optimize,
    });
    const coldchain_tests = b.addTest(.{ .root_module = coldchain_mod });
    test_step.dependOn(&b.addRunArtifact(coldchain_tests).step);

    // CLI (src/main.zig) defers to follow-up — uses Zig 0.14-era APIs that
    // need porting to the 0.16 `pub fn main(init: std.process.Init)` shape.

    if (experimental) {
        addExperimental(b, target, optimize, test_step);
    }
}

fn addExperimental(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    test_step: *std.Build.Step,
) void {
    // experimental/ scaffolds — sketch evidence only. Opt-in.
    const cobs_dep = b.dependency("cobs", .{
        .target = target,
        .optimize = optimize,
    });
    const cobs_mod = cobs_dep.module("cobs");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("experimental/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("cobs", cobs_mod);

    const exe = b.addExecutable(.{
        .name = "carrier_sovereign_node_sketch",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const main_test_mod = b.createModule(.{
        .root_source_file = b.path("experimental/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_test_mod.addImport("cobs", cobs_mod);
    const exe_tests = b.addTest(.{ .root_module = main_test_mod });
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);

    const ingest_test_mod = b.createModule(.{
        .root_source_file = b.path("experimental/ingest.zig"),
        .target = target,
        .optimize = optimize,
    });
    ingest_test_mod.addImport("cobs", cobs_mod);
    const ingest_tests = b.addTest(.{ .root_module = ingest_test_mod });
    test_step.dependOn(&b.addRunArtifact(ingest_tests).step);

    const ptx_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("experimental/ptx_incursion.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(ptx_tests).step);
}
