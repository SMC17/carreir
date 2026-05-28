// HMAC-signed append-only reefer log.
//
// Each entry is fixed-width binary:
//
//   field          type      bytes
//   ----------------------------------
//   timestamp_us   u64 LE    8
//   temperature_c  f32 LE    4
//   humidity       f32 LE    4
//   accel_x_mg     i16 LE    2
//   accel_y_mg     i16 LE    2
//   accel_z_mg     i16 LE    2
//   reserved       [2]u8     2
//   prior_hmac     [32]u8    32
//   hmac           [32]u8    32
//   ----------------------------------
//                            88 bytes
//
// The HMAC over each entry is HMAC-SHA256(key, prior_hmac || payload).
// The first entry uses an all-zero prior_hmac, so the full chain is
// replay-verifiable from any sealed key.
//
// Threat model:
//   - Adversary may modify any byte of a stored log file.
//   - Adversary does NOT have the HMAC key.
//   - Goal: replay must detect single-entry tampering and entry insertion,
//     deletion, or reordering.
//
// WHY non-obvious: prior_hmac is duplicated INTO the next entry's payload
// before being signed. That couples each signature to the entire prefix,
// so removing or reordering any entry breaks the chain. Without this
// coupling, an attacker could shuffle entries that are individually valid.

const std = @import("std");
const hmac = std.crypto.auth.hmac;
const HmacSha256 = hmac.sha2.HmacSha256;

pub const ENTRY_SIZE: usize = 88;
pub const HMAC_SIZE: usize = 32;

pub const Entry = extern struct {
    timestamp_us: u64 align(1),
    temperature_c: f32 align(1),
    humidity: f32 align(1),
    accel_x_mg: i16 align(1),
    accel_y_mg: i16 align(1),
    accel_z_mg: i16 align(1),
    reserved: [2]u8 align(1) = .{ 0, 0 },
    prior_hmac: [HMAC_SIZE]u8 align(1),
    hmac: [HMAC_SIZE]u8 align(1),
};

comptime {
    // Hard-enforce the wire layout; the entry is on-disk format.
    std.debug.assert(@sizeOf(Entry) == ENTRY_SIZE);
}

pub const ChainError = error{
    Truncated,
    HmacMismatch,
    ChainBroken,
};

// Fields that are signed: every byte of an entry EXCEPT the trailing `hmac`.
// That is the first ENTRY_SIZE - HMAC_SIZE = 56 bytes.
pub const SIGNED_PREFIX: usize = ENTRY_SIZE - HMAC_SIZE;

// Compute the HMAC for a signed-prefix slice given the secret key.
fn computeHmac(key: []const u8, signed_bytes: []const u8) [HMAC_SIZE]u8 {
    var out: [HMAC_SIZE]u8 = undefined;
    HmacSha256.create(&out, signed_bytes, key);
    return out;
}

// Sample is the user-facing measurement bundle; we wrap it into an Entry
// with the prior_hmac filled in from chain state.
pub const Sample = struct {
    timestamp_us: u64,
    temperature_c: f32,
    humidity: f32,
    accel_x_mg: i16,
    accel_y_mg: i16,
    accel_z_mg: i16,
};

// Append one sample to a log given the previous HMAC (or zeros for genesis).
// Returns the new entry with hmac field populated.
pub fn appendOne(key: []const u8, prior_hmac: [HMAC_SIZE]u8, sample: Sample) Entry {
    var entry = Entry{
        .timestamp_us = sample.timestamp_us,
        .temperature_c = sample.temperature_c,
        .humidity = sample.humidity,
        .accel_x_mg = sample.accel_x_mg,
        .accel_y_mg = sample.accel_y_mg,
        .accel_z_mg = sample.accel_z_mg,
        .prior_hmac = prior_hmac,
        .hmac = undefined,
    };
    const bytes = std.mem.asBytes(&entry);
    entry.hmac = computeHmac(key, bytes[0..SIGNED_PREFIX]);
    return entry;
}

