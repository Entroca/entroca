const std = @import("std");

pub fn err(e: anyerror) u8 {
    const mask = @as(u8, @intFromBool(true)) << 7;

    return mask | @as(u8, switch (e) {
        error.CommandNotFound => 0,
        error.OutOfMemory => 1,
        error.NotEnoughBytes => 2,
        error.KeyTooShort => 3,
        error.KeyTooLong => 4,
        error.ValueTooShort => 5,
        error.ValueTooLong => 6,
        error.RecordEmpty => 7,
        error.TtlExpired => 8,
        error.RecordNotFound => 9,
        else => 127,
    });
}

pub inline fn ok() u8 {
    return 0;
}
