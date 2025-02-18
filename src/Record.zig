const std = @import("std");
const Config = @import("Config.zig");
const ConfigRecord = @import("Config/Record.zig");
const createEmpty = @import("Record/Empty.zig").Struct;
const createHash = @import("Record/Hash.zig").Struct;
const createDataValue = @import("Record/DataValue.zig").Struct;
const createDataLength = @import("Record/DataLength.zig").Struct;
const createDataPointer = @import("Record/DataPointer.zig").Struct;
const createTemp = @import("Record/Temp.zig").Struct;
const createTtl = @import("Record/Ttl.zig").Struct;
const createPadding = @import("Record/Padding.zig").Struct;
const Curve = @import("Record/Curve.zig");

const Allocator = std.mem.Allocator;

pub fn Struct(config: Config) type {
    const Empty = createEmpty(config.record);
    const Hash = createHash(config.record);
    const Key = createDataValue(config.record, config.record.key);
    const KeyLength = createDataLength(config.record, config.record.key);
    const Value = createDataValue(config.record, config.record.value);
    const ValueLength = createDataLength(config.record, config.record.value);
    const Data = createDataPointer(config.record);
    const Temp = createTemp(config.record);
    const Ttl = createTtl(config.record);
    const Padding = createPadding(config.record);

    return packed struct {
        const Self = @This();

        empty: Empty.Type(),
        hash: Hash.Type(),
        key: Key.Type(),
        key_length: KeyLength.Type(),
        value: Value.Type(),
        value_length: ValueLength.Type(),
        data: Data.Type(),
        temp: Temp.Type(),
        ttl: Ttl.Type(),
        padding: Padding.Type(),

        const CURVE = Curve.create(Temp.Type());

        pub inline fn isEmpty(self: *const Self) bool {
            return self.empty == 1;
        }

        pub inline fn isExpired(self: *const Self) bool {
            return Ttl.isExpired(self.ttl);
        }

        pub inline fn compareHash(self: *const Self, hash: Hash.Type()) bool {
            return self.hash == hash;
        }

        pub inline fn getKey(self: *const Self) []u8 {
            return Key.get(self.data, self.key, KeyLength.get(self.key_length));
        }

        pub fn compareKey(self: *const Self, key: []u8) bool {
            return std.mem.eql(u8, self.getKey(), key);
        }

        pub fn matches(self: *const Self, hash: Hash.Type(), key: []u8) bool {
            return self.compareHash(hash) and self.compareKey(key);
        }

        pub fn shouldWarmUp(probability: f64) bool {
            return probability < config.record.temp.rate;
        }

        pub fn shouldRewrite(self: *const Self, random_temperature: Temp.Type()) bool {
            return random_temperature > CURVE[self.temp];
        }

        pub fn siblingIndex(index: usize) usize {
            return @min(index + 1, config.cache.count - 1);
        }

        pub fn increaseTemperature(self: *Self) void {
            const result = @addWithOverflow(self.temp, 1);

            self.temp = switch (result[1]) {
                1 => std.math.maxInt(config.record.temp.type),
                else => result[0],
            };
        }

        pub fn decreaseTemperature(self: *Self) void {
            const result = @subWithOverflow(self.temp, 1);

            self.temp = switch (result[1]) {
                1 => 0,
                else => result[0],
            };
        }

        pub inline fn getValue(self: *const Self) []u8 {
            return Value.get(self.data, self.value, ValueLength.get(self.value_length));
        }

        pub fn compareValue(self: *const Self, value: []u8) bool {
            return std.mem.eql(u8, self.getValue(), value);
        }

        pub fn free(self: *const Self, allocator: Allocator) void {
            return Data.free(allocator, self.isEmpty(), self.data, KeyLength.get(self.key_length), ValueLength.get(self.value_length));
        }

        pub inline fn create(allocator: Allocator, hash: Hash.Type(), key: []u8, value: []u8, ttl: Ttl.Type()) !Self {
            return Self{
                .empty = Empty.create(false),
                .hash = hash,
                .key = Key.create(key),
                .key_length = KeyLength.create(key.len),
                .value = Value.create(value),
                .value_length = ValueLength.create(value.len),
                .data = try Data.create(allocator, key, value),
                .temp = Temp.default(),
                .ttl = Ttl.create(ttl),
                .padding = Padding.default(),
            };
        }

        pub inline fn default() Self {
            return Self{
                .empty = Empty.default(),
                .hash = Hash.default(),
                .key = Key.default(),
                .key_length = KeyLength.default(),
                .value = Value.default(),
                .value_length = ValueLength.default(),
                .data = Data.default(),
                .temp = Temp.default(),
                .ttl = Ttl.default(),
                .padding = Padding.default(),
            };
        }
    };
}

test "Record" {
    _ = @import("Record/Empty.zig");
    _ = @import("Record/Hash.zig");
    _ = @import("Record/DataValue.zig");
    _ = @import("Record/DataLength.zig");
    _ = @import("Record/DataPointer.zig");
    _ = @import("Record/Temp.zig");
    _ = @import("Record/Ttl.zig");
    _ = @import("Record/Padding.zig");

    const Testing = @import("Testing.zig");
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    const xxhash = std.hash.XxHash64.hash;

    const Record = Struct(Config.default());

    const key = try Testing.randomString(allocator, 5);
    defer allocator.free(key);
    const value = try Testing.randomString(allocator, 5);
    defer allocator.free(value);
    const hash = xxhash(0, key);

    const record = try Record.create(allocator, hash, key, value, 1);
    defer allocator.free(record.data[0..5]);

    try expect(record.compareHash(hash));
    try expect(std.mem.eql(u8, key, record.getKey()));
    try expect(record.compareKey(key));
    try expect(std.mem.eql(u8, value, record.getValue()));
    try expect(record.compareValue(value));
}