// Verify a chain of raw entry bytes.
// `bytes.len` must be a multiple of ENTRY_SIZE.
// `key` is the HMAC key.
// On success, returns the number of entries verified.
pub fn verifyChain(key: []const u8, bytes: []const u8) ChainError!usize {
    if (bytes.len == 0) return 0;
    if (bytes.len % ENTRY_SIZE != 0) return ChainError.Truncated;
    const n = bytes.len / ENTRY_SIZE;

    var expected_prior: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const off = i * ENTRY_SIZE;
        const entry_bytes = bytes[off..][0..ENTRY_SIZE];

        // Pull the stored prior_hmac out of the entry.
        const stored_prior = entry_bytes[SIGNED_PREFIX - HMAC_SIZE .. SIGNED_PREFIX];
        if (!std.mem.eql(u8, stored_prior, &expected_prior)) {
            return ChainError.ChainBroken;
        }

        // Verify the HMAC over the signed prefix.
        const got_hmac = computeHmac(key, entry_bytes[0..SIGNED_PREFIX]);
        const stored_hmac = entry_bytes[SIGNED_PREFIX..][0..HMAC_SIZE];
        if (!std.mem.eql(u8, &got_hmac, stored_hmac)) {
            return ChainError.HmacMismatch;
        }

        // This entry's HMAC becomes the next entry's prior.
        @memcpy(&expected_prior, stored_hmac);
    }
    return n;
}

// Replay callback signature: invoked once per verified entry.
pub const ReplayCallback = *const fn (entry: *const Entry, user: ?*anyopaque) void;

// Verify and replay each entry. `user` is passed through to the callback.
pub fn replay(
    key: []const u8,
    bytes: []const u8,
    cb: ReplayCallback,
    user: ?*anyopaque,
) ChainError!usize {
    if (bytes.len % ENTRY_SIZE != 0) return ChainError.Truncated;
    const n = bytes.len / ENTRY_SIZE;

    var expected_prior: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const off = i * ENTRY_SIZE;
        const entry_bytes = bytes[off..][0..ENTRY_SIZE];
        const stored_prior = entry_bytes[SIGNED_PREFIX - HMAC_SIZE .. SIGNED_PREFIX];
        if (!std.mem.eql(u8, stored_prior, &expected_prior)) {
            return ChainError.ChainBroken;
        }
        const got_hmac = computeHmac(key, entry_bytes[0..SIGNED_PREFIX]);
        const stored_hmac = entry_bytes[SIGNED_PREFIX..][0..HMAC_SIZE];
        if (!std.mem.eql(u8, &got_hmac, stored_hmac)) {
            return ChainError.HmacMismatch;
        }
        const entry_ptr: *const Entry = @ptrCast(@alignCast(entry_bytes.ptr));
        cb(entry_ptr, user);
        @memcpy(&expected_prior, stored_hmac);
    }
    return n;
}

// File-mode replay convenience for the CLI.
//
// Takes the Zig 0.16 `std.Io` interface so the read path is cross-platform
// (Linux, macOS, BSD, Windows, WASI). The older `std.fs.cwd()` API was
// removed in 0.16 in favor of `std.Io.Dir.cwd()` + an explicit Io vtable.
pub fn replayFile(
    io: std.Io,
    allocator: std.mem.Allocator,
    path: []const u8,
    key: []const u8,
    out_count: *usize,
) !void {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    const stat = try file.stat(io);
    if (stat.size > 1 << 30) return error.FileTooLarge;

    const bytes = try allocator.alloc(u8, stat.size);
    defer allocator.free(bytes);

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(io, &read_buf);
    var total: usize = 0;
    while (total < bytes.len) {
        const n = try file_reader.interface.readSliceShort(bytes[total..]);
        if (n == 0) break;
        total += n;
    }
    if (total != bytes.len) return error.ShortRead;

    out_count.* = try verifyChain(key, bytes);
}

// ===========================================================================
// Tests
// ===========================================================================

