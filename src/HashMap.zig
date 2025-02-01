const std = @import("std");
const Record = @import("Record.zig");
const Utils = @import("Utils.zig");
const Config = @import("Config.zig");
const Result = @import("Error.zig").Result;
const Error = @import("Error.zig");
const Allocator = std.mem.Allocator;
const random = std.crypto.random;
const xxhash = std.hash.XxHash64.hash;
const expect = std.testing.expect;

const Self = @This();

allocator: Allocator,
data: []Record,
config: Config,

pub fn init(allocator: Allocator, config: Config) !Self {
    const data = try allocator.alloc(Record, config.record_count);

    for (0..config.record_count) |i| {
        data[i] = Record{
            .data = null,
            .hash = null,
            .temp = std.math.maxInt(u8) / 2,
            .key_length = 0,
            .value_length = 0,
            .ttl = 0,
        };
    }

    return Self{
        .allocator = allocator,
        .data = data,
        .config = config,
    };
}

pub fn put(self: Self, hash: u64, key: []u8, value: []u8, ttl: ?u32) Error.Result(void) {
    if (key.len > self.config.key_max_length) {
        return .{ .err = @intFromEnum(Error.Error.KeyTooLong) };
    }

    if (value.len > self.config.value_max_length) {
        return .{ .err = @intFromEnum(Error.Error.ValueTooLong) };
    }

    const index = hash % self.config.record_count;
    const record = self.data[index];

    if (record.hash == null or (record.hash == hash and std.mem.eql(u8, record.data.?[0..record.key_length], key)) or Utils.now() > record.ttl or random.intRangeAtMost(u8, 0, std.math.maxInt(u8)) > record.temp) {
        var data = self.allocator.alloc(u8, key.len + value.len) catch return .{ .err = @intFromEnum(Error.Error.OutOfMemory) };

        @memcpy(data[0..key.len], key);
        @memcpy(data[key.len..], value);

        if (record.data) |record_data| {
            self.allocator.free(record_data);
        }

        self.data[index] = Record{
            .data = data,
            .hash = hash,
            .temp = std.math.maxInt(u8) / 2,
            .key_length = @intCast(key.len),
            .value_length = @intCast(value.len),
            .ttl = if (ttl) |t| Utils.now() + t else std.math.maxInt(u32),
        };
    }

    return .{ .ok = {} };
}

pub fn get(self: Self, hash: u64, key: []u8) Error.Result([]u8) {
    if (key.len > self.config.key_max_length) {
        return .{ .err = @intFromEnum(Error.Error.KeyTooLong) };
    }

    const index = hash % self.config.record_count;
    var record = self.data[index];

    if (record.hash == null) {
        return .{ .err = @intFromEnum(Error.Error.RecordEmpty) };
    }

    if (Utils.now() > record.ttl) {
        self.delete_record(record, index);
        return .{ .err = @intFromEnum(Error.Error.TtlExpired) };
    }

    if (record.hash == hash and std.mem.eql(u8, record.data.?[0..record.key_length], key)) {
        if (random.float(f64) < 0.05) {
            record.temp = Utils.saturating_add(u8, record.temp, 1);

            var victim = self.data[random.intRangeAtMost(u32, 0, self.config.record_count)];

            victim.temp = Utils.saturating_sub(u8, record.temp, 1);
        }

        return .{ .ok = record.data.?[record.key_length..] };
    }

    return .{ .err = @intFromEnum(Error.Error.RecordNotFound) };
}

pub fn del(self: Self, hash: u64, key: []u8) Error.Result(void) {
    if (key.len > self.config.key_max_length) {
        return .{ .err = @intFromEnum(Error.Error.KeyTooLong) };
    }

    const index = hash % self.config.record_count;
    const record = self.data[index];

    if (record.hash != null and record.hash == hash and std.mem.eql(u8, record.data.?[0..record.key_length], key)) {
        self.delete_record(record, index);
    }

    return .{ .ok = {} };
}

inline fn delete_record(self: Self, record: Record, index: usize) void {
    self.allocator.free(record.data.?);

    self.data[index] = Record{
        .data = null,
        .hash = null,
        .temp = std.math.maxInt(u8) / 2,
        .key_length = 0,
        .value_length = 0,
        .ttl = 0,
    };
}

pub fn free(self: Self) void {
    for (0..self.config.record_count) |i| {
        const record = self.data[i];

        if (record.data) |data| {
            self.allocator.free(data);
        }
    }

    self.allocator.free(self.data);
}

test "HashMap" {
    const config = Config{
        .port = 3000,
        .record_count = 65536,
        .key_max_length = 1048576,
        .value_max_length = 67108864,
    };

    const allocator = std.testing.allocator;
    const hash_map = try init(allocator, config);
    defer hash_map.free();

    const key = @as([]u8, @constCast("Hello, world!"));
    const value = @as([]u8, @constCast("This is me, Mario!"));
    const hash = xxhash(0, key);

    const put_result = hash_map.put(hash, key, value, null);

    try expect(Error.is_ok(put_result));

    const put_record = hash_map.data[hash % config.record_count];

    try expect(std.mem.eql(u8, put_record.data.?[0..key.len], key));
    try expect(std.mem.eql(u8, put_record.data.?[key.len..], value));
    try expect(put_record.hash == hash);
    try expect(put_record.temp == std.math.maxInt(u8) / 2);

    const get_result = hash_map.get(hash, key);

    try expect(Error.is_ok(get_result));

    const get_value = get_result.ok;

    try expect(std.mem.eql(u8, get_value, value));

    const del_result = hash_map.del(hash, key);

    try expect(Error.is_ok(del_result));

    const del_record = hash_map.data[hash % config.record_count];

    try expect(del_record.hash == null);
    try expect(del_record.data == null);

    const put_result2 = hash_map.put(hash, key, value, 1);

    try expect(Error.is_ok(put_result2));

    std.time.sleep(2000 * 1000000);

    const get_result2 = hash_map.get(hash, key);

    try expect(Error.is_err(get_result2));
}
