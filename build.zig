const std = @import("std");

// carreir build — substrate-only.
//
// The main build path covers four composable hulls under `src/`:
//   psychrometric/   ASHRAE 2021 moist-air primitives
//   refrigerant/     NIST-cited P-T saturation tables
//   coldchain/       HMAC-signed append-only reefer log
//   chiller/         Thermodynamic chiller cycle model

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    // --- chiller hull ---
    const chiller_mod = b.createModule(.{
        .root_source_file = b.path("src/chiller/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    const chiller_tests = b.addTest(.{ .root_module = chiller_mod });
    test_step.dependOn(&b.addRunArtifact(chiller_tests).step);

    // --- CLI: `carreir` over all three hulls ---
    //
    // src/main.zig uses the Zig 0.16 `pub fn main(init: std.process.Init)`
    // entry-point shape — args come from init.minimal.args, stdio from
    // init.io. The three hulls below are wired as named module imports so
    // the binary can call into them without crossing module boundaries.
    const cli_psychro = b.createModule(.{
        .root_source_file = b.path("src/psychrometric/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    const cli_refrigerant = b.createModule(.{
        .root_source_file = b.path("src/refrigerant/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    const cli_coldchain = b.createModule(.{
        .root_source_file = b.path("src/coldchain/log.zig"),
        .target = target,
        .optimize = optimize,
    });
    const cli_chiller = b.createModule(.{
        .root_source_file = b.path("src/chiller/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cli_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_mod.addImport("psychrometric", cli_psychro);
    cli_mod.addImport("refrigerant", cli_refrigerant);
    cli_mod.addImport("coldchain", cli_coldchain);
    cli_mod.addImport("chiller", cli_chiller);

    const cli_exe = b.addExecutable(.{
        .name = "carreir",
        .root_module = cli_mod,
    });
    b.installArtifact(cli_exe);

    const run_cmd = b.addRunArtifact(cli_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |run_args| run_cmd.addArgs(run_args);
    const run_step = b.step("run", "Run the carreir CLI");
    run_step.dependOn(&run_cmd.step);

    // --- Chiller Benchmark ---
    const bench_mod = b.createModule(.{
        .root_source_file = b.path("src/chiller/bench.zig"),
        .target = target,
        .optimize = optimize,
    });
    bench_mod.addImport("chiller", chiller_mod);

    const bench_exe = b.addExecutable(.{
        .name = "carreir_bench",
        .root_module = bench_mod,
    });
    const run_bench_cmd = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run ChillerCycle benchmarks");
    bench_step.dependOn(&run_bench_cmd.step);
}
