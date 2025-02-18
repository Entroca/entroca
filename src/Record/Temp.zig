const std = @import("std");
const Utils = @import("../Utils.zig");
const ConfigRecord = @import("../Config/Record.zig");

pub fn Struct(comptime config_record: ConfigRecord) type {
    return struct {
        pub fn Type() type {
            return comptime Utils.uint(@bitSizeOf(config_record.temp.type), config_record.padding.internal);
        }

        pub fn default() Type() {
            return std.math.maxInt(Type()) / 2;
        }
    };
}

test "Record.Temp" {
    const expect = std.testing.expect;

    const temp = Struct(ConfigRecord.default());

    try expect(temp.Type() == u8);
    try expect(temp.default() == 127);
}
