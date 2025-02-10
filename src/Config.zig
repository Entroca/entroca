const std = @import("std");
const Utils = @import("Utils.zig");

const Self = @This();
const Allocator = std.mem.Allocator;

const Hash = struct {
    type: type,
};

const Temperature = struct {
    type: type,
    rate: f64,

    pub fn create(comptime self: Temperature) self.type {
        return std.math.maxInt(self.type) / 2;
    }

    pub fn default(comptime self: Temperature) self.type {
        return 0;
    }
};

const Size = struct {
    min_size: usize,
    max_size: usize,
};

const Data = union(enum) {
    static: Size,
    dynamic: Size,

    pub fn min_size(comptime self: Data) usize {
        return switch (comptime self) {
            .static => |s| s.min_size,
            .dynamic => |s| s.min_size,
        };
    }

    pub fn max_size(comptime self: Data) usize {
        return switch (comptime self) {
            .static => |s| s.max_size,
            .dynamic => |s| s.max_size,
        };
    }

    pub fn diff_size(comptime self: Data) usize {
        return comptime (self.max_size() - self.min_size());
    }

    fn AbsoluteValueType(comptime self: Data) type {
        return std.meta.Int(.unsigned, comptime self.max_size() * 8);
    }

    pub fn ValueType(comptime self: Data) type {
        return switch (comptime self) {
            .static => comptime self.AbsoluteValueType(),
            .dynamic => void,
        };
    }

    fn AbsoluteLengthType(comptime self: Data) type {
        return std.meta.Int(.unsigned, Utils.bitsNeeded(comptime self.max_size()));
    }

    pub fn LengthType(comptime self: Data) type {
        return switch (comptime self) {
            .static => switch (comptime self.diff_size()) {
                0 => void,
                else => comptime self.AbsoluteLengthType(),
            },
            .dynamic => comptime self.AbsoluteLengthType(),
        };
    }

    pub inline fn createValue(comptime self: Data, data: []u8) self.ValueType() {
        return switch (comptime self) {
            .static => std.mem.bytesToValue(comptime self.ValueType(), data),
            .dynamic => {},
        };
    }

    pub inline fn defaultValue(comptime self: Data) self.ValueType() {
        return switch (comptime self) {
            .static => 0,
            .dynamic => {},
        };
    }

    pub inline fn createLength(comptime self: Data, data: []u8) self.LengthType() {
        return switch (comptime self.diff_size()) {
            0 => {},
            else => @intCast(data.len),
        };
    }

    pub inline fn defaultLength(comptime self: Data) self.LengthType() {
        return switch (comptime self.diff_size()) {
            0 => {},
            else => 0,
        };
    }
};

pub fn HashType(self: Self) type {
    return comptime self.hash.type;
}

pub fn KeyType(self: Self) type {
    return comptime self.key.ValueType();
}

pub fn KeyLengthType(self: Self) type {
    return comptime self.key.LengthType();
}

pub fn ValueType(self: Self) type {
    return comptime self.value.ValueType();
}

pub fn ValueLengthType(self: Self) type {
    return comptime self.value.LengthType();
}

pub fn TotalLengthType(self: Self) type {
    if (comptime self.key == .dynamic or self.value == .dynamic) {
        const key_size = switch (self.key.diff_size()) {
            0 => 0,
            else => self.key.max_size(),
        };

        const value_size = switch (self.value.diff_size()) {
            0 => 0,
            else => self.value.max_size(),
        };

        return std.meta.Int(.unsigned, Utils.bitsNeeded(key_size + value_size));
    }

    return void;
}

pub fn createTotalLength(comptime self: Self, key: []u8, value: []u8) self.TotalLengthType() {
    if (comptime self.key == .dynamic or self.value == .dynamic) {
        const key_length = switch (comptime self.key == .dynamic) {
            true => key.len,
            false => 0,
        };

        const value_length = switch (comptime self.value == .dynamic) {
            true => value.len,
            false => 0,
        };

        return @intCast(key_length + value_length);
    }

    return {};
}

pub fn defaultTotalLength(comptime self: Self) self.TotalLengthType() {
    if (comptime self.key == .dynamic or self.value == .dynamic) {
        return 0;
    }

    return {};
}

pub fn DataType(self: Self) type {
    if (comptime self.key == .dynamic or self.value == .dynamic) {
        return [*]u8;
    }

    return void;
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
    if (comptime Utils.isPowerOfTwo(self.count)) {
        return hash & (self.count - 1);
    } else {
        return hash % self.count;
    }
}

count: usize,
boltzmann: f64,
hash: Hash,
key: Data,
value: Data,
temperature: Temperature,
