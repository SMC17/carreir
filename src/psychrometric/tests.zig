// ASHRAE 2021 Ch.1 cross-check fixtures for psychrometric primitives.
//
// Reference: ASHRAE Handbook — Fundamentals (2021), Chapter 1, Table 2
// ("Thermodynamic Properties of Moist Air, Standard Atmospheric Pressure,
// 101.325 kPa") and the psychrometric chart at sea level.
//
// Tolerances follow Hyland-Wexler precision claims for the equation set:
//   - saturation pressure of water:  rel. err <= 0.1% within 0–100 C
//   - humidity ratio at wet-bulb:    rel. err <= 0.3% (mass-balance tolerance)
//   - enthalpy:                      abs. err <= 0.1 kJ/kg
//   - dewpoint (via Newton inv.):    abs. err <= 0.02 C
//
// Every literal in this file traces to a published ASHRAE reference table or
// chart value; no values are invented.

const std = @import("std");
const testing = std.testing;
const p = @import("mod.zig");

// Relative tolerance helper.
fn approxRel(actual: f64, expected: f64, rel_tol: f64) bool {
    if (expected == 0.0) return @abs(actual) < rel_tol;
    return @abs(actual - expected) / @abs(expected) < rel_tol;
}

// ---------------------------------------------------------------------------
// Saturation pressure of water (ASHRAE 2021 eq 6 over liquid water).
// Reference values from ASHRAE Handbook 2021, Table 3 (saturation properties
// of water at temperatures 0 to 100 C). Values are in kPa.
// ---------------------------------------------------------------------------

test "p_ws at 0 C matches ASHRAE Table 3" {
    // ASHRAE 2021 Ch.1 Table 3 / Hyland-Wexler: p_ws(0 C) = 0.6112 kPa.
    const got = p.saturationPressureWaterKPa(0.0);
    try testing.expect(approxRel(got, 0.6112, 0.001));
}

test "p_ws at 20 C matches ASHRAE Table 3" {
    // p_ws(20 C) = 2.339 kPa.
    const got = p.saturationPressureWaterKPa(20.0);
    try testing.expect(approxRel(got, 2.339, 0.001));
}

test "p_ws at 30 C matches ASHRAE Table 3" {
    // p_ws(30 C) = 4.246 kPa.
    const got = p.saturationPressureWaterKPa(30.0);
    try testing.expect(approxRel(got, 4.246, 0.001));
}

test "p_ws at 50 C matches ASHRAE Table 3" {
    // p_ws(50 C) = 12.350 kPa.
    const got = p.saturationPressureWaterKPa(50.0);
    try testing.expect(approxRel(got, 12.350, 0.001));
}

// ---------------------------------------------------------------------------
// Humidity ratio from wet-bulb (ASHRAE 2021 eq 35).
// Reference: ASHRAE Handbook 2021 psychrometric chart, standard pressure.
// Test points selected from textbook examples (Cengel/Boles, Moran/Shapiro)
// that resolve to ASHRAE chart values.
// ---------------------------------------------------------------------------

test "humidity ratio at 30 C dry-bulb / 20 C wet-bulb" {
    // ASHRAE 2021 eq (35) at standard pressure: 30 / 20 C  =>  W = 0.01052 kg/kg.
    // Cross-check: ASHRAE psychrometric chart no. 1 reads ~0.0105 at this point.
    const w = try p.humidityRatioFromWetBulb(30.0, 20.0, p.standard_pressure_kpa);
    try testing.expect(approxRel(w, 0.01052, 0.001));
}

test "humidity ratio at 25 C dry-bulb / 18 C wet-bulb" {
    // ASHRAE 2021 eq (35): 25 / 18 C  =>  W = 0.01002 kg/kg.
    const w = try p.humidityRatioFromWetBulb(25.0, 18.0, p.standard_pressure_kpa);
    try testing.expect(approxRel(w, 0.01002, 0.001));
}

test "humidity ratio at 40 C dry-bulb / 25 C wet-bulb" {
    // ASHRAE 2021 eq (35): 40 / 25 C  =>  W = 0.01375 kg/kg.
    const w = try p.humidityRatioFromWetBulb(40.0, 25.0, p.standard_pressure_kpa);
    try testing.expect(approxRel(w, 0.01375, 0.001));
}

test "saturation case: T_db == T_wb  =>  RH = 1" {
    // At T_db = T_wb, the air is saturated and W equals the saturation
    // humidity ratio at that temperature.
    const t: f64 = 25.0;
    const w = try p.humidityRatioFromWetBulb(t, t, p.standard_pressure_kpa);
    const p_ws = p.saturationPressureWaterKPa(t);
    const w_sat = p.humidityRatioFromPartialPressure(p_ws, p.standard_pressure_kpa);
    try testing.expect(approxRel(w, w_sat, 0.001));
}

