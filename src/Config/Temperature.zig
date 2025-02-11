const std = @import("std");

const Self = @This();

type: type,
rate: f64,

pub fn create(comptime self: Self) self.type {
    return std.math.maxInt(self.type) / 2;
}

pub fn default(comptime self: Self) self.type {
    return 0;
}
