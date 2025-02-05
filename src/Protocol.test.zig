const std = @import("std");
const Protocol = @import("Protocol.zig");
const Config = @import("Config.zig");

const allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectError = std.testing.expectError;

const config = Config{
    .port = 3000,
    .warm_up_probability = 0.05,
    .record_count = 1024,
    .key_max_length = 250,
    .value_max_length = 1048576,
};

fn writeU64(buffer: []u8, value: u64) void {
    std.mem.writeInt(u64, buffer[0..8], value, .little);
}

fn writeU32(buffer: []u8, value: u32) void {
    std.mem.writeInt(u32, buffer[0..4], value, .little);
}

test "Protocol - buffer parsing" {
    var protocol = try Protocol.init(allocator, config);
    defer protocol.deinit();

    // Test buffer too small for hash
    {
        var buffer: [7]u8 = undefined;

        try expectError(error.NotEnoughBytes, protocol.put(buffer[0..]));
        try expectError(error.NotEnoughBytes, protocol.get(buffer[0..]));
        try expectError(error.NotEnoughBytes, protocol.del(buffer[0..]));
    }

    // Test buffer has hash but no TTL flag
    {
        var buffer: [8]u8 = undefined;

        writeU64(buffer[0..], 12345);

        try expectError(error.NotEnoughBytes, protocol.put(buffer[0..]));
    }

    // Test buffer has hash and TTL flag but no TTL value
    {
        var buffer: [9]u8 = undefined;

        writeU64(buffer[0..], 12345);
        buffer[8] = 1; // TTL flag set but no TTL value

        try expectError(error.NotEnoughBytes, protocol.put(buffer[0..]));
    }

    // Test buffer missing key length
    {
        var buffer: [13]u8 = undefined;

        writeU64(buffer[0..], 12345);
        buffer[8] = 1;
        writeU32(buffer[9..], 60); // TTL value
        //
        try expectError(error.NotEnoughBytes, protocol.put(buffer[0..]));
    }

    // Test buffer has key length but missing key data
    {
        var buffer: [17]u8 = undefined;

        writeU64(buffer[0..], 12345);
        buffer[8] = 1;
        writeU32(buffer[9..], 60); // TTL value
        writeU32(buffer[13..], 10); // Key length

        try expectError(error.NotEnoughBytes, protocol.put(buffer[0..]));
    }

    // Test buffer parsing with no TTL
    {
        var buffer: [17]u8 = undefined;

        writeU64(buffer[0..], 12345);
        buffer[8] = 0; // No TTL
        writeU32(buffer[9..], 4); // Key length
        @memcpy(buffer[13..], "test");

        // We need value length and data
        try expectError(error.NotEnoughBytes, protocol.put(buffer[0..]));
    }
}
