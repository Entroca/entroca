const std = @import("std");
const ConfigRecord = @import("../Config/Record.zig");
const Utils = @import("../Utils.zig");

pub fn Struct(comptime config_record: ConfigRecord) type {
    return struct {
        pub fn Type() type {
            if (!config_record.padding.external) {
                return void;
            }

            const hash_size = @bitSizeOf(config_record.HashType());
            const key_size = @bitSizeOf(config_record.KeyType());
            const key_length_size = @bitSizeOf(config_record.KeyLengthType());
            const value_size = @bitSizeOf(config_record.ValueType());
            const value_length_size = @bitSizeOf(config_record.ValueLengthType());
            const temp_size = @bitSizeOf(config_record.TempType());
            const ttl_size = @bitSizeOf(config_record.TtlType());

            const sum_raw = hash_size + key_size + key_length_size + value_size + value_length_size + temp_size + ttl_size;
            const sum_aligned = Utils.closest16(sum_raw);

            return Utils.uint(sum_aligned - sum_raw, false);
        }

        pub fn default() Type() {
            if (!config_record.padding.external) {
                return {};
            }

            return 0;
        }
    };
}

test "Record.Padding" {
    const expect = std.testing.expect;

    const padding = Struct(ConfigRecord.default());

    try expect(padding.Type() == void);
    try expect(padding.default() == {});
}
