const std = @import("std");
const ConfigRecord = @import("../Config/Record.zig");

pub fn Struct(comptime config_record: ConfigRecord) type {
    return struct {
        pub fn Type() type {
            return comptime switch (config_record.padding.internal) {
                true => u8,
                false => u1,
            };
        }

        pub fn create(value: bool) Type() {
            return switch (value) {
                true => 1,
                false => 0,
            };
        }

        pub fn default() Type() {
            return comptime create(true);
        }
    };
}

test "Record.Empty" {
    const expect = std.testing.expect;

    const empty = Struct(ConfigRecord.default());

    try expect(empty.Type() == u1);
    try expect(empty.create(true) == 1);
    try expect(empty.create(false) == 0);
    try expect(empty.default() == 1);
}
