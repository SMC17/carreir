// Comptime safety invariants for a vapor-compression chiller cycle.
//
// The invariants enforce two physical rules that any safe operating point
// must satisfy:
//
//   1. Discharge pressure must stay below the compressor's design rupture
//      limit (otherwise: surge / mechanical failure).
//   2. Compressor suction quality must be >= 1.0 (saturated vapor or
//      superheated). Anything wet drives liquid slugging through the
//      compressor — a leading cause of catastrophic chiller failure.
//
// Both checks are `comptime`, so a cycle that violates them fails to
// compile rather than failing in the field. This is the substrate primitive:
// physical guarantees enforced by the type-system, not by runtime asserts.

const std = @import("std");

/// The physical state of the refrigerant at one point in a chiller cycle.
pub const State = struct {
    temperature_c: f64,
    pressure_kpa: f64,
    enthalpy_kj_kg: f64,
    quality: f64, // 0.0 (saturated liquid) to 1.0 (saturated vapor); <0 subcooled, >1 superheated
};

/// Comptime safety checks for chiller operating points.
pub const SafetyInvariants = struct {
    /// Compile-error if discharge pressure exceeds the safe operating limit.
    pub fn assertSafeDischargePressure(comptime max_pressure_kpa: f64, comptime limit_kpa: f64) void {
        if (max_pressure_kpa >= limit_kpa) {
            @compileError("safety invariant violation: discharge pressure exceeds physical safety limit (risk of compressor surge / rupture).");
        }
    }

    /// Compile-error if suction stream contains liquid (slugging risk).
    pub fn assertNoLiquidSlugging(comptime suction_quality: f64) void {
        if (suction_quality < 1.0) {
            @compileError("safety invariant violation: suction quality < 1.0 indicates liquid slugging risk in compressor.");
        }
    }
};

/// Five-point representation of a vapor-compression chiller cycle.
pub const ChillerCycle = struct {
    evaporator: State,
    compressor_suction: State,
    compressor_discharge: State,
    condenser: State,
    expansion_valve: State,

    /// Run the comptime safety invariants on this cycle. Use inside
    /// `comptime` to get a compile-error on any violation.
    pub fn verifySafety(comptime self: ChillerCycle, comptime pressure_limit_kpa: f64) void {
        SafetyInvariants.assertSafeDischargePressure(self.compressor_discharge.pressure_kpa, pressure_limit_kpa);
        SafetyInvariants.assertNoLiquidSlugging(self.compressor_suction.quality);
    }
};

const testing = std.testing;

test "safe cycle compiles and verifies at comptime" {
    const safe_cycle = ChillerCycle{
        .evaporator = .{ .temperature_c = 5.0, .pressure_kpa = 500.0, .enthalpy_kj_kg = 200.0, .quality = 0.5 },
        .compressor_suction = .{ .temperature_c = 10.0, .pressure_kpa = 500.0, .enthalpy_kj_kg = 250.0, .quality = 1.05 }, // Superheated vapor
        .compressor_discharge = .{ .temperature_c = 80.0, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 300.0, .quality = 1.5 },
        .condenser = .{ .temperature_c = 40.0, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 150.0, .quality = 0.5 },
        .expansion_valve = .{ .temperature_c = 40.0, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 100.0, .quality = -0.1 }, // Subcooled liquid
    };

    // Comptime evaluation = static guarantee against surge and slugging.
    comptime safe_cycle.verifySafety(2000.0);

    try testing.expectEqual(true, true);
}
