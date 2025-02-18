const std = @import("std");
const Utils = @import("../Utils.zig");
const ConfigRecord = @import("../Config/Record.zig");
const ConfigData = @import("../Config/Record/Data.zig").Enum;

pub fn Struct(config_record: ConfigRecord, config_data: ConfigData) type {
    return struct {
        pub fn minSize() usize {
            return comptime switch (config_data) {
                .static => |v| v.min_size,
                .dynamic => |v| v.min_size,
            };
        }

        pub fn maxSize() usize {
            return comptime switch (config_data) {
                .static => |v| v.max_size,
                .dynamic => |v| v.max_size,
            };
        }

        pub fn isFixed() bool {
            return comptime minSize() == maxSize();
        }

        pub fn Type() type {
            if (comptime isFixed()) {
                return void;
            }

            return comptime Utils.uint(Utils.bitsNeeded(maxSize()), config_record.padding.internal);
        }

        pub fn create(value: anytype) Type() {
            if (comptime isFixed()) {
                return {};
            }

            return @intCast(value);
        }

        pub fn default() Type() {
            return create(0);
        }

        pub inline fn get(length: Type()) usize {
            return switch (comptime isFixed()) {
                true => comptime maxSize(),
                else => @intCast(length),
            };
        }
    };
}

test "Record.DataLength" {
    const expect = std.testing.expect;

    const key_length = Struct(ConfigRecord.default(), ConfigRecord.default().key);

    try expect(key_length.Type() == u4);
    try expect(key_length.create(8) == 8);
    try expect(key_length.default() == 0);
}
