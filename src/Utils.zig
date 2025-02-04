const std = @import("std");
const Config = @import("Config.zig");

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

pub inline fn now() u32 {
    return @as(u32, @intCast(std.time.timestamp()));
}

pub inline fn memcmp(a: []u8, b: []u8) bool {
    return std.mem.eql(u8, a, b);
}
