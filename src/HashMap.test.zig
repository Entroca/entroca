const std = @import("std");
const HashMap = @import("HashMap.zig");
const Config = @import("Config.zig");
const Utils = @import("Utils.zig");

const allocator = std.testing.allocator;
const xxhash = std.hash.XxHash64.hash;
const expect = std.testing.expect;
const expectError = std.testing.expectError;

const config = Config{
    .port = 3000,
    .warm_up_probability = 0.05,
    .record_count = 1024,
    .key_max_length = 250,
    .value_max_length = 1048576,
};

test "HashMap" {
    var hash_map = try HashMap.init(allocator, config);
    defer hash_map.deinit();

    try expect(hash_map.records.len == config.record_count);

    // Test key and value length validation
    {
        const key_short = try create_filled_slice(0, 'a');
        const key_normal = try create_filled_slice(127, 'b');
        const key_long = try create_filled_slice(255, 'c');
        const value_normal = try create_filled_slice(524288, 'd');

        defer {
            allocator.free(key_short);
            allocator.free(key_normal);
            allocator.free(key_long);
            allocator.free(value_normal);
        }

        const value_short = try create_filled_slice(0, 'e');
        const value_long = try create_filled_slice(1048577, 'f');
        defer {
            allocator.free(value_short);
            allocator.free(value_long);
        }

        const hash = xxhash(0, key_normal);

        // Test key length validations
        try expectError(error.KeyTooShort, hash_map.put(hash, key_short, value_normal, null));
        try expectError(error.KeyTooLong, hash_map.put(hash, key_long, value_normal, null));
        try expectError(error.KeyTooShort, hash_map.get(hash, key_short));
        try expectError(error.KeyTooLong, hash_map.get(hash, key_long));
        try expectError(error.KeyTooShort, hash_map.del(hash, key_short));
        try expectError(error.KeyTooLong, hash_map.del(hash, key_long));

        // Test value length validations
        try expectError(error.ValueTooShort, hash_map.put(hash, key_normal, value_short, null));
        try expectError(error.ValueTooLong, hash_map.put(hash, key_normal, value_long, null));
    }

    // Test empty record handling
    {
        const kv = try create_key_value(100, 1000, 'g', 'h');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try expectError(error.RecordEmpty, hash_map.get(hash, kv.key));
    }

    // Test successful put and get operations
    {
        const kv = try create_key_value(100, 1000, 'i', 'j');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try hash_map.put(hash, kv.key, kv.value, null);
        const result = try hash_map.get(hash, kv.key);
        try expect(std.mem.eql(u8, result, kv.value));
    }

    // Test record overwriting
    {
        const kv = try create_key_value(100, 500, 'k', 'l');
        const new_value = try create_filled_slice(600, 'm');
        defer {
            free_key_value(kv);
            allocator.free(new_value);
        }

        const hash = xxhash(0, kv.key);
        try hash_map.put(hash, kv.key, kv.value, null);
        try hash_map.put(hash, kv.key, new_value, null);
        const result = try hash_map.get(hash, kv.key);
        try expect(std.mem.eql(u8, result, new_value));
    }

    // Test TTL expiration
    {
        const kv = try create_key_value(100, 1000, 'n', 'o');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try hash_map.put(hash, kv.key, kv.value, 1); // TTL 1 second
        std.time.sleep(2 * std.time.ns_per_s);

        try expectError(error.TtlExpired, hash_map.get(hash, kv.key));
        const index = Utils.hash_to_index(config, hash);
        try expect(hash_map.records[index].cmp_hash(null));
    }

    // Test record deletion
    {
        const kv = try create_key_value(100, 1000, 'p', 'q');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try hash_map.put(hash, kv.key, kv.value, null);
        try hash_map.del(hash, kv.key);
        try expectError(error.RecordEmpty, hash_map.get(hash, kv.key));
    }

    // Test maximum length boundaries
    {
        const kv = try create_key_value(config.key_max_length, config.value_max_length, 'r', 's');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try hash_map.put(hash, kv.key, kv.value, null);
        const result = try hash_map.get(hash, kv.key);
        try expect(std.mem.eql(u8, result, kv.value));
    }
}

test "HashMap collision" {
    const collision_config = Config{
        .port = 3000,
        .warm_up_probability = 0.0, // Disable unlucky overwrites
        .record_count = 1,
        .key_max_length = 250,
        .value_max_length = 1048576,
    };

    var collision_map = try HashMap.init(allocator, collision_config);
    defer collision_map.deinit();

    // Test collision behavior
    const kv1 = try create_key_value(100, 1000, 't', 'u');
    const kv2 = try create_key_value(100, 1000, 'v', 'w');
    defer {
        free_key_value(kv1);
        free_key_value(kv2);
    }

    const hash1 = xxhash(0, kv1.key);
    const hash2 = xxhash(0, kv2.key);

    try collision_map.put(hash1, kv1.key, kv1.value, null);
    try collision_map.put(hash2, kv2.key, kv2.value, null);

    // Verify second record wasn't stored due to collision
    try expectError(error.RecordNotFound, collision_map.get(hash2, kv2.key));

    // Verify first record remains intact
    const result = try collision_map.get(hash1, kv1.key);
    try expect(std.mem.eql(u8, result, kv1.value));
}

const KeyValue = struct {
    key: []u8,
    value: []u8,
};

pub fn create_filled_slice(length: usize, fill_char: u8) ![]u8 {
    const slice = try allocator.alloc(u8, length);

    @memset(slice, fill_char);

    return slice;
}

pub fn create_key_value(key_len: usize, value_len: usize, key_char: u8, value_char: u8) !KeyValue {
    const key = try create_filled_slice(key_len, key_char);
    errdefer allocator.free(key);

    const value = try create_filled_slice(value_len, value_char);
    errdefer allocator.free(value);

    return .{ .key = key, .value = value };
}

pub fn free_key_value(kv: KeyValue) void {
    allocator.free(kv.key);
    allocator.free(kv.value);
}
