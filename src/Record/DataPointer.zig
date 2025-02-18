const std = @import("std");
const ConfigRecord = @import("../Config/Record.zig");

const Allocator = std.mem.Allocator;

pub fn Struct(config_record: ConfigRecord) type {
    return struct {
        pub fn Type() type {
            if (config_record.key == .static and config_record.value == .static) {
                return void;
            }

            return [*]u8;
        }

        pub fn create(allocator: Allocator, key: []u8, value: []u8) !Type() {
            if (config_record.key == .static and config_record.value == .static) {
                return {};
            }

            if (config_record.key == .dynamic and config_record.value == .static) {
                const data = try allocator.alloc(u8, key.len);

                @memcpy(data, key);

                return data.ptr;
            }

            if (config_record.key == .static and config_record.value == .dynamic) {
                const data = try allocator.alloc(u8, value.len);

                @memcpy(data, value);

                return data.ptr;
            }

            if (config_record.key == .dynamic and config_record.value == .dynamic) {
                const data = try allocator.alloc(u8, key.len + value.len);

                @memcpy(data[0..key.len], key);
                @memcpy(data[key.len..], value);

                return data.ptr;
            }
        }

        pub fn default() Type() {
            if (config_record.key == .static and config_record.value == .static) {
                return {};
            }

            return undefined;
        }

        pub inline fn free(allocator: Allocator, is_empty: bool, data: [*]u8, key_length: usize, value_length: usize) void {
            if (config_record.key == .static and config_record.value == .static) {
                return {};
            } else if (!is_empty) {
                if (config_record.key == .dynamic and config_record.value == .static) {
                    allocator.free(data[0..key_length]);
                }

                if (config_record.key == .static and config_record.value == .dynamic) {
                    allocator.free(data[0..value_length]);
                }

                if (config_record.key == .dynamic and config_record.value == .dynamic) {
                    allocator.free(data[0 .. key_length + value_length]);
                }
            }
        }
    };
}

test "Record.DataPointer" {
    const expect = std.testing.expect;

    const key_length = Struct(ConfigRecord.default());

    try expect(key_length.Type() == [*]u8);
}
