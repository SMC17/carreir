// carreir CLI — three-hull substrate: psychrometric / refrigerant / coldchain.
//
// Usage:
//   carreir psychro <T_db_c> <T_wb_c>     — moist-air state at standard pressure
//   carreir refrigerant <name> T=<c>      — saturation pressure for T (Celsius)
//   carreir refrigerant <name> P=<kPa>    — saturation temperature for P (kPa)
//   carreir coldchain replay <path>       — verify HMAC chain on a .ccl log
//
// Each hull is independently importable; the CLI is a thin shell over the libraries.
//
// Zig 0.16 conventions:
//   `pub fn main` takes `std.process.Init` by value. CLI args come from
//   `init.minimal.args`; stdio comes from `init.io`. The arena allocator
//   owns args + scratch buffers for the lifetime of the process.

const std = @import("std");
const psychrometric = @import("psychrometric");
const refrigerant = @import("refrigerant");
const coldchain = @import("coldchain");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    var out_buf: [4096]u8 = undefined;
    var out_w = std.Io.File.stdout().writer(init.io, &out_buf);
    var err_buf: [1024]u8 = undefined;
    var err_w = std.Io.File.stderr().writer(init.io, &err_buf);
    const out = &out_w.interface;
    const err = &err_w.interface;
    defer out.flush() catch {};
    defer err.flush() catch {};

    if (args.len < 2) {
        try printUsage(out);
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "psychro")) {
        try runPsychro(out, err, args);
    } else if (std.mem.eql(u8, cmd, "refrigerant")) {
        try runRefrigerant(out, err, args);
    } else if (std.mem.eql(u8, cmd, "coldchain")) {
        try runColdchain(init.io, arena, out, err, args);
    } else if (std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
        try printUsage(out);
    } else {
        try printUsage(err);
        std.process.exit(2);
    }
}

fn printUsage(w: *std.Io.Writer) !void {
    try w.writeAll(
        \\carreir — three-hull HVAC / cold-chain substrate
        \\
        \\Commands:
        \\  psychro <T_db_c> <T_wb_c>
        \\      Compute moist-air state at standard pressure (101.325 kPa).
        \\      Prints humidity ratio, enthalpy, dewpoint.
        \\
        \\  refrigerant <name> T=<celsius>
        \\      Saturation pressure (kPa) for the given temperature.
        \\      Supported names: R-134a R-410A R-32 R-1234yf R-744
        \\
        \\  refrigerant <name> P=<kPa>
        \\      Saturation temperature (Celsius) for the given pressure.
        \\
        \\  coldchain replay <path>
        \\      Verify the HMAC chain on an append-only reefer log.
        \\
        \\Examples:
        \\  carreir psychro 30 20
        \\  carreir refrigerant R-410A T=5
        \\  carreir coldchain replay /tmp/reefer.ccl
        \\
    );
}

fn runPsychro(out: *std.Io.Writer, err: *std.Io.Writer, args: []const [:0]const u8) !void {
    if (args.len < 4) {
        try printUsage(err);
        std.process.exit(2);
    }
    const t_db = try std.fmt.parseFloat(f64, args[2]);
    const t_wb = try std.fmt.parseFloat(f64, args[3]);

    const w = try psychrometric.humidityRatioFromWetBulb(t_db, t_wb, psychrometric.standard_pressure_kpa);
    const h = psychrometric.enthalpy(t_db, w);
    const p_w = psychrometric.partialPressureFromHumidityRatio(w, psychrometric.standard_pressure_kpa);
    const p_ws = psychrometric.saturationPressureWaterKPa(t_db);
    const rh = p_w / p_ws;
    const td = psychrometric.dewpoint(t_db, rh);

    try out.print(
        \\T_db    = {d:.3} C
        \\T_wb    = {d:.3} C
        \\W       = {d:.6} kg/kg dry air
        \\h       = {d:.3} kJ/kg dry air
        \\RH      = {d:.3} (fraction)
        \\T_dew   = {d:.3} C
        \\
    , .{ t_db, t_wb, w, h, rh, td });
}

fn runRefrigerant(out: *std.Io.Writer, err: *std.Io.Writer, args: []const [:0]const u8) !void {
    if (args.len < 4) {
        try printUsage(err);
        std.process.exit(2);
    }
    const name = args[2];
    const fluid = refrigerant.byName(name) orelse {
        try err.writeAll("unknown refrigerant: ");
        try err.writeAll(name);
        try err.writeAll("\nsupported: R-134a R-410A R-32 R-1234yf R-744\n");
        std.process.exit(2);
    };

    const spec = args[3];
    if (std.mem.startsWith(u8, spec, "T=")) {
        const t = try std.fmt.parseFloat(f64, spec[2..]);
        const p = try refrigerant.saturationPressureKPa(fluid, t);
        try out.print("{s} T={d:.3} C  =>  P_sat = {d:.3} kPa\n", .{ name, t, p });
    } else if (std.mem.startsWith(u8, spec, "P=")) {
        const p = try std.fmt.parseFloat(f64, spec[2..]);
        const t = try refrigerant.saturationTemperatureCelsius(fluid, p);
        try out.print("{s} P={d:.3} kPa  =>  T_sat = {d:.3} C\n", .{ name, p, t });
    } else {
        try printUsage(err);
        std.process.exit(2);
    }
}

fn runColdchain(io: std.Io, arena: std.mem.Allocator, out: *std.Io.Writer, err: *std.Io.Writer, args: []const [:0]const u8) !void {
    if (args.len < 4 or !std.mem.eql(u8, args[2], "replay")) {
        try printUsage(err);
        std.process.exit(2);
    }
    const path = args[3];

    // Demo key — real deployments load from secure storage. Zero key is fine
    // for verifying logs signed with zero key (e.g. the example produced by
    // examples/coldchain_log_sample.zig).
    const key = [_]u8{0} ** 32;

    var verified: usize = 0;
    coldchain.replayFile(io, arena, path, &key, &verified) catch |e| {
        try err.print("replay FAILED: {s}\n", .{@errorName(e)});
        std.process.exit(1);
    };

    try out.print("replay OK: {d} entries verified\n", .{verified});
}
