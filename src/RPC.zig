const std = @import("std");
const Config = @import("Config.zig");
const HashMap = @import("HashMap.zig");
const Utils = @import("Utils.zig");
const Result = @import("Result.zig");

const Allocator = std.mem.Allocator;
const Self = @This();

hash_map: HashMap,

pub fn init(allocator: Allocator, config: Config) !Self {
    const hash_map = try HashMap.init(allocator, config);

    return Self{
        .hash_map = hash_map,
    };
}

pub fn deinit(self: Self) void {
    self.hash_map.deinit();
}

pub fn call(self: Self, input_buffer: []u8, output_buffer: []u8) []u8 {
    Utils.assert_bytes(0, input_buffer, 14) catch |e| {
        output_buffer[0] = Result.err(e);
        return output_buffer[0..1];
    };

    const command = input_buffer[0];

    return switch (command) {
        0 => put: {
            _ = self.hash_map.put(input_buffer[1..]) catch |e| {
                output_buffer[0] = Result.err(e);
                break :put output_buffer[0..1];
            };

            output_buffer[0] = Result.ok();
            break :put output_buffer[0..1];
        },
        1 => get: {
            const output = self.hash_map.get(input_buffer[1..]) catch |e| {
                output_buffer[0] = Result.err(e);
                break :get output_buffer[0..1];
            };

            output_buffer[0] = Result.ok();
            @memcpy(output_buffer[1..output.len], output);

            break :get output_buffer[0 .. 1 + output.len];
        },
        2 => del: {
            _ = self.hash_map.del(input_buffer[1..]) catch |e| {
                output_buffer[0] = Result.err(e);
                break :del output_buffer[0..1];
            };

            output_buffer[0] = Result.ok();
            break :del output_buffer[0..1];
        },
        else => unknown: {
            output_buffer[0] = Result.err(error.CommandNotFound);
            break :unknown output_buffer[0..1];
        },
    };
}
