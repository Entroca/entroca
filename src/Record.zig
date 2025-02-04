const std = @import("std");
const Utils = @import("Utils.zig");

const Allocator = std.mem.Allocator;

const Self = @This();

data: ?[]u8,
hash: ?u64,
key_length: u32,
value_length: u32,
ttl: u32,
temperature: u8,

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

pub fn is_unlucky(self: Self) bool {
    return Utils.temp_rand() > self.temperature;
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

pub fn default() Self {
    return Self{
        .data = null,
        .hash = null,
        .temperature = Utils.temp_value(),
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
        .temperature = Utils.temp_value(),
        .key_length = @intCast(key.len),
        .value_length = @intCast(value.len),
        .ttl = Utils.ttl_value(ttl),
    };
}
