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

        pub fn assertSize(length: usize) !void {
            if (length < minSize()) {
                return error.DataTooSmall;
            }

            if (length > maxSize()) {
                return error.DataTooLarge;
            }
        }

        pub fn Type() type {
            if (comptime config_data == .dynamic) {
                return void;
            }

            return comptime Utils.uint(maxSize() * 8, config_record.padding.internal);
        }

        pub fn create(value: []u8) Type() {
            if (comptime config_data == .dynamic) {
                return {};
            }

            return std.mem.bytesToValue(Type(), value);
        }

        pub fn default() Type() {
            if (comptime config_data == .dynamic) {
                return {};
            }

            return 0;
        }

        pub inline fn get(data: [*]u8, value: Type(), length: usize) []u8 {
            return switch (comptime config_data) {
                .static => block: {
                    var _value = value;
                    break :block std.mem.asBytes(&_value)[0..length];
                },
                .dynamic => data[0..length],
            };
        }
    };
}

test "Record.DataValue" {
    const Testing = @import("../Testing.zig");
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    const Key = Struct(ConfigRecord.default(), ConfigRecord.default().key);
    const key_bytes = try Testing.randomString(allocator, 5);
    const key_value = std.mem.bytesToValue(Key.Type(), key_bytes);

    try expect(Key.Type() == u64);
    try expect(Key.create(key_bytes) == key_value);
    try expect(Key.default() == 0);

    allocator.free(key_bytes);
}
