const std = @import("std");
const Record = @import("Record.zig");
const HashMap = @import("HashMap.zig");
const Utils = @import("Utils.zig");
const xxhash = std.hash.XxHash64.hash;
const expect = std.testing.expect;

fn call_get(hash_map: HashMap, buffer: []u8) ![]u8 {
    const hash_length = @sizeOf(u64);
    const buffer_length = buffer.len;
    const key_length = Utils.saturating_sub(usize, buffer_length, hash_length);

    if (buffer_length < hash_length or key_length == 0) {
        return error.NotEnoughBytes;
    }

    const hash = std.mem.readInt(u64, buffer[0..hash_length], .little);
    const key = buffer[hash_length..];

    return hash_map.get(hash, key);
}

fn call_put(hash_map: HashMap, buffer: []u8) !void {
    const hash_length = @sizeOf(u64);
    const length_length = @sizeOf(u32);
    const ttl_length = @sizeOf(u32);
    const buffer_length = buffer.len;
    const remaining_length = Utils.saturating_sub(usize, buffer_length, hash_length + ttl_length);

    if (buffer_length < hash_length or remaining_length < (2 * length_length + 2)) {
        return error.NotEnoughBytes;
    }

    const hash = std.mem.readInt(u64, buffer[0..hash_length], .little);
    const ttl = std.mem.readInt(u32, buffer[hash_length .. hash_length + ttl_length][0..4], .little);

    const key_length_start = hash_length + ttl_length;
    const key_length_end = key_length_start + length_length;
    const key_length = std.mem.readInt(u32, buffer[key_length_start..key_length_end][0..4], .little);

    const key_start = key_length_end;
    const key_end = key_start + key_length;
    const key = buffer[key_start..key_end];

    const value_length_start = key_end;
    const value_length_end = value_length_start + length_length;
    const value_length = std.mem.readInt(u32, buffer[value_length_start..value_length_end][0..4], .little);

    const value_start = value_length_end;
    const value_end = value_start + value_length;
    const value = buffer[value_start..value_end];

    return hash_map.put(hash, key, value, ttl);
}

fn call_del(hash_map: HashMap, buffer: []u8) !void {
    const hash_length = @sizeOf(u64);
    const buffer_length = buffer.len;
    const key_length = Utils.saturating_sub(usize, buffer_length, hash_length);

    if (buffer_length < hash_length or key_length == 0) {
        return error.NotEnoughBytes;
    }

    const hash = std.mem.readInt(u64, buffer[0..hash_length], .little);
    const key = buffer[hash_length..];

    return hash_map.del(hash, key);
}

pub fn call(hash_map: HashMap, buffer: []u8) ![]u8 {
    return switch (buffer[0]) {
        0 => call_get(hash_map, buffer[1..]),
        1 => block: {
            try call_put(hash_map, buffer[1..]);
            break :block error.NoReturn;
        },
        2 => block: {
            try call_del(hash_map, buffer[1..]);
            break :block error.NoReturn;
        },
        else => error.CommandNotFound,
    };
}

// test "put" {
//     std.debug.print("PUT\n", .{});

//     const allocator = std.testing.allocator;
//     const hash_map = try HashMap.init(allocator, 1024);
//     defer hash_map.free();

//     const key = @as([]u8, @constCast("Hello, world!"));
//     const value = @as([]u8, @constCast("This is me, Mario!"));
//     const hash = xxhash(0, key);
//     const ttl = @as(u32, @intCast(std.time.timestamp())) + 1;

//     const buffer = try allocator.alloc(u8, 1 + 8 + 4 + 4 + key.len + 4 + value.len);
//     defer allocator.free(buffer);

//     buffer[0] = 1;

//     @memcpy(buffer[1..9], std.mem.toBytes(hash)[0..]);
//     @memcpy(buffer[9..13], std.mem.toBytes(ttl)[0..]);
//     @memcpy(buffer[13..17], std.mem.toBytes(@as(u32, @intCast(key.len)))[0..]);
//     @memcpy(buffer[17 .. 17 + key.len], key);
//     @memcpy(buffer[17 + key.len .. 17 + key.len + 4], std.mem.toBytes(@as(u32, @intCast(value.len)))[0..]);
//     @memcpy(buffer[17 + key.len + 4 .. 17 + key.len + 4 + value.len], value);

//     std.debug.print("buffer: {any}\n", .{buffer});

//     const result = call(hash_map, buffer);

//     std.debug.print("result: {any}\n", .{result});
// }

// test "get" {
//     std.debug.print("GET\n", .{});

//     const allocator = std.testing.allocator;
//     const hash_map = try HashMap.init(allocator, 1024);
//     defer hash_map.free();

//     const key = @as([]u8, @constCast("Hello, world!"));
//     const value = @as([]u8, @constCast("This is me, Mario!"));
//     const hash = xxhash(0, key);
//     const ttl = @as(u32, @intCast(std.time.timestamp())) + 1;

//     const buffer = try allocator.alloc(u8, 1 + 8 + key.len);
//     defer allocator.free(buffer);

//     buffer[0] = 0;

//     @memcpy(buffer[1..9], std.mem.toBytes(hash)[0..]);
//     @memcpy(buffer[9..], key);

//     std.debug.print("buffer: {any}\n", .{buffer});

//     try hash_map.put(hash, key, value, ttl);

//     const result = call(hash_map, buffer);

//     std.debug.print("result: {any}\n", .{result});
// }

// test "del" {
//     std.debug.print("DEL\n", .{});

//     const allocator = std.testing.allocator;
//     const hash_map = try HashMap.init(allocator, 1024);
//     defer hash_map.free();

//     const key = @as([]u8, @constCast("Hello, world!"));
//     const value = @as([]u8, @constCast("This is me, Mario!"));
//     const hash = xxhash(0, key);
//     const ttl = @as(u32, @intCast(std.time.timestamp())) + 1;

//     const buffer = try allocator.alloc(u8, 1 + 8 + key.len);
//     defer allocator.free(buffer);

//     buffer[0] = 2;

//     @memcpy(buffer[1..9], std.mem.toBytes(hash)[0..]);
//     @memcpy(buffer[9..], key);

//     std.debug.print("buffer: {any}\n", .{buffer});

//     try hash_map.put(hash, key, value, ttl);

//     const result = call(hash_map, buffer);

//     std.debug.print("result: {any}\n", .{result});
// }
