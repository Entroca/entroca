const std = @import("std");
const Utils = @import("../Utils.zig");
const Size = @import("Size.zig");

pub const Enum = union(enum) {
    const Self = @This();

    static: Size,
    dynamic: Size,

    pub fn min_size(comptime self: Self) usize {
        return comptime switch (self) {
            .static => |s| s.min_size,
            .dynamic => |s| s.min_size,
        };
    }

    pub fn max_size(comptime self: Self) usize {
        return comptime switch (self) {
            .static => |s| s.max_size,
            .dynamic => |s| s.max_size,
        };
    }

    pub fn diff_size(comptime self: Self) usize {
        return comptime (self.max_size() - self.min_size());
    }

    pub fn assertSize(comptime self: Self, data: []u8, short_err: anyerror, long_err: anyerror) !void {
        if (data.len < comptime self.min_size()) {
            return short_err;
        }

        if (data.len > comptime self.max_size()) {
            return long_err;
        }
    }

    fn AbsoluteValueType(comptime self: Self) type {
        return std.meta.Int(.unsigned, comptime self.max_size() * 8);
    }

    pub fn ValueType(comptime self: Self) type {
        return switch (comptime self) {
            .static => comptime self.AbsoluteValueType(),
            .dynamic => void,
        };
    }

    fn AbsoluteLengthType(comptime self: Self) type {
        return std.meta.Int(.unsigned, Utils.bitsNeeded(comptime self.max_size()));
    }

    pub fn LengthType(comptime self: Self) type {
        return switch (comptime self.diff_size()) {
            0 => void,
            else => comptime self.AbsoluteLengthType(),
        };
    }

    pub inline fn createValue(comptime self: Self, data: []u8) self.ValueType() {
        return switch (comptime self) {
            .static => std.mem.bytesToValue(comptime self.ValueType(), data),
            .dynamic => {},
        };
    }

    pub inline fn defaultValue(comptime self: Self) self.ValueType() {
        return switch (comptime self) {
            .static => 0,
            .dynamic => {},
        };
    }

    pub inline fn createLength(comptime self: Self, data: []u8) self.LengthType() {
        return switch (comptime self.diff_size()) {
            0 => {},
            else => @intCast(data.len),
        };
    }

    pub inline fn defaultLength(comptime self: Self) self.LengthType() {
        return switch (comptime self.diff_size()) {
            0 => {},
            else => 0,
        };
    }
};
