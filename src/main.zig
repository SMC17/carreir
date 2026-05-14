const std = @import("std");
const core = @import("carrier_core.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    std.debug.print("Initializing Carrier Sovereign Cognitive Node [FLEET SCALE]...\n", .{});
    std.debug.print("Targeting APX / Micro-Link Architecture.\n", .{});

    const thread_count = 10;
    var threads: [thread_count]std.Thread = undefined;

    std.debug.print("Scaling Ingest Engine: Spawning {d} threads (10 units/thread)...\n", .{thread_count});

    for (0..thread_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, simulateBatch, .{ i, allocator });
    }

    for (threads) |t| {
        t.join();
    }

    std.debug.print("Fleet Simulation Complete. 100 units audited.\n", .{});
}

fn simulateBatch(batch_id: usize, allocator: std.mem.Allocator) void {
    for (0..10) |i| {
        const unit_id = batch_id * 10 + i;
        simulateUnit(unit_id, allocator);
    }
}

fn simulateUnit(id: usize, allocator: std.mem.Allocator) void {
    const initial_latent_state = core.Hexagram.EntropyMinimizing;
    const action = initial_latent_state.toAction();

    const current_state = core.PhysicalState{
        .ambient_temp_c = 35.0,
        .target_temp_c = -20.0,
        .compressor_rpm = @intFromFloat(action.compressor_speed * 3000),
        .refrigerant_pressure_psi = 150.0,
        .energy_input_watts = action.compressor_speed * 5000.0,
        .enthalpy_h = 400.0,
        .entropy_s = 1.5,
        .config = core.CarrierConfig.default,
    };

    const researcher = core.ResearchEngine{ .allocator = allocator };
    const best_cycle = researcher.explore(current_state) catch return;

    if (id % 20 == 0) {
        std.debug.print("[Unit {d}] Alpha Cycle Discovered (COP: {d:.2})\n", .{ id, best_cycle.avg_cop });
    }
}

test "Causality Invariant Enforcement" {
    const state = core.PhysicalState{
        .ambient_temp_c = 30.0,
        .target_temp_c = 22.0,
        .compressor_rpm = 1000,
        .refrigerant_pressure_psi = 100.0,
        .energy_input_watts = 2000.0,
        .enthalpy_h = 400.0,
        .entropy_s = 1.5,
        .config = core.CarrierConfig.default,
    };
    
    const pressure_violation = core.PhysicalState{
        .ambient_temp_c = 30.0,
        .target_temp_c = 22.0,
        .compressor_rpm = 1000,
        .refrigerant_pressure_psi = 500.0, // Exceeds 450.0 max
        .energy_input_watts = 2000.0,
        .enthalpy_h = 400.0,
        .entropy_s = 1.5,
        .config = core.CarrierConfig.default,
    };

    const surge_violation = core.PhysicalState{
        .ambient_temp_c = 30.0,
        .target_temp_c = 22.0,
        .compressor_rpm = 5000, // Exceeds 4500 max
        .refrigerant_pressure_psi = 100.0,
        .energy_input_watts = 2000.0,
        .enthalpy_h = 400.0,
        .entropy_s = 1.5,
        .config = core.CarrierConfig.default,
    };

    try std.testing.expectError(core.CausalityError.PressureInvariantViolation, state.checkCausality(pressure_violation));
    try std.testing.expectError(core.CausalityError.CompressorSurge, state.checkCausality(surge_violation));
}