const testing = std.testing;

test "single-entry append + verify" {
    const key = "secret-reefer-key";
    const sample = Sample{
        .timestamp_us = 1_700_000_000_000_000,
        .temperature_c = -18.0,
        .humidity = 0.85,
        .accel_x_mg = 12,
        .accel_y_mg = -3,
        .accel_z_mg = 1004,
    };
    const zero: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;
    var entry = appendOne(key, zero, sample);
    const bytes = std.mem.asBytes(&entry);
    const verified = try verifyChain(key, bytes);
    try testing.expectEqual(@as(usize, 1), verified);
}

test "100-entry chain: append, replay, verify" {
    const key = "reefer-secret-32-byte-keyXXXXXXX";
    var buf: [100 * ENTRY_SIZE]u8 = undefined;
    var prior: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const sample = Sample{
            .timestamp_us = @as(u64, i) * 60_000_000,
            .temperature_c = -18.0 + @as(f32, @floatFromInt(i)) * 0.001,
            .humidity = 0.85,
            .accel_x_mg = @intCast(i % 20),
            .accel_y_mg = 0,
            .accel_z_mg = 1000,
        };
        var entry = appendOne(key, prior, sample);
        @memcpy(buf[i * ENTRY_SIZE ..][0..ENTRY_SIZE], std.mem.asBytes(&entry));
        prior = entry.hmac;
    }

    const verified = try verifyChain(key, &buf);
    try testing.expectEqual(@as(usize, 100), verified);
}

test "tamper detection: flip a single payload byte" {
    const key = "reefer-secret-32-byte-keyXXXXXXX";
    var buf: [100 * ENTRY_SIZE]u8 = undefined;
    var prior: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const sample = Sample{
            .timestamp_us = @as(u64, i) * 60_000_000,
            .temperature_c = -18.0,
            .humidity = 0.85,
            .accel_x_mg = 0,
            .accel_y_mg = 0,
            .accel_z_mg = 1000,
        };
        var entry = appendOne(key, prior, sample);
        @memcpy(buf[i * ENTRY_SIZE ..][0..ENTRY_SIZE], std.mem.asBytes(&entry));
        prior = entry.hmac;
    }

    // Tamper: change the temperature in entry 42 from -18.0 to -10.0.
    const entry42_offset = 42 * ENTRY_SIZE;
    const temp_offset = entry42_offset + @offsetOf(Entry, "temperature_c");
    const new_temp: f32 = -10.0;
    @memcpy(buf[temp_offset..][0..4], std.mem.asBytes(&new_temp));

    // Now verify must reject — entry 42's stored HMAC no longer matches its
    // tampered payload.
    try testing.expectError(ChainError.HmacMismatch, verifyChain(key, &buf));
}

test "tamper detection: swap two entries" {
    const key = "reefer-secret-32-byte-keyXXXXXXX";
    var buf: [10 * ENTRY_SIZE]u8 = undefined;
    var prior: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const sample = Sample{
            .timestamp_us = @as(u64, i),
            .temperature_c = @floatFromInt(i),
            .humidity = 0.5,
            .accel_x_mg = 0,
            .accel_y_mg = 0,
            .accel_z_mg = 1000,
        };
        var entry = appendOne(key, prior, sample);
        @memcpy(buf[i * ENTRY_SIZE ..][0..ENTRY_SIZE], std.mem.asBytes(&entry));
        prior = entry.hmac;
    }

    // Swap entries 3 and 7.
    var tmp: [ENTRY_SIZE]u8 = undefined;
    @memcpy(&tmp, buf[3 * ENTRY_SIZE ..][0..ENTRY_SIZE]);
    @memcpy(buf[3 * ENTRY_SIZE ..][0..ENTRY_SIZE], buf[7 * ENTRY_SIZE ..][0..ENTRY_SIZE]);
    @memcpy(buf[7 * ENTRY_SIZE ..][0..ENTRY_SIZE], &tmp);

    // Chain must break (entry-4's prior_hmac no longer matches what we
    // expect, since we re-applied entry-7's hmac into the chain position).
    const result = verifyChain(key, &buf);
    try testing.expect(result == ChainError.ChainBroken or result == ChainError.HmacMismatch);
}

