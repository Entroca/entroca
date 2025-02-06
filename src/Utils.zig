const std = @import("std");
const Config = @import("Config.zig");

pub inline fn saturating_add(comptime T: type, a: T, b: T) T {
    const result = @addWithOverflow(a, b);

    if (result[1] == 1) {
        return std.math.maxInt(T);
    }

    return result[0];
}

pub inline fn saturating_sub(comptime T: type, a: T, b: T) T {
    const result = @subWithOverflow(a, b);

    if (result[1] == 1) {
        return 0;
    }

    return result[0];
}

pub inline fn now() u32 {
    return @as(u32, @intCast(std.time.timestamp()));
}

pub inline fn memcmp(a: []u8, b: []u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn create_boltzmann_curve(comptime T: type, kT: f64) [std.math.maxInt(T) + 1]T {
    const size = std.math.maxInt(T) + 1;
    var table: [size]T = undefined;

    for (0..size) |index| {
        const temp: f64 = @floatFromInt(index);
        const prob = @exp(-temp / kT);

        table[index] = @intFromFloat(prob * @as(f64, @floatFromInt(std.math.maxInt(T))));
    }

    return table;
}

pub const ReadError = error{NotEnoughBytes};

pub fn assert_bytes(index: usize, buffer: []u8, size: usize) ReadError!void {
    if (buffer.len - index < size) {
        return error.NotEnoughBytes;
    }
}

pub fn read_hash(index: *usize, buffer: []u8) ReadError!u64 {
    const size = 8;

    try assert_bytes(index.*, buffer, size);

    const result = std.mem.readInt(u64, buffer[index.* .. index.* + size][0..8], .little);

    index.* += size;

    return result;
}

pub fn read_ttl(index: *usize, buffer: []u8) ReadError!?u32 {
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

pub fn read_length(index: *usize, buffer: []u8) ReadError!u32 {
    const size = 4;

    try assert_bytes(index.*, buffer, size);

    const result = std.mem.readInt(u32, buffer[index.* .. index.* + size][0..4], .little);

    index.* += size;

    return result;
}

pub fn read_array(index: *usize, buffer: []u8) ReadError![]u8 {
    const size = try read_length(index, buffer);

    try assert_bytes(index.*, buffer, size);

    const result = buffer[index.* .. index.* + size];

    index.* += size;

    return result;
}
