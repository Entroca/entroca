const std = @import("std");

pub fn bitsNeeded(comptime number: usize) u16 {
    if (number == 0) return 1;
    return @bitSizeOf(@TypeOf(number)) - @clz(number);
}

pub fn isPowerOfTwo(n: usize) bool {
    return n != 0 and (n & (n - 1)) == 0;
}

pub fn createBoltzmannCurve(comptime T: type, kT: f64) [std.math.maxInt(T) + 1]T {
    const size = std.math.maxInt(T) + 1;
    var table: [size]T = undefined;

    for (0..size) |index| {
        const temp: f64 = @floatFromInt(index);
        const prob = @exp(-temp / kT);

        table[index] = @intFromFloat(prob * @as(f64, @floatFromInt(std.math.maxInt(T))));
    }

    return table;
}
