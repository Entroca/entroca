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

pub const Enum = union(enum) {
    const Self = @This();

    boltzmann: Boltzmann,

    pub fn createCurve(comptime self: Self, comptime T: type) [std.math.maxInt(T) + 1]T {
        return comptime switch (self) {
            .boltzmann => |s| s.createCurve(T),
        };
    }
};
