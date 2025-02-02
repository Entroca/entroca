const std = @import("std");
const Record = @import("Record.zig");
const HashMap = @import("HashMap.zig");
const Utils = @import("Utils.zig");
const Error = @import("Error.zig");
const Config = @import("Config.zig");

/// Handles PUT operation by parsing buffer and inserting into hash map
/// Buffer format: [8-byte hash][4-byte TTL][4-byte key len][key bytes][4-byte value len][value bytes]
fn call_put(hash_map: HashMap, request_buffer: []u8) Error.Result(void) {
    const HASH_SIZE = @sizeOf(u64);
    const TTL_SIZE = @sizeOf(u32);
    const LEN_FIELD_SIZE = @sizeOf(u32);
    const request_length = request_buffer.len;

    // Calculate remaining bytes after hash and TTL
    const remaining_bytes = Utils.saturating_sub(usize, request_length, HASH_SIZE + TTL_SIZE);

    // Validate buffer has minimum required bytes
    if (request_length < HASH_SIZE or remaining_bytes < (2 * LEN_FIELD_SIZE + 2)) {
        return .{ .err = @intFromEnum(Error.Error.NotEnoughBytes) };
    }

    // Parse hash (first 8 bytes)
    const hash = std.mem.readInt(u64, request_buffer[0..HASH_SIZE], .little);

    // Parse TTL (next 4 bytes)
    const ttl_offset = HASH_SIZE;
    const ttl = std.mem.readInt(u32, request_buffer[ttl_offset .. ttl_offset + TTL_SIZE], .little);

    // Parse key length (4 bytes after TTL)
    const key_len_offset = ttl_offset + TTL_SIZE;
    const key_length = std.mem.readInt(u32, request_buffer[key_len_offset .. key_len_offset + LEN_FIELD_SIZE], .little);

    // Extract key bytes
    const key_start = key_len_offset + LEN_FIELD_SIZE;
    const key_end = key_start + key_length;
    const key = request_buffer[key_start..key_end];

    // Parse value length (4 bytes after key)
    const val_len_offset = key_end;
    const value_length = std.mem.readInt(u32, request_buffer[val_len_offset .. val_len_offset + LEN_FIELD_SIZE][0..4], .little);

    // Extract value bytes
    const value_start = val_len_offset + LEN_FIELD_SIZE;
    const value_end = value_start + value_length;
    const value = request_buffer[value_start..value_end];

    return hash_map.put(hash, key, value, ttl);
}

/// Handles GET operation by parsing buffer and retrieving from hash map
/// Buffer format: [8-byte hash][key bytes]
fn call_get(hash_map: HashMap, request_buffer: []u8) Error.Result([]u8) {
    const HASH_SIZE = @sizeOf(u64);
    const request_length = request_buffer.len;
    const min_required_bytes = HASH_SIZE + 1; // Hash + at least 1 byte key

    if (request_length < min_required_bytes) {
        return .{ .err = @intFromEnum(Error.Error.NotEnoughBytes) };
    }

    // Extract hash and key from buffer
    const hash = std.mem.readInt(u64, request_buffer[0..HASH_SIZE], .little);
    const key = request_buffer[HASH_SIZE..];

    return hash_map.get(hash, key);
}

/// Handles DEL operation by parsing buffer and removing from hash map
/// Buffer format: [8-byte hash][key bytes]
fn call_del(hash_map: HashMap, request_buffer: []u8) Error.Result(void) {
    const HASH_SIZE = @sizeOf(u64);
    const request_length = request_buffer.len;
    const min_required_bytes = HASH_SIZE + 1; // Hash + at least 1 byte key

    if (request_length < min_required_bytes) {
        return .{ .err = @intFromEnum(Error.Error.NotEnoughBytes) };
    }

    // Extract hash and key from buffer
    const hash = std.mem.readInt(u64, request_buffer[0..HASH_SIZE], .little);
    const key = request_buffer[HASH_SIZE..];

    return hash_map.del(hash, key);
}

/// Main entry point for command processing
/// Commands:
/// - 0x00: GET (followed by call_get buffer)
/// - 0x01: PUT (followed by call_put buffer)
/// - 0x02: DEL (followed by call_del buffer)
/// Response format:
/// - Success: [0x01][response data...]
/// - Error:   [0x00][error code]
pub fn call(
    hash_map: HashMap,
    input_buffer: []u8,
    output_buffer: []u8,
) []u8 {
    // Command byte is first byte of input buffer
    return switch (input_buffer[0]) {
        // GET Command
        0 => handle_get: {
            const result = call_get(hash_map, input_buffer[1..]);

            if (result == .ok) {
                // Success response: [0x01][value bytes]
                const value = result.ok;
                output_buffer[0] = 1;
                @memcpy(output_buffer[1 .. 1 + value.len], value);
                break :handle_get output_buffer[0 .. 1 + value.len];
            } else {
                // Error response: [0x00][error code]
                output_buffer[0] = 0;
                output_buffer[1] = result.err;
                break :handle_get output_buffer[0..2];
            }
        },

        // PUT Command
        1 => handle_put: {
            const result = call_put(hash_map, input_buffer[1..]);

            if (result == .ok) {
                // Success response: [0x01]
                output_buffer[0] = 1;
                break :handle_put output_buffer[0..1];
            } else {
                // Error response: [0x00][error code]
                output_buffer[0] = 0;
                output_buffer[1] = result.err;
                break :handle_put output_buffer[0..2];
            }
        },

        // DEL Command
        2 => handle_del: {
            const result = call_del(hash_map, input_buffer[1..]);

            if (result == .ok) {
                // Success response: [0x01]
                output_buffer[0] = 1;
                break :handle_del output_buffer[0..1];
            } else {
                // Error response: [0x00][error code]
                output_buffer[0] = 0;
                output_buffer[1] = result.err;
                break :handle_del output_buffer[0..2];
            }
        },

        // Unknown command
        else => handle_unknown: {
            output_buffer[0] = 0;
            output_buffer[1] = @intFromEnum(Error.Error.CommandNotFound);
            break :handle_unknown output_buffer[0..2];
        },
    };
}
