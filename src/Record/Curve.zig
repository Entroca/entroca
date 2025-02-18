const std = @import("std");
const Config = @import("../Config.zig");

pub fn create(comptime T: type) [std.math.maxInt(T) + 1]T {
    const size = std.math.maxInt(T) + 1;
    var table: [size]T = undefined;

    for (0..size) |index| {
        const temp: f64 = @floatFromInt(index);
        const prob = @exp(-temp / 32.0);

        table[index] = @intFromFloat(prob * @as(f64, @floatFromInt(std.math.maxInt(T))));
    }

    return table;
}
