const std = @import("std");
const cobs = @import("cobs");
const core = @import("carrier_core.zig");

// Real packet structure we expect from the Carrier sensor stream
pub const SensorPacket = packed struct {
    ambient_temp_c: f32,
    target_temp_c: f32,
    compressor_rpm: u32,
    refrigerant_pressure_psi: f32,
    energy_input_watts: f32,
    
    // Cycle enthalpies
    h1_evap_exit: f32, 
    h2_comp_exit: f32,
    h3_cond_exit: f32,
    h4_evap_inlet: f32,
    
    entropy_s: f32,
};

/// InteliSense/Lynx Ingest Stream Handler
pub const IngestStream = struct {
    allocator: std.mem.Allocator,

    pub fn processPacket(self: *const IngestStream, raw_data: []const u8) !core.PhysicalState {
        var buffer: [256]u8 = undefined;
        const dec_len = try cobs.decode(raw_data, &buffer);
        
        if (dec_len != @sizeOf(SensorPacket)) {
            return error.InvalidPacketSize;
        }

        // Physically interpret the bit-accurate binary format
        var packet: SensorPacket = undefined;
        @memcpy(std.mem.asBytes(&packet), buffer[0..@sizeOf(SensorPacket)]);

        return core.PhysicalState{
            .ambient_temp_c = packet.ambient_temp_c,
            .target_temp_c = packet.target_temp_c,
            .compressor_rpm = packet.compressor_rpm,
            .refrigerant_pressure_psi = packet.refrigerant_pressure_psi,
            .energy_input_watts = packet.energy_input_watts,
            .h1_evap_exit = packet.h1_evap_exit,
            .h2_comp_exit = packet.h2_comp_exit,
            .h3_cond_exit = packet.h3_cond_exit,
            .h4_evap_inlet = packet.h4_evap_inlet,
            .entropy_s = packet.entropy_s,
            .config = core.CarrierConfig.default,
        };
    }
};

test "Ingest COBS Pipeline" {
    const allocator = std.testing.allocator;
    const stream = IngestStream{ .allocator = allocator };

    // Create a real payload
    var packet = SensorPacket{
        .ambient_temp_c = 25.0,
        .target_temp_c = 2.0,
        .compressor_rpm = 1800,
        .refrigerant_pressure_psi = 165.0,
        .energy_input_watts = 3500.0,
        .h1_evap_exit = 400.0,
        .h2_comp_exit = 450.0,
        .h3_cond_exit = 200.0,
        .h4_evap_inlet = 200.0,
        .entropy_s = 1.48,
    };
    const packet_bytes = std.mem.asBytes(&packet);
    
    var enc_buffer: [256]u8 = undefined;
    const enc_len = try cobs.encode(packet_bytes, &enc_buffer);

    const state = try stream.processPacket(enc_buffer[0..enc_len]);
    try std.testing.expect(state.compressor_rpm == 1800);
}

