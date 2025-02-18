const std = @import("std");
const Utils = @import("../Utils.zig");
const ConfigRecord = @import("../Config/Record.zig");

pub fn Struct(comptime config_record: ConfigRecord) type {
    return struct {
        pub fn Type() type {
            if (comptime config_record.ttl == .none) {
                return void;
            }

            return u32;
        }

        pub inline fn now() Type() {
            return switch (comptime config_record.ttl) {
                .absolute => @intCast(std.time.timestamp()),
                .none => {},
            };
        }

        pub inline fn isExpired(value: Type()) bool {
            return switch (comptime config_record.ttl) {
                .absolute => now() > value,
                .none => false,
            };
        }

        pub fn create(value: Type()) Type() {
            return switch (comptime config_record.ttl) {
                .absolute => now() + value,
                .none => {},
            };
        }

        pub fn default() Type() {
            return comptime switch (config_record.ttl) {
                .absolute => std.math.maxInt(Type()),
                .none => {},
            };
        }
    };
}

test "Record.Ttl" {
    const expect = std.testing.expect;

    const Ttl = Struct(ConfigRecord.default());
    const now = @as(u32, @intCast(std.time.timestamp()));

    try expect(Ttl.Type() == u32);
    try expect(Ttl.default() == std.math.maxInt(Ttl.Type()));

    const ttl = Ttl.create(1);
    try expect(ttl == now + 1);

    std.time.sleep(2000 * 1000000);

    try expect(Ttl.isExpired(ttl));
}
