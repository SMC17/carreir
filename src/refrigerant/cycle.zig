const std = @import("std");

/// Project Omega-Scalar: Carrier Chiller Invariants
///
/// Implements Shao-Yong Pressure Checking for high-power industrial HVAC.
/// Ensures the chiller substrate remains within safe physical bounds.
pub const ChillerInvariants = struct {
    pub const State = struct {
        suction_pressure_psi: f32,
        discharge_pressure_psi: f32,
        ambient_temp_c: f32,
    };

    /// Verify the thermodynamic invariant of the compressor.
    /// Rejects states that would cause "Surge" or "Liquid Slugging".
    pub fn isSafe(state: State) bool {
        // Invariant 1: Compression Ratio must not exceed surge limit
        const ratio = state.discharge_pressure_psi / (state.suction_pressure_psi + 0.001);
        if (ratio > 8.0) return false; // Surge Risk

        // Invariant 2: Suction pressure must be above freeze-point
        if (state.suction_pressure_psi < 25.0) return false; // Freeze/Slugging Risk

        return true;
    }
};

test "Carrier Chiller - Surge Detection" {
    // Normal operation
    try std.testing.expect(ChillerInvariants.isSafe(.{
        .suction_pressure_psi = 100.0,
        .discharge_pressure_psi = 300.0,
        .ambient_temp_c = 25.0,
    }));

    // Dangerous operation (High compression ratio)
    try std.testing.expect(!ChillerInvariants.isSafe(.{
        .suction_pressure_psi = 50.0,
        .discharge_pressure_psi = 500.0,
        .ambient_temp_c = 40.0,
    }));
}
