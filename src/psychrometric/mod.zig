// Psychrometric primitives for moist air at standard atmospheric pressure.
//
// REFERENCE: ASHRAE Handbook — Fundamentals (2021), Chapter 1 "Psychrometrics".
// All equation numbers below refer to ASHRAE 2021 Ch.1 unless noted.
//
// SI units throughout. Temperatures in degrees Celsius (converted to Kelvin
// internally where the source equation requires absolute temperature). Pressures
// in kPa. Humidity ratio W in kg water / kg dry air. Specific enthalpy h in
// kJ / kg dry air.

const std = @import("std");
const math = std.math;

pub const standard_pressure_kpa: f64 = 101.325;

pub const PsychroError = error{
    OutOfRange,
    InvalidInput,
};

// --- Saturation pressure of water vapor (Hyland-Wexler / ASHRAE 2021 eq 6 over water).
//
// ASHRAE 2021 Ch.1 eq (6) gives ln(p_ws) over liquid water for 0 °C <= t <= 200 °C.
// Returns saturation pressure in kPa.
//
// WHY non-obvious: the equation is in Kelvin and returns Pa; we convert to kPa.
// Coefficients are the published ASHRAE 2021 values (eq 6).
pub fn saturationPressureWaterKPa(t_celsius: f64) f64 {
    const T = t_celsius + 273.15;
    // Eq (6): liquid water, 0 < t < 200 C
    const c8: f64 = -5.8002206e3;
    const c9: f64 = 1.3914993;
    const c10: f64 = -4.8640239e-2;
    const c11: f64 = 4.1764768e-5;
    const c12: f64 = -1.4452093e-8;
    const c13: f64 = 6.5459673;
    const ln_p_ws = c8 / T + c9 + c10 * T + c11 * T * T + c12 * T * T * T + c13 * @log(T);
    return @exp(ln_p_ws) / 1000.0;
}

// --- Eq (20): humidity ratio from partial pressure of water vapor and total pressure.
//
// W = 0.621945 * p_w / (p - p_w)
// 0.621945 = M_water / M_dry_air per ASHRAE 2021 eq (20).
pub fn humidityRatioFromPartialPressure(p_w_kpa: f64, p_total_kpa: f64) f64 {
    return 0.621945 * p_w_kpa / (p_total_kpa - p_w_kpa);
}

// Inverse of eq (20): partial pressure of water from humidity ratio.
pub fn partialPressureFromHumidityRatio(w: f64, p_total_kpa: f64) f64 {
    return p_total_kpa * w / (0.621945 + w);
}

// --- Eq (32): specific enthalpy of moist air.
//
// h = 1.006 * t + W * (2501 + 1.86 * t)   [kJ / kg dry air]
//
// WHY non-obvious: ASHRAE eq (32) uses 1.006 kJ/(kg·K) for dry air heat capacity
// and 2501 kJ/kg for water vapor enthalpy at 0 °C reference, with 1.86 kJ/(kg·K)
// for water vapor heat capacity. The result is referenced to 0 °C dry air and
// 0 °C liquid water (standard ASHRAE reference state).
pub fn enthalpy(t_db_celsius: f64, humidity_ratio_w: f64) f64 {
    return 1.006 * t_db_celsius + humidity_ratio_w * (2501.0 + 1.86 * t_db_celsius);
}

// --- Eq (35) / (36): humidity ratio from dry-bulb and wet-bulb temperatures.
//
// At the wet-bulb temperature, the air is saturated; W_s* = humidityRatioFromPartialPressure(p_ws(t_wb), p).
// Then ASHRAE 2021 eq (35) for t_wb >= 0 °C:
//
//   W = ((2501 - 2.326*t_wb)*W_s* - 1.006*(t_db - t_wb))
//       / (2501 + 1.86*t_db - 4.186*t_wb)
//
// This is the adiabatic-saturation form. Requires t_db >= t_wb.
//
// WHY non-obvious: the denominator 4.186 is the specific heat of liquid water
// (kJ/(kg·K)); the numerator coefficient 2.326 is the specific heat of water
// vapor at the wet-bulb reference state. These are the exact ASHRAE eq (35)
// coefficients, not a simplification.
pub fn humidityRatioFromWetBulb(
    t_db_celsius: f64,
    t_wb_celsius: f64,
    p_total_kpa: f64,
) PsychroError!f64 {
    if (t_wb_celsius > t_db_celsius) return PsychroError.InvalidInput;
    if (t_wb_celsius < 0.0) return PsychroError.OutOfRange; // eq (35) form; eq (37) handles t_wb < 0
    const p_ws_wb = saturationPressureWaterKPa(t_wb_celsius);
    const w_s_star = humidityRatioFromPartialPressure(p_ws_wb, p_total_kpa);
    const numerator = (2501.0 - 2.326 * t_wb_celsius) * w_s_star - 1.006 * (t_db_celsius - t_wb_celsius);
    const denominator = 2501.0 + 1.86 * t_db_celsius - 4.186 * t_wb_celsius;
    return numerator / denominator;
}

// --- Eq (39): dewpoint temperature from dry-bulb and relative humidity.
//
// The dewpoint is the temperature at which p_w = p_ws(t_d). We compute
// p_w = rh * p_ws(t_db) and invert p_ws by Newton iteration on the
// ASHRAE eq (6) form, since eq (6) is monotonic over 0–200 °C.
//
// WHY non-obvious: ASHRAE 2021 also publishes an explicit polynomial fit
// (eq 39 and 40), but those forms are restricted to specific ranges and
// introduce ~0.05 °C bias. We use direct inversion of eq (6) for
// equation-consistent precision.
pub fn dewpoint(t_db_celsius: f64, relative_humidity: f64) f64 {
    const p_w = relative_humidity * saturationPressureWaterKPa(t_db_celsius);
    // Newton iteration; initial guess from ASHRAE 2021 eq (39) for moderate range.
    var t_d: f64 = t_db_celsius - 5.0;
    var iter: u32 = 0;
    while (iter < 50) : (iter += 1) {
        const f = saturationPressureWaterKPa(t_d) - p_w;
        // dp/dT at t_d via central difference.
        const dt: f64 = 0.01;
        const dfdt = (saturationPressureWaterKPa(t_d + dt) - saturationPressureWaterKPa(t_d - dt)) / (2.0 * dt);
        if (@abs(dfdt) < 1e-12) break;
        const step = f / dfdt;
        t_d -= step;
        if (@abs(step) < 1e-6) break;
    }
    return t_d;
}