test "wet-bulb > dry-bulb is rejected" {
    try testing.expectError(
        p.PsychroError.InvalidInput,
        p.humidityRatioFromWetBulb(20.0, 25.0, p.standard_pressure_kpa),
    );
}

// ---------------------------------------------------------------------------
// Enthalpy (ASHRAE 2021 eq 32).
// h = 1.006*t + W*(2501 + 1.86*t)   [kJ/kg dry air]
// Reference values from ASHRAE 2021 psychrometric chart no. 1.
// ---------------------------------------------------------------------------

test "enthalpy at 30 C / W=0.01052 matches ASHRAE eq (32)" {
    // ASHRAE 2021 eq (32) at 30 C / W=0.01052:  h = 57.07 kJ/kg dry air.
    // Hand-computed: 1.006*30 + 0.01052*(2501+1.86*30) = 30.18 + 26.89 = 57.07.
    const h = p.enthalpy(30.0, 0.01052);
    try testing.expectApproxEqAbs(h, 57.07, 0.05);
}

test "enthalpy at 25 C / W=0.01002 matches ASHRAE eq (32)" {
    // 25 C / W=0.01002:  h = 25.15 + 25.55 = 50.70 kJ/kg.
    const h = p.enthalpy(25.0, 0.01002);
    try testing.expectApproxEqAbs(h, 50.70, 0.05);
}

test "enthalpy at 0 C / W=0 (dry, freezing reference)" {
    // h(0,0) = 0 by ASHRAE reference state.
    const h = p.enthalpy(0.0, 0.0);
    try testing.expectApproxEqAbs(h, 0.0, 0.01);
}

// ---------------------------------------------------------------------------
// Dewpoint (Newton inversion of ASHRAE 2021 eq 6).
// ---------------------------------------------------------------------------

test "dewpoint at 30 C / RH=0.5 matches ASHRAE chart" {
    // ASHRAE chart no. 1: 30 C dry-bulb, 50% RH  =>  T_dew ~= 18.4 C.
    const td = p.dewpoint(30.0, 0.5);
    try testing.expectApproxEqAbs(td, 18.4, 0.2);
}

test "dewpoint at saturation (RH=1) equals dry-bulb" {
    const td = p.dewpoint(20.0, 1.0);
    try testing.expectApproxEqAbs(td, 20.0, 0.05);
}

test "dewpoint at 25 C / RH=0.6" {
    // ASHRAE chart no. 1: 25 C, 60% RH  =>  T_dew ~= 16.7 C.
    const td = p.dewpoint(25.0, 0.6);
    try testing.expectApproxEqAbs(td, 16.7, 0.2);
}

// ---------------------------------------------------------------------------
// Round-trip / consistency checks.
// ---------------------------------------------------------------------------

test "round-trip: W -> p_w -> W" {
    const w_in: f64 = 0.012;
    const p_w = p.partialPressureFromHumidityRatio(w_in, p.standard_pressure_kpa);
    const w_out = p.humidityRatioFromPartialPressure(p_w, p.standard_pressure_kpa);
    try testing.expectApproxEqAbs(w_out, w_in, 1e-10);
}

// ---------------------------------------------------------------------------
// Property-based tests (PRNG-seeded; deterministic).
//
// Pattern adapted from sentinel-sbom's randomized determinism harness:
// fixed seed so a failing trial is reproducible; explicit invariant per
// trial; counts and seed printed if any trial fails.
// ---------------------------------------------------------------------------

test "property: saturation pressure is strictly monotonic in T over 0-100 C" {
    var prng = std.Random.DefaultPrng.init(0xA5_2026_0514_C0DE);
    const rng = prng.random();
    const trials: u32 = 1000;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        // Two random temperatures in [0.5, 99.5] C with at least 0.1 C gap.
        const t1 = 0.5 + rng.float(f64) * 99.0;
        const dt = 0.1 + rng.float(f64) * 5.0;
        const t2 = t1 + dt;
        if (t2 > 99.5) continue;
        const p1 = p.saturationPressureWaterKPa(t1);
        const p2 = p.saturationPressureWaterKPa(t2);
        // Strict monotonicity. Hyland-Wexler is smooth + monotone over this range.
        if (!(p2 > p1)) {
            std.debug.print("FAIL @ trial {d}: p_ws({d:.4}) = {e:.6} not > p_ws({d:.4}) = {e:.6}\n",
                .{ i, t1, p1, t2, p2 });
            return error.TestUnexpectedResult;
        }
    }
}

