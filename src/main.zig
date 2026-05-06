const std = @import("std");
const core = @import("carrier_core.zig");

pub fn main() !void {
    std.debug.print("Initializing Carrier Sovereign Cognitive Node...\n", .{});
    std.debug.print("Targeting APX / Micro-Link Architecture.\n", .{});

    const current_state = core.PhysicalState{
        .ambient_temp_c = 35.0,
        .target_temp_c = -20.0, // Cold Chain target
        .compressor_rpm = 1200,
        .refrigerant_pressure_psi = 150.0,
    };

    const action_token = core.tokenizeAction(current_state);
    std.debug.print("Action Tokenized (Comptime SIMD-DCT): 0x{X}\n", .{action_token});

    const proposed_next_state = core.PhysicalState{
        .ambient_temp_c = 35.0,
        .target_temp_c = -20.0,
        .compressor_rpm = 3000,
        .refrigerant_pressure_psi = 500.0, // Triggers .ml3 Max Pressure (450.0)
    };

    std.debug.print("Auditing Proposed State Transition against Shao-Yong Causality Invariants...\n", .{});
    if (current_state.checkCausality(proposed_next_state)) {
        std.debug.print("Transition Verified. Executing.\n", .{});
    } else |err| {
        std.debug.print("HALT: Causality Violation Detected: {}\n", .{err});
        std.debug.print("Advantage RL signal penalized. Hardware damage averted.\n", .{});
    }
}

test "Causality Invariant Enforcement" {
    const state = core.PhysicalState{
        .ambient_temp_c = 30.0,
        .target_temp_c = 22.0,
        .compressor_rpm = 1000,
        .refrigerant_pressure_psi = 100.0,
    };
    
    const pressure_violation = core.PhysicalState{
        .ambient_temp_c = 30.0,
        .target_temp_c = 22.0,
        .compressor_rpm = 1000,
        .refrigerant_pressure_psi = 500.0, // Exceeds 450.0 max
    };

    const surge_violation = core.PhysicalState{
        .ambient_temp_c = 30.0,
        .target_temp_c = 22.0,
        .compressor_rpm = 5000, // Exceeds 4500 max
        .refrigerant_pressure_psi = 100.0,
    };

    try std.testing.expectError(core.CausalityError.PressureInvariantViolation, state.checkCausality(pressure_violation));
    try std.testing.expectError(core.CausalityError.CompressorSurge, state.checkCausality(surge_violation));
}
