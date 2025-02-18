const std = @import("std");
const Config = @import("Config.zig");
const createRandom = @import("Random.zig").Struct;
const createRecord = @import("Record.zig").Struct;
const createHash = @import("Record/Hash.zig").Struct;
const createData = @import("Record/DataValue.zig").Struct;
const createTtl = @import("Record/Ttl.zig").Struct;

const Allocator = std.mem.Allocator;

pub fn Struct(comptime config: Config, allocator: Allocator) type {
    const Random = createRandom(config);
    const Record = createRecord(config);
    const Hash = createHash(config.record);
    const Key = createData(config.record, config.record.key);
    const Value = createData(config.record, config.record.value);
    const Ttl = createTtl(config.record);

    return struct {
        const Self = @This();

        allocator: Allocator,
        records: []Record,
        random: Random,

        pub fn init() !Self {
            const records = try allocator.alloc(Record, config.cache.count);

            for (0..config.cache.count) |index| {
                records[index] = Record.default();
            }

            const random = try Random.init(allocator);

            return Self{
                .allocator = allocator,
                .records = records,
                .random = random,
            };
        }

        pub fn deinit(self: *const Self) void {
            if (config.record.key == .dynamic or config.record.value == .dynamic) {
                for (0..config.cache.count) |index| {
                    self.records[index].free(self.allocator);
                }
            }

            self.allocator.free(self.records);
            self.random.deinit();
        }

        inline fn assertKeySize(length: usize) !void {
            Key.assertSize(length) catch |e| {
                return switch (e) {
                    error.DataTooSmall => error.KeyTooSmall,
                    error.DataTooLarge => error.KeyTooLarge,
                };
            };
        }

        inline fn assertValueSize(length: usize) !void {
            Value.assertSize(length) catch |e| {
                return switch (e) {
                    error.DataTooSmall => error.ValueTooSmall,
                    error.DataTooLarge => error.ValueTooLarge,
                };
            };
        }

        inline fn getIndex(hash: Hash.Type()) usize {
            if (comptime std.math.isPowerOfTwo(config.cache.count)) {
                return hash & (comptime config.cache.count - 1);
            } else {
                return hash % comptime config.cache.count;
            }
        }

        pub fn put(self: *const Self, hash: Hash.Type(), key: []u8, value: []u8, ttl: Ttl.Type()) !void {
            try assertKeySize(key.len);
            try assertValueSize(value.len);

            const index = getIndex(hash);
            const record = self.records[index];

            if (record.isEmpty() or record.matches(hash, key)) {
                const new_record = try Record.create(self.allocator, hash, key, value, ttl);

                self.records[index].free(self.allocator);
                self.records[index] = new_record;

                return {};
            }

            return error.NotFound;
        }

        pub fn get(self: *const Self, hash: Hash.Type(), key: []u8, output_buffer: []u8) ![]u8 {
            try assertKeySize(key.len);

            const index = getIndex(hash);
            const record = self.records[index];

            if (!record.isEmpty() and record.matches(hash, key)) {
                if (Record.shouldWarmUp(block: {
                    var random = self.random;
                    break :block random.probability();
                })) {
                    self.records[index].increaseTemperature();
                    self.records[Record.siblingIndex(index)].decreaseTemperature();
                }

                const value = record.getValue();

                @memcpy(output_buffer[0..value.len], value);

                return output_buffer[0..value.len];
            }

            return error.NotFound;
        }

        pub fn del(self: *const Self, hash: Hash.Type(), key: []u8) !void {
            try assertKeySize(key.len);

            const index = getIndex(hash);
            const record = self.records[index];

            if (record.isEmpty() or record.matches(hash, key)) {
                record.free(allocator);
                self.records[index] = Record.default();
            }
        }
    };
}

test "Cache" {
    const Testing = @import("Testing.zig");
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    const xxhash = std.hash.XxHash64.hash;

    const Cache = Struct(Config.default(), allocator);

    const cache = try Cache.init();
    defer cache.deinit();

    const key = try Testing.randomString(allocator, 5);
    defer allocator.free(key);
    const value = try Testing.randomString(allocator, 16);
    defer allocator.free(value);
    const hash = xxhash(0, key);
    const ttl: u32 = 1;

    const output_buffer = try allocator.alloc(u8, 16);
    defer allocator.free(output_buffer);

    try expect(cache.get(hash, key, output_buffer) == error.NotFound);
    try expect(try cache.put(hash, key, value, ttl) == {});
    try expect(std.mem.eql(u8, value, try cache.get(hash, key, output_buffer)));
    try expect(try cache.del(hash, key) == {});
    try expect(cache.get(hash, key, output_buffer) == error.NotFound);
}