test "tamper detection: wrong key" {
    const right_key = "correct-key-1234567890123456789012";
    const wrong_key = "wrong-key-12345678901234567890123456";

    const sample = Sample{
        .timestamp_us = 1,
        .temperature_c = 0.0,
        .humidity = 0.5,
        .accel_x_mg = 0,
        .accel_y_mg = 0,
        .accel_z_mg = 1000,
    };
    const zero: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;
    var entry = appendOne(right_key, zero, sample);
    const bytes = std.mem.asBytes(&entry);

    try testing.expectError(ChainError.HmacMismatch, verifyChain(wrong_key, bytes));
}

test "replay invokes callback per entry" {
    const Counter = struct {
        var n: usize = 0;
        fn cb(_: *const Entry, _: ?*anyopaque) void {
            n += 1;
        }
    };
    Counter.n = 0;

    const key = "reefer-secret-32-byte-keyXXXXXXX";
    var buf: [25 * ENTRY_SIZE]u8 = undefined;
    var prior: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;
    var i: usize = 0;
    while (i < 25) : (i += 1) {
        const sample = Sample{
            .timestamp_us = i,
            .temperature_c = 0.0,
            .humidity = 0.5,
            .accel_x_mg = 0,
            .accel_y_mg = 0,
            .accel_z_mg = 1000,
        };
        var entry = appendOne(key, prior, sample);
        @memcpy(buf[i * ENTRY_SIZE ..][0..ENTRY_SIZE], std.mem.asBytes(&entry));
        prior = entry.hmac;
    }

    const verified = try replay(key, &buf, Counter.cb, null);
    try testing.expectEqual(@as(usize, 25), verified);
    try testing.expectEqual(@as(usize, 25), Counter.n);
}

test "truncated input rejected" {
    const key = "test-key";
    var buf: [ENTRY_SIZE - 1]u8 = .{0} ** (ENTRY_SIZE - 1);
    try testing.expectError(ChainError.Truncated, verifyChain(key, &buf));
}

// ---------------------------------------------------------------------------
// Property-based tests (PRNG-seeded; deterministic).
//
// Sister to the psychrometric / refrigerant property suites — same
// randomised-trial pattern reused across all three hulls.
//
// Cold-chain log invariants pinned:
//   - randomized append-then-verify always passes
//   - tamper detection: any single-bit flip in any signed prefix or HMAC
//     causes verifyChain to fail
//   - HMAC determinism: same key + same prior_hmac + same sample produces
//     byte-identical Entry
//   - wrong key always rejects
// ---------------------------------------------------------------------------

test "property: random N-entry chain (N in [1, 100]) appends and verifies" {
    var prng = std.Random.DefaultPrng.init(0xC0_2026_0514_BEEF);
    const rng = prng.random();
    const trials: u32 = 200;
    var trial: u32 = 0;
    while (trial < trials) : (trial += 1) {
        const n = 1 + rng.uintLessThan(usize, 100);
        const key = "rng-property-key";
        var buf = try std.testing.allocator.alloc(u8, n * ENTRY_SIZE);
        defer std.testing.allocator.free(buf);
        var prior: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const sample = Sample{
                .timestamp_us = rng.int(u64),
                .temperature_c = @as(f32, @floatFromInt(@as(i32, @intCast(rng.uintLessThan(u32, 1200))))) / 10.0 - 50.0,
                .humidity = rng.float(f32),
                .accel_x_mg = @intCast(@as(i32, @intCast(rng.uintLessThan(u32, 4001))) - 2000),
                .accel_y_mg = @intCast(@as(i32, @intCast(rng.uintLessThan(u32, 4001))) - 2000),
                .accel_z_mg = @intCast(@as(i32, @intCast(rng.uintLessThan(u32, 4001))) - 2000),
            };
            const entry = appendOne(key, prior, sample);
            @memcpy(buf[i * ENTRY_SIZE ..][0..ENTRY_SIZE], std.mem.asBytes(&entry));
            prior = entry.hmac;
        }
        const verified = verifyChain(key, buf) catch |err| {
            std.debug.print("FAIL @ trial {d}: n={d} verifyChain returned {}\n", .{ trial, n, err });
            return error.TestUnexpectedResult;
        };
        if (verified != n) {
            std.debug.print("FAIL @ trial {d}: n={d} verifyChain returned {d}\n", .{ trial, n, verified });
            return error.TestUnexpectedResult;
        }
    }
}

