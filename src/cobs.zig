const std = @import("std");

/// Consistent Overhead Byte Stuffing (COBS)
/// Used for framing sensor data over unreliable streams (InteliSense/Lynx).
pub const Cobs = struct {
    pub const Error = error{
        BufferTooSmall,
        InvalidEncoding,
    };

    pub fn encode(src: []const u8, dst: []u8) Error!usize {
        if (dst.len < src.len + 2) return Error.BufferTooSmall;
        
        var read_index: usize = 0;
        var write_index: usize = 1;
        var code_index: usize = 0;
        var code: u8 = 1;

        while (read_index < src.len) {
            if (src[read_index] == 0) {
                dst[code_index] = code;
                code_index = write_index;
                write_index += 1;
                code = 1;
            } else {
                dst[write_index] = src[read_index];
                write_index += 1;
                code += 1;
                if (code == 0xFF) {
                    dst[code_index] = code;
                    code_index = write_index;
                    write_index += 1;
                    code = 1;
                }
            }
            read_index += 1;
        }
        dst[code_index] = code;
        return write_index;
    }

    pub fn decode(src: []const u8, dst: []u8) Error!usize {
        var read_index: usize = 0;
        var write_index: usize = 0;

        while (read_index < src.len) {
            const code = src[read_index];
            read_index += 1;
            
            var i: u8 = 1;
            while (i < code) : (i += 1) {
                if (read_index >= src.len) return Error.InvalidEncoding;
                if (write_index >= dst.len) return Error.BufferTooSmall;
                dst[write_index] = src[read_index];
                write_index += 1;
                read_index += 1;
            }
            
            if (code < 0xFF and read_index < src.len) {
                if (write_index >= dst.len) return Error.BufferTooSmall;
                dst[write_index] = 0;
                write_index += 1;
            }
        }
        return write_index;
    }
};

test "COBS Loopback" {
    const data = "Carrier\x00Sovereign\x00AI";
    var encoded: [64]u8 = undefined;
    var decoded: [64]u8 = undefined;

    const enc_len = try Cobs.encode(data, &encoded);
    const dec_len = try Cobs.decode(encoded[0..enc_len], &decoded);

    try std.testing.expectEqualStrings(data, decoded[0..dec_len]);
}
