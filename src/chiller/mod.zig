const std = @import("std");

/// The physical state of the refrigerant in a chiller cycle.
pub const State = struct {
    temperature_c: f64,
    pressure_kpa: f64,
    enthalpy_kj_kg: f64,
    quality: f64, // 0.0 (saturated liquid) to 1.0 (saturated vapor); <0 subcooled, >1 superheated
};

/// Shao-Yong Pressure Invariants for safe chiller operation.
pub const ShaoYongInvariants = struct {
    /// Compiling this will fail if the maximum discharge pressure exceeds the safe limit.
    pub fn assertSafeDischargePressure(comptime max_pressure_kpa: f64, comptime limit_kpa: f64) void {
        if (max_pressure_kpa >= limit_kpa) {
            @compileError("Shao-Yong Invariant Violation: Discharge pressure exceeds physical safety limit (risk of compressor surge/rupture).");
        }
    }

    /// Compiling this will fail if liquid is allowed into the compressor.
    pub fn assertNoLiquidSlugging(comptime suction_quality: f64) void {
        if (suction_quality < 1.0) {
            @compileError("Shao-Yong Invariant Violation: Suction quality < 1.0 indicates liquid slugging risk in compressor.");
        }
    }
};

/// Thermodynamic State Machine for an HVAC cycle.
pub const ChillerCycle = struct {
    evaporator: State,
    compressor_suction: State,
    compressor_discharge: State,
    condenser: State,
    expansion_valve: State,

    /// Trigger static invariant checks at compile time.
    pub fn verifyShaoYong(comptime self: ChillerCycle, comptime pressure_limit_kpa: f64) void {
        ShaoYongInvariants.assertSafeDischargePressure(self.compressor_discharge.pressure_kpa, pressure_limit_kpa);
        ShaoYongInvariants.assertNoLiquidSlugging(self.compressor_suction.quality);
    }
};

const testing = std.testing;

test "Shao-Yong safe cycle compiles and verifies" {
    const safe_cycle = ChillerCycle{
        .evaporator = .{ .temperature_c = 5.0, .pressure_kpa = 500.0, .enthalpy_kj_kg = 200.0, .quality = 0.5 },
        .compressor_suction = .{ .temperature_c = 10.0, .pressure_kpa = 500.0, .enthalpy_kj_kg = 250.0, .quality = 1.05 }, // Superheated vapor
        .compressor_discharge = .{ .temperature_c = 80.0, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 300.0, .quality = 1.5 },
        .condenser = .{ .temperature_c = 40.0, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 150.0, .quality = 0.5 },
        .expansion_valve = .{ .temperature_c = 40.0, .pressure_kpa = 1500.0, .enthalpy_kj_kg = 100.0, .quality = -0.1 }, // Subcooled liquid
    };
    
    // This comptime evaluation acts as our static guarantee against surge and slugging.
    comptime safe_cycle.verifyShaoYong(2000.0);
    
    try testing.expectEqual(true, true);
}