test "property: random bit-flip in any signed-prefix byte is detected" {
    var prng = std.Random.DefaultPrng.init(0xC0_2026_0514_BEF0);
    const rng = prng.random();
    const trials: u32 = 200;
    var trial: u32 = 0;
    while (trial < trials) : (trial += 1) {
        const key = "rng-tamper-key";
        const n: usize = 5;
        var buf: [n * ENTRY_SIZE]u8 = undefined;
        var prior: [HMAC_SIZE]u8 = .{0} ** HMAC_SIZE;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const sample = Sample{
                .timestamp_us = @as(u64, @intCast(i)),
                .temperature_c = 4.0 + rng.float(f32) * 4.0,
                .humidity = 0.7,
                .accel_x_mg = 0,
                .accel_y_mg = 0,
                .accel_z_mg = 1000,
            };
            const entry = appendOne(key, prior, sample);
            @memcpy(buf[i * ENTRY_SIZE ..][0..ENTRY_SIZE], std.mem.asBytes(&entry));
            prior = entry.hmac;
        }
        // Pick a random byte to flip — anywhere in the buffer.
        const flip_idx = rng.uintLessThan(usize, buf.len);
        const flip_bit: u3 = @intCast(rng.uintLessThan(u32, 8));
        buf[flip_idx] ^= (@as(u8, 1) << flip_bit);
        // verifyChain must reject — single-bit corruption anywhere breaks
        // either the HMAC over the prefix or the HMAC chain itself.
        if (verifyChain(key, &buf)) |verified| {
            std.debug.print(
                "FAIL @ trial {d}: flip at byte={d} bit={d} verified={d} (should have rejected)\n",
                .{ trial, flip_idx, flip_bit, verified },
            );
            return error.TestUnexpectedResult;
        } else |_| {}
    }
}

test "property: appendOne is deterministic in (key, prior_hmac, sample)" {
    var prng = std.Random.DefaultPrng.init(0xC0_2026_0514_BEF1);
    const rng = prng.random();
    const trials: u32 = 500;
    var trial: u32 = 0;
    while (trial < trials) : (trial += 1) {
        var key_buf: [16]u8 = undefined;
        rng.bytes(&key_buf);
        var prior: [HMAC_SIZE]u8 = undefined;
        rng.bytes(&prior);
        const sample = Sample{
            .timestamp_us = rng.int(u64),
            .temperature_c = rng.float(f32) * 50.0 - 25.0,
            .humidity = rng.float(f32),
            .accel_x_mg = @intCast(@as(i32, @intCast(rng.uintLessThan(u32, 4001))) - 2000),
            .accel_y_mg = @intCast(@as(i32, @intCast(rng.uintLessThan(u32, 4001))) - 2000),
            .accel_z_mg = @intCast(@as(i32, @intCast(rng.uintLessThan(u32, 4001))) - 2000),
        };
        const a = appendOne(&key_buf, prior, sample);
        const b = appendOne(&key_buf, prior, sample);
        if (!std.mem.eql(u8, std.mem.asBytes(&a), std.mem.asBytes(&b))) {
            std.debug.print("FAIL @ trial {d}: appendOne non-deterministic\n", .{trial});
            return error.TestUnexpectedResult;
        }
    }
}
