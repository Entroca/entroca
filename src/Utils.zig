const std = @import("std");

pub fn bitsNeeded(comptime number: usize) u16 {
    if (number == 0) return 1;
    return @bitSizeOf(@TypeOf(number)) - @clz(number);
}

pub fn closestN(comptime n: usize, comptime value: usize) usize {
    if (value % n == 0) return value;
    return value + (n - (value % n));
}

pub fn closest8(comptime value: usize) usize {
    return comptime closestN(8, value);
}

pub fn closest16(comptime value: usize) usize {
    return comptime closestN(16, value);
}

pub fn uint(comptime bits: usize, comptime padding: bool) type {
    return comptime std.meta.Int(.unsigned, switch (padding) {
        true => closest8(bits),
        false => bits,
    });
}
