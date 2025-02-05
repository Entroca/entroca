const Utils = @import("Utils.zig");
const ReadError = @import("../Utils.zig").ReadError;
const HashMap = @import("../HashMap.zig");
const Self = @This();

hash: u64,
key: []u8,
value: []u8,
ttl: ?u32,

pub const DecodeInputError = ReadError || HashMap.PutError;

pub fn decode_input(buffer: []u8) DecodeInputError!Self {
    var index: usize = 0;

    const hash = try Utils.read_hash(&index, buffer);
    const ttl = try Utils.read_ttl(&index, buffer);
    const key = try Utils.read_array(&index, buffer);
    const value = try Utils.read_array(&index, buffer);

    return Self{
        .hash = hash,
        .key = key,
        .value = value,
        .ttl = ttl,
    };
}
