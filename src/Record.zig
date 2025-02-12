const std = @import("std");
const Config = @import("Config.zig");
const Utils = @import("Utils.zig");

const Allocator = std.mem.Allocator;

pub fn create(comptime config: Config) type {
    return packed struct {
        const Self = @This();

        empty: config.EmptyType(),
        hash: config.HashType(),
        key: config.KeyType(),
        key_length: config.KeyLengthType(),
        value: config.ValueType(),
        value_length: config.ValueLengthType(),
        total_length: config.TotalLengthType(),
        data: config.DataType(),
        temperature: config.TemperatureType(),
        ttl: config.TtlTotalType(),
        padding: config.PaddingType(),

        const CURVE = config.strategy.createCurve(config.TemperatureType());

        pub inline fn compareHash(self: Self, hash: config.HashType()) bool {
            return self.hash == hash;
        }

        pub inline fn isEmpty(self: Self) bool {
            return self.empty == comptime switch (config.padding.internal) {
                true => 1,
                false => true,
            };
        }

        pub inline fn getKeyLength(self: Self) usize {
            return switch (comptime config.key.diff_size()) {
                0 => comptime config.key.max_size(),
                else => self.key_length,
            };
        }

        pub inline fn getKey(self: Self) []u8 {
            return switch (comptime config.key) {
                .static => block: {
                    var key = self.key;
                    break :block std.mem.asBytes(&key)[0..self.getKeyLength()];
                },
                .dynamic => self.data[0..self.getKeyLength()],
            };
        }

        pub inline fn compareKey(self: Self, key: []u8) bool {
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
            if (comptime config.key == .dynamic and config.value == .dynamic and !config.features.no_total_length) {
                return switch (comptime config.value.diff_size()) {
                    0 => comptime config.value.max_size(),
                    else => self.total_length,
                };
            }

            return switch (comptime config.value.diff_size()) {
                0 => comptime config.value.max_size(),
                else => self.value_length,
            };
        }

        pub inline fn getValue(self: Self) []u8 {
            return switch (comptime config.value) {
                .static => block: {
                    var value = self.value;
                    break :block std.mem.asBytes(&value)[0..self.getValueLength()];
                },
                .dynamic => block: {
                    const start = switch (comptime config.key) {
                        .static => 0,
                        .dynamic => self.getKeyLength(),
                    };

                    break :block self.data[start..self.getTotalLength()];
                },
            };
        }

        pub inline fn compareValue(self: Self, value: []u8) bool {
            const self_value = self.getValue();

            if (self_value.len != value.len) {
                return false;
            }

            return std.mem.eql(u8, self_value, value);
        }

        pub inline fn getTotalLength(self: Self) usize {
            if (comptime config.key == .static and config.value == .static) {
                @compileError("To use getTotalLength at least one of key/value has to be .dynamic");
            }

            if (comptime config.key == .dynamic and config.value == .dynamic) {
                if (comptime config.features.no_total_length) {
                    return self.getKeyLength() + self.getValueLength();
                } else {
                    return self.total_length;
                }
            }

            const key_length = switch (comptime config.key) {
                .static => 0,
                .dynamic => self.getKeyLength(),
            };

            const value_length = switch (comptime config.value) {
                .static => 0,
                .dynamic => self.getValueLength(),
            };

            return key_length + value_length;
        }

        pub inline fn isLucky(_: Self, hash_map: anytype) bool {
            var random = hash_map.random;

            return random.probability() > config.temperature.rate;
        }

        pub inline fn isUnlucky(self: Self, hash_map: anytype) bool {
            var random = hash_map.random;

            return random.temperature() > CURVE[self.temperature];
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

        pub fn isExpired(self: Self) bool {
            return switch (comptime config.ttl) {
                .none => false,
                .absolute => config.now() > self.ttl,
                .relative => config.now() > self.ttl,
            };
        }

        pub fn create(allocator: Allocator, hash: config.HashType(), key: []u8, value: []u8, ttl: config.TtlInputType()) !Self {
            return Self{
                .empty = config.createEmpty(false),
                .hash = hash,
                .key = config.key.createValue(key),
                .key_length = config.key.createLength(key),
                .value = config.value.createValue(value),
                .value_length = config.createValueLength(value),
                .total_length = config.createTotalLength(key, value),
                .data = try config.createData(allocator, key, value),
                .temperature = config.temperature.create(),
                .ttl = config.createTtlTotal(ttl),
                .padding = config.defaultPadding(),
            };
        }

        pub fn free(self: Self, allocator: Allocator) void {
            if (comptime config.key == .dynamic or config.value == .dynamic) {
                if (!self.isEmpty()) {
                    allocator.free(self.data[0..self.getTotalLength()]);
                }
            }
        }

        pub fn default() Self {
            return Self{
                .empty = config.defaultEmpty(),
                .hash = 0,
                .key = config.key.defaultValue(),
                .key_length = config.key.defaultLength(),
                .value = config.value.defaultValue(),
                .value_length = config.defaultValueLength(),
                .total_length = config.defaultTotalLength(),
                .data = config.defaultData(),
                .temperature = config.temperature.default(),
                .ttl = config.defaultTtlTotal(),
                .padding = config.defaultPadding(),
            };
        }
    };
}
