const std = @import("std");

const Boltzmann = struct {
    const Self = @This();

    constant: f64,

    pub fn createCurve(comptime self: Self, comptime T: type) [std.math.maxInt(T) + 1]T {
        const size = std.math.maxInt(T) + 1;
        var table: [size]T = undefined;

        for (0..size) |index| {
            const temp: f64 = @floatFromInt(index);
            const prob = @exp(-temp / self.constant);

            table[index] = @intFromFloat(prob * @as(f64, @floatFromInt(std.math.maxInt(T))));
        }

        return table;
    }
};

const Linear = struct {
    const Self = @This();

    pub fn createCurve(comptime _: Self, comptime T: type) [std.math.maxInt(T) + 1]T {
        const size = std.math.maxInt(T) + 1;
        var table: [size]T = undefined;

        for (0..size) |index| {
            table[index] = @intCast(index);
        }

        return table;
    }
};

const Exponential = struct {
    const Self = @This();

    constant: f64,

    pub fn createCurve(comptime self: Self, comptime T: type) [std.math.maxInt(T) + 1]T {
        const size = std.math.maxInt(T) + 1;
        var table: [size]T = undefined;
        const max_T_f64 = @as(f64, @floatFromInt(std.math.maxInt(T)));

        for (0..size) |index| {
            const temp: f64 = @floatFromInt(index);
            const prob = 1.0 - @exp(-temp / self.constant);
            const value = prob * max_T_f64;

            table[index] = @intFromFloat(value);
        }

        return table;
    }
};

pub const Enum = union(enum) {
    const Self = @This();

    boltzmann: Boltzmann,
    linear: Linear,
    exponential: Exponential,

    pub fn createCurve(comptime self: Self, comptime T: type) [std.math.maxInt(T) + 1]T {
        return comptime switch (self) {
            .boltzmann => |s| s.createCurve(T),
            .linear => |s| s.createCurve(T),
            .exponential => |s| s.createCurve(T),
        };
    }
};
