const std = @import("std");
const Record = @import("Record.zig");
const Utils = @import("Utils.zig");
const Allocator = std.mem.Allocator;
const random = std.crypto.random;
const xxhash = std.hash.XxHash64.hash;
const expect = std.testing.expect;

const Self = @This();

allocator: Allocator,
data: []Record,
size: u32,

pub fn init(allocator: Allocator, size: u32) !Self {
    const data = try allocator.alloc(Record, size);

    for (0..size) |i| {
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
        .size = size,
    };
}

pub fn put(self: Self, hash: u64, key: []u8, value: []u8, ttl: ?u32) !void {
    const index = hash % self.size;
    const record = self.data[index];

    if (record.hash == null or (record.hash == hash and std.mem.eql(u8, record.data.?[0..record.key_length], key)) or @as(u32, @intCast(std.time.timestamp())) > record.ttl or random.intRangeAtMost(u8, 0, std.math.maxInt(u8)) > record.temp) {
        if (record.data) |data| {
            self.allocator.free(data);
        }

        var data = try self.allocator.alloc(u8, key.len + value.len);

        @memcpy(data[0..key.len], key);
        @memcpy(data[key.len..], value);

        self.data[index] = Record{
            .data = data,
            .hash = hash,
            .temp = std.math.maxInt(u8) / 2,
            .key_length = @intCast(key.len),
            .value_length = @intCast(value.len),
            .ttl = if (ttl) |t| t else std.math.maxInt(u32),
        };
    }
}

pub fn get(self: Self, hash: u64, key: []u8) ![]u8 {
    const index = hash % self.size;
    var record = self.data[index];

    if (record.hash == null) {
        return error.RecordEmpty;
    }

    if (@as(u32, @intCast(std.time.timestamp())) > record.ttl) {
        self.delete_record(record, index);
        return error.TtlExpired;
    }

    if (record.hash == hash and std.mem.eql(u8, record.data.?[0..record.key_length], key)) {
        if (random.float(f64) < 0.05) {
            record.temp = Utils.saturating_add(u8, record.temp, 1);

            var victim = self.data[random.intRangeAtMost(u32, 0, self.size)];

            victim.temp = Utils.saturating_sub(u8, record.temp, 1);
        }

        return record.data.?[record.key_length..];
    }

    return error.RecordNotFound;
}

pub fn del(self: Self, hash: u64, key: []u8) void {
    const index = hash % self.size;
    const record = self.data[index];

    if (record.hash != null and record.hash == hash and std.mem.eql(u8, record.data.?[0..record.key_length], key)) {
        self.delete_record(record, index);
    }
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

pub fn peek(self: Self, hash: u64) Record {
    return self.data[hash % self.size];
}

pub fn free(self: Self) void {
    for (0..self.size) |i| {
        const record = self.data[i];

        if (record.data) |data| {
            self.allocator.free(data);
        }
    }

    self.allocator.free(self.data);
}

// test "HashMap" {
//     const allocator = std.testing.allocator;
//     const hash_map = try init(allocator, 1024);
//     defer hash_map.free();

//     const key = @as([]u8, @constCast("Hello, world!"));
//     const value = @as([]u8, @constCast("This is me, Mario!"));
//     const hash = xxhash(0, key);

//     try hash_map.put(hash, key, value, null);

//     const peek_record = hash_map.peek(hash);

//     try expect(std.mem.eql(u8, peek_record.data.?[0..key.len], key));
//     try expect(std.mem.eql(u8, peek_record.data.?[key.len..], value));
//     try expect(peek_record.hash == hash);
//     try expect(peek_record.temp == std.math.maxInt(u8) / 2);

//     const get_record = try hash_map.get(hash, key);

//     try expect(std.mem.eql(u8, get_record.data.?[0..key.len], key));
//     try expect(std.mem.eql(u8, get_record.data.?[key.len..], value));
//     try expect(get_record.hash == hash);
//     try expect(get_record.temp == std.math.maxInt(u8) / 2);

//     hash_map.del(hash, key);

//     const del_record = hash_map.peek(hash);

//     try expect(del_record.hash == null);
//     try expect(del_record.data == null);

//     try hash_map.put(hash, key, value, @as(u32, @intCast(std.time.timestamp())) + 1);

//     std.time.sleep(2000 * 1000000);

//     try expect(hash_map.get(hash, key) == error.TtlExpired);
// }
