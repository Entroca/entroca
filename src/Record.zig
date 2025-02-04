const std = @import("std");
const Utils = @import("Utils.zig");
const Config = @import("Config.zig");

const Allocator = std.mem.Allocator;

const Self = @This();

data: ?[]u8,
hash: ?u64,
key_length: u32,
value_length: u32,
ttl: u32,
temperature: u8,

pub const TEMP_DEFAULT = std.math.maxInt(u8) / 2;

pub const ErrorAssertKeyValueLength = ErrorAssertKeyLength || ErrorAssertValueLength;

pub fn get_key(self: Self) []u8 {
    return self.data.?[0..self.key_length];
}

pub fn get_value(self: Self) []u8 {
    return self.data.?[self.key_length..];
}

pub fn cmp_key(self: Self, key: []u8) bool {
    return Utils.memcmp(self.get_key(), key);
}

pub fn cmp_hash(self: Self, hash: ?u64) bool {
    return self.hash == hash;
}

pub fn exp_ttl(self: Self) bool {
    return Utils.now() > self.ttl;
}

pub fn is_unlucky(self: Self, random_temperature: u8) bool {
    return random_temperature > self.temperature;
}

pub fn ttl_value(ttl: ?u32) u32 {
    return if (ttl) |t| Utils.now() + t else std.math.maxInt(u32);
}

pub fn hash_to_index(config: Config, hash: u64) u32 {
    return @intCast(hash % config.record_count);
}

pub fn get_victim_index(config: Config, current_index: u32) u32 {
    return @min(current_index + 1, config.record_count - 1);
}

pub fn should_inc_temp(config: Config, random_probability: f64) bool {
    return random_probability < config.warm_up_probability;
}

pub fn temp_inc(self: *Self) void {
    self.temperature = Utils.saturating_add(u8, self.temperature, 1);
}

pub fn temp_dec(self: *Self) void {
    self.temperature = Utils.saturating_sub(u8, self.temperature, 1);
}

pub fn deinit(self: Self, allocator: Allocator) void {
    if (self.data) |buffer| {
        allocator.free(buffer);
    }
}

pub const ErrorAssertKeyLength = error{
    KeyTooShort,
    KeyTooLong,
};

pub fn assert_key_length(key: []u8, config: Config) ErrorAssertKeyLength!void {
    if (key.len > config.key_max_length) {
        return error.KeyTooLong;
    } else if (key.len == 0) {
        return error.KeyTooShort;
    }
}

pub const ErrorAssertValueLength = error{
    ValueTooShort,
    ValueTooLong,
};

pub fn assert_value_length(value: []u8, config: Config) ErrorAssertValueLength!void {
    if (value.len > config.value_max_length) {
        return error.ValueTooLong;
    } else if (value.len == 0) {
        return error.ValueTooShort;
    }
}

pub fn default() Self {
    return Self{
        .data = null,
        .hash = null,
        .temperature = TEMP_DEFAULT,
        .key_length = 0,
        .value_length = 0,
        .ttl = 0,
    };
}

pub fn create(allocator: Allocator, hash: u64, key: []u8, value: []u8, ttl: ?u32) !Self {
    var new_buffer = try allocator.alloc(u8, key.len + value.len);

    @memcpy(new_buffer[0..key.len], key);
    @memcpy(new_buffer[key.len..], value);

    return Self{
        .data = new_buffer,
        .hash = hash,
        .temperature = TEMP_DEFAULT,
        .key_length = @intCast(key.len),
        .value_length = @intCast(value.len),
        .ttl = ttl_value(ttl),
    };
}
