const std = @import("std");
const Utils = @import("../Utils.zig");

pub fn read_hash(index: *usize, buffer: []u8) Utils.ReadError!u64 {
    const size = 8;

    try Utils.assert_bytes(index.*, buffer, size);

    const result = std.mem.readInt(u64, buffer[index.* .. index.* + size][0..8], .little);

    index.* += size;

    return result;
}

pub fn read_ttl(index: *usize, buffer: []u8) Utils.ReadError!?u32 {
    try Utils.assert_bytes(index.*, buffer, 1);

    if (buffer[index.*] == 0) {
        index.* += 1;

        return null;
    } else {
        const size = 5;

        try Utils.assert_bytes(index.*, buffer, size);

        const result = std.mem.readInt(u32, buffer[index.* + 1 .. index.* + size][0..4], .little);

        index.* += size;

        return result;
    }
}

pub fn read_length(index: *usize, buffer: []u8) Utils.ReadError!u32 {
    const size = 4;

    try Utils.assert_bytes(index.*, buffer, size);

    const result = std.mem.readInt(u32, buffer[index.* .. index.* + size][0..4], .little);

    index.* += size;

    return result;
}

pub fn read_array(index: *usize, buffer: []u8) Utils.ReadError![]u8 {
    const size = try read_length(index, buffer);

    try Utils.assert_bytes(index.*, buffer, size);

    const result = buffer[index.* .. index.* + size];

    index.* += size;

    return result;
}
