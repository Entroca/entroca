const std = @import("std");
const Utils = @import("Utils.zig");
const Hash = @import("Config/Hash.zig");
const Data = @import("Config/Data.zig").Enum;
const Temperature = @import("Config/Temperature.zig");
const Padding = @import("Config/Padding.zig");
const Strategy = @import("Config/Strategy.zig").Enum;
const Features = @import("Config/Features.zig");

const Self = @This();
const Allocator = std.mem.Allocator;

pub fn EmptyType(comptime self: Self) type {
    return comptime switch (self.padding.internal) {
        true => u8,
        false => bool,
    };
}

pub fn HashType(self: Self) type {
    return comptime self.hash.type;
}

pub fn KeyType(comptime self: Self) type {
    return comptime switch (self.key) {
        .static => std.meta.Int(.unsigned, switch (self.padding.internal) {
            true => Utils.closest8(self.key.max_size()),
            false => self.key.max_size(),
        } * 8),
        .dynamic => void,
    };
}

pub fn KeyLengthType(comptime self: Self) type {
    const bits_needed = comptime Utils.bitsNeeded(self.key.max_size());

    return comptime switch (self.key.diff_size()) {
        0 => void,
        else => std.meta.Int(.unsigned, switch (self.padding.internal) {
            true => Utils.closest8(bits_needed),
            false => bits_needed,
        }),
    };
}

pub fn ValueType(self: Self) type {
    return comptime switch (self.value) {
        .static => std.meta.Int(.unsigned, switch (self.padding.internal) {
            true => Utils.closest8(self.value.max_size()),
            false => self.value.max_size(),
        } * 8),
        .dynamic => void,
    };
}

pub fn ValueLengthType(self: Self) type {
    const bits_needed = comptime Utils.bitsNeeded(self.value.max_size());

    return comptime switch (self.value.diff_size()) {
        0 => void,
        else => std.meta.Int(.unsigned, switch (self.padding.internal) {
            true => Utils.closest8(bits_needed),
            false => bits_needed,
        }),
    };
}

pub fn TotalLengthType(self: Self) type {
    if (comptime self.key == .static and self.value == .static) {
        return void;
    }

    const key_length = switch (comptime self.key) {
        .static => 0,
        .dynamic => switch (comptime self.key.diff_size()) {
            0 => 0,
            else => self.key.max_size(),
        },
    };

    const value_length = switch (comptime self.value) {
        .static => 0,
        .dynamic => switch (comptime self.value.diff_size()) {
            0 => 0,
            else => self.value.max_size(),
        },
    };

    if (comptime key_length == 0 and value_length == 0) {
        return void;
    }

    const bits_needed = Utils.bitsNeeded(key_length + value_length);

    return std.meta.Int(.unsigned, switch (self.padding.internal) {
        true => Utils.closest8(bits_needed),
        false => bits_needed,
    });
}

pub fn DataType(self: Self) type {
    if (comptime self.key == .dynamic or self.value == .dynamic) {
        return [*]u8;
    }

    return void;
}

pub fn createTotalLength(comptime self: Self, key: []u8, value: []u8) self.TotalLengthType() {
    if (comptime self.key == .static and self.value == .static) {
        return {};
    }

    const key_length = comptime switch (self.key) {
        .static => 0,
        .dynamic => switch (self.key.diff_size()) {
            0 => 0,
            else => 1,
        },
    };

    const value_length = comptime switch (self.value) {
        .static => 0,
        .dynamic => switch (self.value.diff_size()) {
            0 => 0,
            else => 1,
        },
    };

    if (comptime key_length == 0 and value_length == 0) {
        return {};
    }

    const key_length_absolute = switch (comptime self.key) {
        .static => 0,
        .dynamic => switch (comptime self.key.diff_size()) {
            0 => 0,
            else => key.len,
        },
    };

    const value_length_absolute = switch (comptime self.value) {
        .static => 0,
        .dynamic => switch (comptime self.value.diff_size()) {
            0 => 0,
            else => value.len,
        },
    };

    return @intCast(key_length_absolute + value_length_absolute);
}

pub fn defaultTotalLength(comptime self: Self) self.TotalLengthType() {
    if (comptime self.key == .static and self.value == .static) {
        return {};
    }

    const key_length = comptime switch (self.key) {
        .static => 0,
        .dynamic => switch (self.key.diff_size()) {
            0 => 0,
            else => self.key.max_size(),
        },
    };

    const value_length = comptime switch (self.value) {
        .static => 0,
        .dynamic => switch (self.value.diff_size()) {
            0 => 0,
            else => self.value.max_size(),
        },
    };

    if (comptime key_length == 0 and value_length == 0) {
        return {};
    }

    return 0;
}

pub fn createData(comptime self: Self, allocator: Allocator, key: []u8, value: []u8) !self.DataType() {
    if (comptime self.key == .dynamic and self.value == .dynamic) {
        const data = try allocator.alloc(u8, key.len + value.len);

        @memcpy(data[0..key.len], key);
        @memcpy(data[key.len..], value);

        return data.ptr;
    }

    if (comptime self.key == .dynamic and self.value == .static) {
        const data = try allocator.alloc(u8, key.len);

        @memcpy(data[0..], key);

        return data.ptr;
    }

    if (comptime self.key == .static and self.value == .dynamic) {
        const data = try allocator.alloc(u8, value.len);

        @memcpy(data[0..], value);

        return data.ptr;
    }

    return {};
}

pub fn defaultData(comptime self: Self) self.DataType() {
    if (comptime self.key == .dynamic or self.value == .dynamic) {
        return undefined;
    }

    return {};
}

pub fn TemperatureType(self: Self) type {
    return self.temperature.type;
}

pub fn getIndex(comptime self: Self, hash: self.hash.type) usize {
    if (comptime std.math.isPowerOfTwo(self.count)) {
        return hash & (self.count - 1);
    } else {
        return hash % self.count;
    }
}

pub fn createEmpty(comptime self: Self, value: bool) self.EmptyType() {
    return switch (comptime self.padding.internal) {
        true => if (value) 1 else 0,
        false => value,
    };
}

pub fn defaultEmpty(comptime self: Self) self.EmptyType() {
    return comptime self.createEmpty(true);
}

count: usize,
strategy: Strategy,
padding: Padding,
hash: Hash,
key: Data,
value: Data,
temperature: Temperature,
features: Features,
