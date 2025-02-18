const ConfigRecord = @import("../Config/Record.zig");

pub fn Struct(comptime config_record: ConfigRecord) type {
    return struct {
        pub fn Type() type {
            return config_record.hash.type;
        }

        pub fn default() Type() {
            return 0;
        }
    };
}

test "Record.Hash" {
    const std = @import("std");
    const expect = std.testing.expect;

    const hash = Struct(ConfigRecord.default());

    try expect(hash.Type() == u64);
}
