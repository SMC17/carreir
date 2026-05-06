const std = @import("std");
const cobs = @import("cobs.zig");
const core = @import("carrier_core.zig");

/// InteliSense/Lynx Ingest Stream Handler
pub const IngestStream = struct {
    allocator: std.mem.Allocator,

    pub fn processPacket(self: *const IngestStream, raw_data: []const u8) !core.PhysicalState {
        var buffer: [256]u8 = undefined;
        const dec_len = try cobs.Cobs.decode(raw_data, &buffer);
        
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
        };
    }
};

test "Ingest COBS Pipeline" {
    const allocator = std.testing.allocator;
    const stream = IngestStream{ .allocator = allocator };
    
    // Mock encoded packet from Lynx Fleet
    const mock_packet = [_]u8{ 0x05, 0x01, 0x02, 0x03, 0x04, 0x00 }; 
    
    const state = try stream.processPacket(&mock_packet);
    try std.testing.expect(state.compressor_rpm == 1800);
}
