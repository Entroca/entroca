const std = @import("std");

const Allocator = std.mem.Allocator;
const random = std.crypto.random;

const Self = @This();

allocator: Allocator,
array: []u32,
index: usize,
size: usize,

pub fn init(allocator: Allocator, size: u32) !Self {
    if (size == 0) @panic("Size cannot be zero");

    const array = try allocator.alloc(u32, size);

    for (0..size) |i| {
        array[i] = random.intRangeAtMost(u32, 0, size);
    }

    return Self{
        .allocator = allocator,
        .array = array,
        .index = 0,
        .size = size,
    };
}

pub fn next(self: *Self) u32 {
    const result = self.array[self.index];

    self.index = (self.index + 1) % self.size;

    return result;
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.array);
}
