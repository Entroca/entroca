const std = @import("std");
const Record = @import("Record.zig");
const Utils = @import("Utils.zig");
const Config = @import("Config.zig");
const Result = @import("Error.zig").Result;
const Error = @import("Error.zig");
const Allocator = std.mem.Allocator;
const random = std.crypto.random;

const Self = @This();

allocator: Allocator,
records: []Record,
config: Config,

/// Initializes a new hash map with the given allocator and configuration.
/// Allocates memory for all records and initializes them to empty state.
pub fn init(allocator: Allocator, config: Config) !Self {
    const records = try allocator.alloc(Record, config.record_count);

    // Initialize all records with empty/default values
    for (0..config.record_count) |i| {
        records[i] = Record{
            .data = null,
            .hash = null,
            .temperature = std.math.maxInt(u8) / 2,
            .key_length = 0,
            .value_length = 0,
            .ttl = 0,
        };
    }

    return Self{
        .allocator = allocator,
        .records = records,
        .config = config,
    };
}

/// Stores a key-value pair in the hash map using the provided precomputed hash.
/// Handles both insertions and updates, including eviction based on TTL and temperature.
pub fn put(self: Self, hash: u64, key: []u8, value: []u8, ttl: ?u32) Error.Result(void) {
    if (key.len > self.config.key_max_length) {
        return .{ .err = @intFromEnum(Error.Error.KeyTooLong) };
    }

    if (value.len > self.config.value_max_length) {
        return .{ .err = @intFromEnum(Error.Error.ValueTooLong) };
    }

    const index = self.hash_to_index(hash);
    const current_record = self.records[index];

    // Conditions for overwriting the current record:
    // 1. Slot is empty
    // 2. Existing key matches (update case)
    // 3. Record has expired
    // 4. Random eviction based on temperature value
    const should_overwrite = current_record.hash == null or
        (current_record.hash == hash and
        std.mem.eql(u8, current_record.data.?[0..current_record.key_length], key)) or
        Utils.now() > current_record.ttl or
        random.intRangeAtMost(u8, 0, std.math.maxInt(u8)) > current_record.temperature;

    if (should_overwrite) {
        // Allocate combined storage for key + value
        var new_buffer = self.allocator.alloc(u8, key.len + value.len) catch
            return .{ .err = @intFromEnum(Error.Error.OutOfMemory) };

        // Copy key and value into the new buffer
        @memcpy(new_buffer[0..key.len], key);
        @memcpy(new_buffer[key.len..], value);

        // Free existing data if present
        if (current_record.data) |existing_buffer| {
            self.allocator.free(existing_buffer);
        }

        // Create updated record
        self.records[index] = Record{
            .data = new_buffer,
            .hash = hash,
            .temperature = std.math.maxInt(u8) / 2,
            .key_length = @intCast(key.len),
            .value_length = @intCast(value.len),
            .ttl = if (ttl) |t| Utils.now() + t else std.math.maxInt(u32),
        };
    }

    return .{ .ok = {} };
}

/// Retrieves a value by its precomputed hash and key.
/// Handles TTL expiration and implements temperature-based caching strategy.
pub fn get(self: Self, hash: u64, key: []u8) Error.Result([]u8) {
    if (key.len > self.config.key_max_length) {
        return .{ .err = @intFromEnum(Error.Error.KeyTooLong) };
    }

    const index = self.hash_to_index(hash);
    const current_record = self.records[index];

    if (current_record.hash == null) {
        return .{ .err = @intFromEnum(Error.Error.RecordEmpty) };
    }

    // Check and handle expiration
    if (Utils.now() > current_record.ttl) {
        self.clear_record_at_index(index);
        return .{ .err = @intFromEnum(Error.Error.TtlExpired) };
    }

    // Verify key match
    if (current_record.hash == hash and
        std.mem.eql(u8, current_record.data.?[0..current_record.key_length], key))
    {

        // With 5% probability, adjust temperatures for caching strategy
        if (random.float(f64) < 0.05) {
            // Increase temperature of current record
            self.records[index].temperature = Utils.saturating_add(u8, current_record.temperature, 1);

            // Find and cool a random victim record
            const victim_index = random.intRangeAtMost(u32, 0, self.config.record_count);
            var victim = &self.records[victim_index];
            victim.temperature = Utils.saturating_sub(u8, victim.temperature, 1);
        }

        // Return the value portion of the buffer
        return .{ .ok = current_record.data.?[current_record.key_length..] };
    }

    return .{ .err = @intFromEnum(Error.Error.RecordNotFound) };
}

/// Removes a record by its precomputed hash and key if it exists
pub fn del(self: Self, hash: u64, key: []u8) Error.Result(void) {
    if (key.len > self.config.key_max_length) {
        return .{ .err = @intFromEnum(Error.Error.KeyTooLong) };
    }

    const index = self.hash_to_index(hash);
    const current_record = self.records[index];

    if (current_record.hash != null and
        current_record.hash == hash and
        std.mem.eql(u8, current_record.data.?[0..current_record.key_length], key))
    {
        self.clear_record_at_index(index);
    }

    return .{ .ok = {} };
}

/// Internal helper to clear a record at a specific index and free its memory
inline fn clear_record_at_index(self: Self, index: usize) void {
    const record = self.records[index];

    if (record.data) |buffer| {
        self.allocator.free(buffer);
    }

    self.records[index] = Record{
        .data = null,
        .hash = null,
        .temperature = std.math.maxInt(u8) / 2,
        .key_length = 0,
        .value_length = 0,
        .ttl = 0,
    };
}

inline fn hash_to_index(self: Self, hash: u64) usize {
    return @intCast(hash % self.config.record_count);
}

/// Releases all resources and memory associated with the hash map
pub fn deinit(self: Self) void {
    // Free all individual record buffers
    for (0..self.config.record_count) |i| {
        if (self.records[i].data) |buffer| {
            self.allocator.free(buffer);
        }
    }

    // Free the main records array
    self.allocator.free(self.records);
}