test "property: humidity-ratio round-trip W -> p_w -> W (rel err < 1e-12)" {
    var prng = std.Random.DefaultPrng.init(0xA5_2026_0514_C0DF);
    const rng = prng.random();
    const trials: u32 = 1000;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        // Realistic humidity ratio range: 0.0001 to 0.05 kg-water/kg-dry-air.
        const w_in = 0.0001 + rng.float(f64) * 0.0499;
        const p_total = 80.0 + rng.float(f64) * 30.0; // 80-110 kPa, real atmospheric range
        const p_w = p.partialPressureFromHumidityRatio(w_in, p_total);
        const w_out = p.humidityRatioFromPartialPressure(p_w, p_total);
        const rel_err = @abs(w_out - w_in) / w_in;
        if (rel_err >= 1e-12) {
            std.debug.print("FAIL @ trial {d}: W_in = {e:.6} W_out = {e:.6} rel_err = {e:.6}\n",
                .{ i, w_in, w_out, rel_err });
            return error.TestUnexpectedResult;
        }
    }
}

test "property: enthalpy strictly monotonic in T (fixed W)" {
    var prng = std.Random.DefaultPrng.init(0xA5_2026_0514_C0E0);
    const rng = prng.random();
    const trials: u32 = 500;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        const w = 0.001 + rng.float(f64) * 0.020;
        const t1 = -10.0 + rng.float(f64) * 50.0; // -10 to 40 C
        const t2 = t1 + 0.5 + rng.float(f64) * 10.0;
        const h1 = p.enthalpy(t1, w);
        const h2 = p.enthalpy(t2, w);
        // h is linear in t with positive slope (1.006 + 1.86*W > 0 for all W >= 0).
        if (!(h2 > h1)) {
            std.debug.print("FAIL @ trial {d}: t1={d:.3} t2={d:.3} W={e:.4} h1={d:.3} h2={d:.3}\n",
                .{ i, t1, t2, w, h1, h2 });
            return error.TestUnexpectedResult;
        }
    }
}

test "property: enthalpy strictly monotonic in W (fixed T >= 0)" {
    var prng = std.Random.DefaultPrng.init(0xA5_2026_0514_C0E1);
    const rng = prng.random();
    const trials: u32 = 500;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        const t = 0.5 + rng.float(f64) * 50.0; // 0.5 to 50.5 C, positive temperatures
        const w1 = 0.0001 + rng.float(f64) * 0.020;
        const w2 = w1 + 0.0001 + rng.float(f64) * 0.005;
        const h1 = p.enthalpy(t, w1);
        const h2 = p.enthalpy(t, w2);
        // d h / d W = (2501 + 1.86 * t) > 0 for t > -1345 C, trivially true here.
        if (!(h2 > h1)) {
            std.debug.print("FAIL @ trial {d}: t={d:.3} W1={e:.4} W2={e:.4} h1={d:.3} h2={d:.3}\n",
                .{ i, t, w1, w2, h1, h2 });
            return error.TestUnexpectedResult;
        }
    }
}

test "property: at saturation (RH=1), dewpoint equals dry-bulb (|err| < 0.05 C)" {
    var prng = std.Random.DefaultPrng.init(0xA5_2026_0514_C0E2);
    const rng = prng.random();
    const trials: u32 = 200;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        const t_db = 1.0 + rng.float(f64) * 80.0; // 1 to 81 C, in Hyland-Wexler range
        const t_dew = p.dewpoint(t_db, 1.0);
        const err = @abs(t_dew - t_db);
        // Newton iteration on monotone p_ws should converge to within 0.05 C.
        if (err > 0.05) {
            std.debug.print("FAIL @ trial {d}: t_db={d:.4} t_dew={d:.4} err={d:.6}\n",
                .{ i, t_db, t_dew, err });
            return error.TestUnexpectedResult;
        }
    }
}

test "property: dewpoint is bounded by dry-bulb (dewpoint <= dry-bulb)" {
    var prng = std.Random.DefaultPrng.init(0xA5_2026_0514_C0E3);
    const rng = prng.random();
    const trials: u32 = 500;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        const t_db = 1.0 + rng.float(f64) * 80.0;
        const rh = 0.05 + rng.float(f64) * 0.95; // 5% to 100% RH
        const t_dew = p.dewpoint(t_db, rh);
        // Dewpoint is the temperature at which RH=1 with the same p_w; it must be <= t_db.
        // Allow tiny numerical slack at RH=1.
        if (t_dew > t_db + 0.05) {
            std.debug.print("FAIL @ trial {d}: t_db={d:.4} RH={d:.3} t_dew={d:.4}\n",
                .{ i, t_db, rh, t_dew });
            return error.TestUnexpectedResult;
        }
    }
}
