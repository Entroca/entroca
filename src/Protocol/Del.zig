const Utils = @import("Utils.zig");
const ReadError = @import("../Utils.zig").ReadError;
const HashMap = @import("../HashMap.zig");
const Self = @This();

hash: u64,
key: []u8,

pub const DecodeInputError = ReadError || HashMap.DelError;

pub fn decode_input(buffer: []u8) DecodeInputError!Self {
    var index: usize = 0;

    const hash = try Utils.read_hash(&index, buffer);
    const key = try Utils.read_array(&index, buffer);

    return Self{
        .hash = hash,
        .key = key,
    };
}
