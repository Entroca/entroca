const std = @import("std");
const HashMap = @import("HashMap.zig");
const Config = @import("Config.zig");

const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
hash_map: HashMap,

pub const ReadError = error{NotEnoughBytes};

pub const PutError = ReadError || HashMap.PutError;
pub const GetError = ReadError || HashMap.GetError;
pub const DelError = ReadError || HashMap.DelError;

pub const Error = PutError || GetError || DelError;

pub fn init(allocator: Allocator, config: Config) !Self {
    const hash_map = try HashMap.init(allocator, config);

    return Self{
        .allocator = allocator,
        .hash_map = hash_map,
    };
}

pub fn deinit(self: Self) void {
    self.hash_map.deinit();
}

pub fn put(self: Self, buffer: []u8) PutError!void {
    var index: usize = 0;

    const hash = try read_hash(&index, buffer);
    const ttl = try read_ttl(&index, buffer);
    const key = try read_array(&index, buffer);
    const value = try read_array(&index, buffer);

    return self.hash_map.put(hash, key, value, ttl);
}

pub fn get(self: Self, buffer: []u8) GetError![]u8 {
    var index: usize = 0;

    const hash = try read_hash(&index, buffer);
    const key = try read_array(&index, buffer);

    return self.hash_map.get(hash, key);
}

pub fn del(self: Self, buffer: []u8) DelError!void {
    var index: usize = 0;

    const hash = try read_hash(&index, buffer);
    const key = try read_array(&index, buffer);

    return self.hash_map.del(hash, key);
}

fn assert_bytes(index: usize, buffer: []u8, size: usize) ReadError!void {
    if (buffer.len - index < size) {
        return error.NotEnoughBytes;
    }
}

fn read_hash(index: *usize, buffer: []u8) ReadError!u64 {
    const size = 8;

    try assert_bytes(index.*, buffer, size);

    const result = std.mem.readInt(u64, buffer[index.* .. index.* + size][0..8], .little);

    index.* += size;

    return result;
}

fn read_ttl(index: *usize, buffer: []u8) ReadError!?u32 {
    try assert_bytes(index.*, buffer, 1);

    if (buffer[index.*] == 0) {
        index.* += 1;

        return null;
    } else {
        const size = 5;

        try assert_bytes(index.*, buffer, size);

        const result = std.mem.readInt(u32, buffer[index.* + 1 .. index.* + size][0..4], .little);

        index.* += size;

        return result;
    }
}

fn read_length(index: *usize, buffer: []u8) ReadError!u32 {
    const size = 4;

    try assert_bytes(index.*, buffer, size);

    const result = std.mem.readInt(u32, buffer[index.* .. index.* + size][0..4], .little);

    index.* += size;

    return result;
}

fn read_array(index: *usize, buffer: []u8) ReadError![]u8 {
    const size = try read_length(index, buffer);

    try assert_bytes(index.*, buffer, size);

    const result = buffer[index.* .. index.* + size];

    index.* += size;

    return result;
}
