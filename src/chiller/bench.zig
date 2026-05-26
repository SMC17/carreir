const std = @import("std");
const chiller = @import("chiller");

// We define a comptime array of 10 safe states to simulate rapid transition.
// Every state is statically verified at compile time to ensure 0ns runtime overhead.
const NUM_STATES = 10;
const safe_states = blk: {
    var states: [NUM_STATES]chiller.ChillerCycle = undefined;
    for (&states, 0..) |*state, i| {
        const offset: f64 = @floatFromInt(i);
        state.* = chiller.ChillerCycle{
            .evaporator = .{ .temperature_c = 5.0 + offset, .pressure_kpa = 500.0, .enthalpy_kj_kg = 200.0, .quality = 0.5 },
            .compressor_suction = .{ .temperature_c = 10.0 + offset, .pressure_kpa = 500.0, .enthalpy_kj_kg = 250.0, .quality = 1.05 },
            .compressor_discharge = .{ .temperature_c = 80.0 + offset, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 300.0, .quality = 1.5 },
            .condenser = .{ .temperature_c = 40.0 + offset, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 150.0, .quality = 0.5 },
            .expansion_valve = .{ .temperature_c = 40.0 + offset, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 100.0, .quality = -0.1 },
        };
        // The magic: static invariant checks execute at compile time!
        state.verifyShaoYong(2000.0);
    }
    break :blk states;
};

pub fn main(init: std.process.Init) !void {
    _ = init;
    std.debug.print("Initializing ChillerCycle High-Frequency Benchmark (Shao-Yong Static Invariants)\n", .{});

    const ITERATIONS: usize = 10_000_000;
    var current_state: chiller.ChillerCycle = safe_states[0];
    
    // Rapidly transition states at runtime
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        current_state = safe_states[i % NUM_STATES];
        std.mem.doNotOptimizeAway(&current_state);
    }

    std.debug.print("Completed {d} state transitions\n", .{ITERATIONS});
}
