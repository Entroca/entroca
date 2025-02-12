const std = @import("std");
const Utils = @import("Utils.zig");
const Hash = @import("Config/Hash.zig");
const Data = @import("Config/Data.zig").Enum;
const Temperature = @import("Config/Temperature.zig");
const Padding = @import("Config/Padding.zig");
const Strategy = @import("Config/Strategy.zig").Enum;
const Features = @import("Config/Features.zig");
const Ttl = @import("Config/Ttl.zig").Enum;

const Self = @This();
const Allocator = std.mem.Allocator;

pub fn EmptyType(comptime self: Self) type {
    return comptime switch (self.padding.internal) {
        true => u8,
        false => bool,
    };
}

pub fn HashType(comptime self: Self) type {
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

pub fn ValueType(comptime self: Self) type {
    return comptime switch (self.value) {
        .static => std.meta.Int(.unsigned, switch (self.padding.internal) {
            true => Utils.closest8(self.value.max_size()),
            false => self.value.max_size(),
        } * 8),
        .dynamic => void,
    };
}

pub fn ValueLengthType(comptime self: Self) type {
    if (comptime self.key == .dynamic and self.value == .dynamic and !self.features.no_total_length) {
        return void;
    }

    const bits_needed = comptime Utils.bitsNeeded(self.value.max_size());

    return comptime switch (self.value.diff_size()) {
        0 => void,
        else => std.meta.Int(.unsigned, switch (self.padding.internal) {
            true => Utils.closest8(bits_needed),
            false => bits_needed,
        }),
    };
}

pub fn TotalLengthType(comptime self: Self) type {
    if (comptime self.features.no_total_length or self.key == .static or self.value == .static) {
        return void;
    }

    const key_length = switch (comptime self.key) {
        .static => @compileError("Key has to be dynamic"),
        .dynamic => switch (comptime self.key.diff_size()) {
            0 => 0,
            else => self.key.max_size(),
        },
    };

    const value_length = switch (comptime self.value) {
        .static => @compileError("Value has to be dynamic"),
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

pub fn DataType(comptime self: Self) type {
    if (comptime self.key == .dynamic or self.value == .dynamic) {
        return [*]u8;
    }

    return void;
}

pub fn createTotalLength(comptime self: Self, key: []u8, value: []u8) self.TotalLengthType() {
    if (comptime self.features.no_total_length or self.key == .static or self.value == .static) {
        return {};
    }

    const key_length = comptime switch (self.key) {
        .static => @compileError("Key has to be dynamic"),
        .dynamic => switch (self.key.diff_size()) {
            0 => 0,
            else => 1,
        },
    };

    const value_length = comptime switch (self.value) {
        .static => @compileError("Value has to be dynamic"),
        .dynamic => switch (self.value.diff_size()) {
            0 => 0,
            else => 1,
        },
    };

    if (comptime key_length == 0 and value_length == 0) {
        return {};
    }

    const key_length_absolute = switch (comptime self.key) {
        .static => @compileError("Key has to be dynamic"),
        .dynamic => switch (comptime self.key.diff_size()) {
            0 => 0,
            else => key.len,
        },
    };

    const value_length_absolute = switch (comptime self.value) {
        .static => @compileError("Value has to be dynamic"),
        .dynamic => switch (comptime self.value.diff_size()) {
            0 => 0,
            else => value.len,
        },
    };

    return @intCast(key_length_absolute + value_length_absolute);
}

pub fn defaultTotalLength(comptime self: Self) self.TotalLengthType() {
    if (comptime self.features.no_total_length or self.key == .static or self.value == .static) {
        return {};
    }

    const key_length = comptime switch (self.key) {
        .static => @compileError("Key has to be dynamic"),
        .dynamic => switch (self.key.diff_size()) {
            0 => 0,
            else => self.key.max_size(),
        },
    };

    const value_length = comptime switch (self.value) {
        .static => @compileError("Value has to be dynamic"),
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

pub fn TemperatureType(comptime self: Self) type {
    return self.temperature.type;
}

pub fn TtlInputType(comptime self: Self) type {
    return comptime switch (self.ttl) {
        .none => void,
        .absolute => |s| block: {
            const bits_needed = Utils.bitsNeeded(s.max_input_count);

            break :block std.meta.Int(.unsigned, switch (self.padding.internal) {
                true => Utils.closest8(bits_needed),
                false => bits_needed,
            });
        },
        .relative => |s| block: {
            const bits_needed = Utils.bitsNeeded(s.max_input_count);

            break :block std.meta.Int(.unsigned, switch (self.padding.internal) {
                true => Utils.closest8(bits_needed),
                false => bits_needed,
            });
        },
    };
}

pub fn TtlTotalType(comptime self: Self) type {
    return comptime switch (self.ttl) {
        .none => void,
        .absolute => |s| block: {
            const bits_needed = Utils.bitsNeeded(s.max_total_count);

            break :block std.meta.Int(.unsigned, switch (self.padding.internal) {
                true => Utils.closest8(bits_needed),
                false => bits_needed,
            });
        },
        .relative => |s| block: {
            const bits_needed = Utils.bitsNeeded(s.max_total_count);

            break :block std.meta.Int(.unsigned, switch (self.padding.internal) {
                true => Utils.closest8(bits_needed),
                false => bits_needed,
            });
        },
    };
}

pub fn createTtlTotal(comptime self: Self, input: self.TtlInputType()) self.TtlTotalType() {
    return switch (comptime self.ttl) {
        .none => {},
        .absolute => self.now() + @as(self.TtlTotalType(), input),
        .relative => self.now() + @as(self.TtlTotalType(), input),
    };
}

pub fn defaultTtlTotal(comptime self: Self) self.TtlTotalType() {
    return comptime switch (self.ttl) {
        .none => {},
        .absolute => std.math.maxInt(self.TtlTotalType()),
        .relative => std.math.maxInt(self.TtlTotalType()),
    };
}

pub fn now(comptime self: Self) self.TtlTotalType() {
    return switch (comptime self.ttl) {
        .none => {},
        .absolute => @intCast(std.time.timestamp()),
        .relative => @intCast(std.time.timestamp()),
    };
}

pub fn PaddingType(comptime self: Self) type {
    return comptime switch (self.padding.external) {
        true => block: {
            const empty_size = @bitSizeOf(self.EmptyType());
            const hash_size = @bitSizeOf(self.HashType());
            const key_size = @bitSizeOf(self.KeyType());
            const key_length_size = @bitSizeOf(self.KeyLengthType());
            const value_size = @bitSizeOf(self.ValueType());
            const value_length_size = @bitSizeOf(self.ValueLengthType());
            const total_length_size = @bitSizeOf(self.TotalLengthType());
            const data_size = @bitSizeOf(self.DataType());
            const temperature_size = @bitSizeOf(self.TemperatureType());

            const sum = empty_size + hash_size + key_size + key_length_size + value_size + value_length_size + total_length_size + data_size + temperature_size;

            const rounded = Utils.closest16(sum);
            const padding = rounded - sum;

            break :block std.meta.Int(.unsigned, padding);
        },
        false => void,
    };
}

pub fn defaultPadding(comptime self: Self) self.PaddingType() {
    return comptime switch (self.padding.external) {
        true => 0,
        false => {},
    };
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

pub fn defaultValueLength(comptime self: Self) self.ValueLengthType() {
    return comptime switch (self.features.no_total_length and self.key == .dynamic and self.value == .dynamic) {
        true => self.value.defaultLength(),
        false => {},
    };
}

pub fn createValueLength(comptime self: Self, value: []u8) self.ValueLengthType() {
    return switch (comptime self.features.no_total_length and self.key == .dynamic and self.value == .dynamic) {
        true => self.value.createLength(value),
        false => {},
    };
}

count: usize,
strategy: Strategy,
padding: Padding,
hash: Hash,
key: Data,
value: Data,
temperature: Temperature,
features: Features,
ttl: Ttl,
