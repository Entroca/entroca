const std = @import("std");

const Allocator = std.mem.Allocator;
const random = std.crypto.random;

const Self = @This();

allocator: Allocator,
array: []u8,
index: usize,
size: usize,

pub fn init(allocator: Allocator, size: usize) !Self {
    if (size == 0) @panic("Size cannot be zero");

    const array = try allocator.alloc(u8, size);

    for (0..size) |i| {
        array[i] = random.intRangeAtMost(u8, 0, std.math.maxInt(u8));
    }

    return Self{
        .allocator = allocator,
        .array = array,
        .index = 0,
        .size = size,
    };
}

pub fn next(self: *Self) u8 {
    const result = self.array[self.index];

    self.index = (self.index + 1) % self.size;

    return result;
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.array);
}
