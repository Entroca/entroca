const std = @import("std");

pub inline fn saturating_add(comptime T: type, a: T, b: T) T {
    const result = @addWithOverflow(a, b);

    if (result[1] == 1) {
        return std.math.maxInt(T);
    }

    return result[0];
}

pub inline fn saturating_sub(comptime T: type, a: T, b: T) T {
    const result = @subWithOverflow(a, b);

    if (result[1] == 1) {
        return 0;
    }

    return result[0];
}
