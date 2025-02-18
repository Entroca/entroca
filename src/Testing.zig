const std = @import("std");
const Allocator = std.mem.Allocator;
const random = std.crypto.random;

pub fn randomString(allocator: Allocator, length: usize) ![]u8 {
    const string = try allocator.alloc(u8, length);

    for (0..length) |_| {
        const index = random.intRangeAtMost(usize, 0, length - 1);
        string[index] = random.intRangeAtMost(u8, 0, 255);
    }

    return string;
}
