const std = @import("std");

pub fn bitsNeeded(comptime number: usize) u16 {
    if (number == 0) return 1;
    return @bitSizeOf(@TypeOf(number)) - @clz(number);
}

pub fn isPowerOfTwo(n: usize) bool {
    return n != 0 and (n & (n - 1)) == 0;
}
