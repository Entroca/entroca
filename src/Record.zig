const std = @import("std");
const Config = @import("Config.zig");
const Utils = @import("Utils.zig");

const Allocator = std.mem.Allocator;

pub fn create(config: Config) type {
    // TODO: make sure all fields are padded
    // and that the whole struct is padded
    return packed struct {
        const Self = @This();

        empty: bool,
        hash: config.HashType(),
        key: config.KeyType(),
        key_length: config.KeyLengthType(),
        value: config.ValueType(),
        value_length: config.ValueLengthType(),
        total_length: config.TotalLengthType(),
        data: config.DataType(),
        temperature: config.TemperatureType(),

        const CURVE = Utils.createBoltzmannCurve(config.TemperatureType(), config.boltzmann);

        pub inline fn compareHash(self: Self, hash: config.HashType()) bool {
            return self.hash == hash;
        }

        pub inline fn isEmpty(self: Self) bool {
            return self.empty == true;
        }

        pub inline fn getKeyLength(self: Self) usize {
            return switch (comptime config.key.diff_size()) {
                0 => comptime config.key.max_size(),
                else => self.key_length,
            };
        }

        pub inline fn getKey(self: Self) []u8 {
            return switch (comptime config.key) {
                .static => std.mem.asBytes(@constCast(&self.key))[0..self.getKeyLength()],
                .dynamic => self.data[0..self.getKeyLength()],
            };
        }

        pub fn compareKey(self: Self, key: []u8) bool {
            const self_key = self.getKey();

            if (self_key.len != key.len) {
                return false;
            }

            return std.mem.eql(u8, self_key, key);
        }

        pub inline fn compareHashAndKey(self: Self, hash: config.HashType(), key: []u8) bool {
            return self.compareHash(hash) and self.compareKey(key);
        }

        pub inline fn getValueLength(self: Self) usize {
            return switch (comptime config.value.diff_size()) {
                0 => comptime config.value.max_size(),
                else => self.value_length,
            };
        }

        pub inline fn getValue(self: Self) []u8 {
            return switch (comptime config.value) {
                .static => std.mem.asBytes(@constCast(&self.value))[0..self.getValueLength()],
                .dynamic => block: {
                    const start = switch (comptime config.key) {
                        .static => 0,
                        .dynamic => self.getKeyLength(),
                    };

                    break :block self.data[start .. start + self.getValueLength()];
                },
            };
        }

        pub fn compareValue(self: Self, value: []u8) bool {
            const self_value = self.getValue();

            if (self_value.len != value.len) {
                return false;
            }

            return std.mem.eql(u8, self_value, value);
        }

        pub inline fn isLucky(_: Self, random_probability: f64) bool {
            return random_probability > config.temperature.rate;
        }

        pub inline fn isUnlucky(self: Self, random_temperature: config.TemperatureType()) bool {
            return random_temperature > CURVE[self.temperature];
        }

        pub inline fn getSiblingIndex(index: usize) usize {
            return @min(index + 1, config.count - 1);
        }

        pub inline fn increaseTemperature(self: *Self) void {
            const result = @addWithOverflow(self.temperature, 1);

            self.temperature = switch (result[1]) {
                1 => std.math.maxInt(config.TemperatureType()),
                else => result[0],
            };
        }

        pub inline fn decreaseTemperature(self: *Self) void {
            const result = @subWithOverflow(self.temperature, 1);

            self.temperature = switch (result[1]) {
                1 => 0,
                else => result[0],
            };
        }

        pub fn create(allocator: Allocator, hash: config.HashType(), key: []u8, value: []u8) !Self {
            return Self{
                .empty = false,
                .hash = hash,
                .key = config.key.createValue(key),
                .key_length = config.key.createLength(key),
                .value = config.value.createValue(value),
                .value_length = config.value.createLength(value),
                .total_length = config.createTotalLength(key, value),
                .data = try config.createData(allocator, key, value),
                .temperature = config.temperature.create(),
            };
        }

        pub fn free(self: Self, allocator: Allocator) void {
            if (comptime config.key == .dynamic or config.value == .dynamic) {
                if (self.empty == false) {
                    allocator.free(self.data[0..self.total_length]);
                }
            }
        }

        pub fn default() Self {
            return Self{
                .empty = true,
                .hash = 0,
                .key = config.key.defaultValue(),
                .key_length = config.key.defaultLength(),
                .value = config.value.defaultValue(),
                .value_length = config.value.defaultLength(),
                .total_length = config.defaultTotalLength(),
                .data = config.defaultData(),
                .temperature = config.temperature.default(),
            };
        }
    };
}

// test "Record" {
//     const xxhash = std.hash.XxHash64.hash;
//     const allocator = std.testing.allocator;

//     const config = Config{
//         .hash = .{
//             .type = u64,
//         },
//         .key = .{
//             .dynamic = .{
//                 .min_size = 1,
//                 .max_size = 8,
//             },
//         },
//         .value = .{
//             .dynamic = .{
//                 .min_size = 1,
//                 .max_size = 65536,
//             },
//         },
//         .temperature = .{
//             .type = u8,
//         },
//     };
//     const Record = create(config);

//     _ = Record.default();

//     const key_bytes = @as([]u8, @constCast("hello")[0..]);
//     const value_bytes = @as([]u8, @constCast("world")[0..]);
//     std.debug.print("key: {any}\n", .{key_bytes});
//     std.debug.print("value: {any}\n", .{value_bytes});

//     const hash = xxhash(0, key_bytes);
//     const record = try Record.create(allocator, hash, key_bytes, value_bytes);
//     defer allocator.free(record.data[0..record.total_length]);

//     std.debug.print("Record key: {}\n", .{record.key});
//     std.debug.print("getKey() result: {any}\n", .{record.getKey()});
//     std.debug.print("Record value: {}\n", .{record.value});
//     std.debug.print("getValue() result: {any}\n", .{record.getValue()});
// }
