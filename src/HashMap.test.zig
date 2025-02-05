const std = @import("std");
const HashMap = @import("HashMap.zig");
const Config = @import("Config.zig");
const Record = @import("Record.zig");
const Protocol = @import("Protocol.zig");

const Error = HashMap.Error;

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
        try expectError(Error.KeyTooShort, hash_map.put(Protocol.Put{
            .hash = hash,
            .key = key_short,
            .value = value_normal,
            .ttl = null,
        }));
        try expectError(Error.KeyTooLong, hash_map.put(Protocol.Put{
            .hash = hash,
            .key = key_long,
            .value = value_normal,
            .ttl = null,
        }));
        try expectError(Error.KeyTooShort, hash_map.get(Protocol.Get{
            .hash = hash,
            .key = key_short,
        }));
        try expectError(Error.KeyTooLong, hash_map.get(Protocol.Get{
            .hash = hash,
            .key = key_long,
        }));
        try expectError(Error.KeyTooShort, hash_map.del(Protocol.Get{
            .hash = hash,
            .key = key_short,
        }));
        try expectError(Error.KeyTooLong, hash_map.del(Protocol.Get{
            .hash = hash,
            .key = key_long,
        }));

        // Test value length validations
        try expectError(Error.ValueTooShort, hash_map.put(Protocol.Put{
            .hash = hash,
            .key = key_normal,
            .value = value_short,
            .ttl = null,
        }));
        try expectError(Error.ValueTooLong, hash_map.put(Protocol.Put{
            .hash = hash,
            .key = key_normal,
            .value = value_long,
            .ttl = null,
        }));
    }

    // Test empty record handling
    {
        const kv = try create_key_value(100, 1000, 'g', 'h');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try expectError(Error.RecordEmpty, hash_map.get(Protocol.Get{
            .hash = hash,
            .key = kv.key,
        }));
    }

    // Test successful put and get operations
    {
        const kv = try create_key_value(100, 1000, 'i', 'j');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try hash_map.put(Protocol.Put{
            .hash = hash,
            .key = kv.key,
            .value = kv.value,
            .ttl = null,
        });
        const result = try hash_map.get(Protocol.Get{
            .hash = hash,
            .key = kv.key,
        });
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
        try hash_map.put(Protocol.Put{
            .hash = hash,
            .key = kv.key,
            .value = kv.value,
            .ttl = null,
        });
        try hash_map.put(Protocol.Put{
            .hash = hash,
            .key = kv.key,
            .value = new_value,
            .ttl = null,
        });
        const result = try hash_map.get(Protocol.Get{
            .hash = hash,
            .key = kv.key,
        });
        try expect(std.mem.eql(u8, result, new_value));
    }

    // Test TTL expiration
    {
        const kv = try create_key_value(100, 1000, 'n', 'o');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try hash_map.put(Protocol.Put{
            .hash = hash,
            .key = kv.key,
            .value = kv.value,
            .ttl = 1,
        });
        std.time.sleep(2 * std.time.ns_per_s);

        try expectError(Error.TtlExpired, hash_map.get(Protocol.Get{
            .hash = hash,
            .key = kv.key,
        }));
        const index = Record.hash_to_index(config, hash);
        try expect(hash_map.records[index].cmp_hash(null));
    }

    // Test record deletion
    {
        const kv = try create_key_value(100, 1000, 'p', 'q');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try hash_map.put(Protocol.Put{
            .hash = hash,
            .key = kv.key,
            .value = kv.value,
            .ttl = null,
        });
        try hash_map.del(Protocol.Get{
            .hash = hash,
            .key = kv.key,
        });
        try expectError(Error.RecordEmpty, hash_map.get(Protocol.Get{
            .hash = hash,
            .key = kv.key,
        }));
    }

    // Test maximum length boundaries
    {
        const kv = try create_key_value(config.key_max_length, config.value_max_length, 'r', 's');
        defer free_key_value(kv);

        const hash = xxhash(0, kv.key);
        try hash_map.put(Protocol.Put{
            .hash = hash,
            .key = kv.key,
            .value = kv.value,
            .ttl = null,
        });
        const result = try hash_map.get(Protocol.Get{
            .hash = hash,
            .key = kv.key,
        });
        try expect(std.mem.eql(u8, result, kv.value));
    }
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
