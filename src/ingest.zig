const std = @import("std");
const cobs = @import("cobs");
const core = @import("carrier_core.zig");

/// InteliSense/Lynx Ingest Stream Handler
pub const IngestStream = struct {
    allocator: std.mem.Allocator,

    pub fn processPacket(self: *const IngestStream, raw_data: []const u8) !core.PhysicalState {
        var buffer: [256]u8 = undefined;
        const dec_len = try cobs.decode(raw_data, &buffer);
        
        // In a real implementation, we would parse the bit-accurate binary 
        // format of the Carrier sensor stream here.
        // For now, we mock the transition from a COBS stream to a Sovereign PhysicalState.
        _ = self;
        _ = dec_len;

        return core.PhysicalState{
            .ambient_temp_c = 25.0,
            .target_temp_c = 2.0,
            .compressor_rpm = 1800,
            .refrigerant_pressure_psi = 165.0,
            .energy_input_watts = 3500.0,
            .enthalpy_h = 390.0,
            .entropy_s = 1.48,
            .config = core.CarrierConfig.default,
        };
    }
};

test "Ingest COBS Pipeline" {
    const allocator = std.testing.allocator;
    const stream = IngestStream{ .allocator = allocator };

    // Mock encoded packet from Lynx Fleet — the COBS-encoded data only.
    // The trailing 0x00 frame delimiter is stripped before calling decode.
    const mock_packet = [_]u8{ 0x05, 0x01, 0x02, 0x03, 0x04 };

    const state = try stream.processPacket(&mock_packet);
    try std.testing.expect(state.compressor_rpm == 1800);
}
