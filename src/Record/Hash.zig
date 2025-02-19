const std = @import("std");
const ConfigRecord = @import("../Config/Record.zig");

pub fn Struct(comptime config_record: ConfigRecord) type {
    return struct {
        pub fn Type() type {
            return config_record.hash.type;
        }

        pub fn default() Type() {
            return 0;
        }

        pub fn byteSize() usize {
            return @sizeOf(Type());
        }

        pub fn decode(buffer: []u8, index: *usize) Type() {
            const result = std.mem.readInt(Type(), buffer[index.*..][0..comptime byteSize()], .little);

            index.* += byteSize();

            return result;
        }
    };
}

test "Record.Hash" {
    const expect = std.testing.expect;

    const hash = Struct(ConfigRecord.default());

    try expect(hash.Type() == u64);
}
