const std = @import("std");
const Config = @import("Config.zig");
const HashMap = @import("HashMap.zig");
const Protocol = @import("Protocol.zig");
const Utils = @import("Utils.zig");

const Allocator = std.mem.Allocator;
const Self = @This();

hash_map: HashMap,

pub const PutError = Protocol.Put.DecodeInputError;
pub const GetError = Protocol.Get.DecodeInputError;
pub const DelError = Protocol.Del.DecodeInputError;

pub fn init(allocator: Allocator, config: Config) !Self {
    const hash_map = try HashMap.init(allocator, config);

    return Self{
        .hash_map = hash_map,
    };
}

pub fn deinit(self: Self) void {
    self.hash_map.deinit();
}

pub fn call(self: Self, input_buffer: []u8, output_buffer: *[]u8) !usize {
    const command = input_buffer[0];

    if (command == 0) {
        const data = try Protocol.Put.decode_input(input_buffer[1..]);
        const output = try self.hash_map.put(data);
        const written = try Protocol.Put.encode_output(output, output_buffer);

        return written;
    }
}
