const std = @import("std");
const Config = @import("Config.zig");
const createRandom = @import("Random.zig").Struct;
const createRecord = @import("Record.zig").Struct;
const createHash = @import("Record/Hash.zig").Struct;
const createTtl = @import("Record/Ttl.zig").Struct;

const Allocator = std.mem.Allocator;

pub fn Struct(comptime config: Config) type {
    const Random = createRandom(config);
    const Record = createRecord(config);
    const Hash = createHash(config.record);
    const Ttl = createTtl(config.record);

    return struct {
        const Self = @This();

        allocator: Allocator,
        records: []Record,
        random: Random,

        pub fn init(allocator: Allocator) !Self {
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

        inline fn getIndex(hash: Hash.Type()) usize {
            if (comptime std.math.isPowerOfTwo(config.cache.count)) {
                return hash & (comptime config.cache.count - 1);
            } else {
                return hash % comptime config.cache.count;
            }
        }

        pub fn put(self: *const Self, hash: Hash.Type(), key: []u8, value: []u8, ttl: Ttl.Type()) !void {
            const index = getIndex(hash);
            const record = self.records[index];

            if (record.isEmpty() or record.matches(hash, key) or record.shouldRewrite(block: {
                var random = self.random;
                break :block random.temperature();
            })) {
                const new_record = try Record.create(self.allocator, hash, key, value, ttl);

                self.records[index].free(self.allocator);
                self.records[index] = new_record;
            }
        }

        pub fn get(self: *const Self, hash: Hash.Type(), key: []u8, output_buffer: []u8) ![]u8 {
            const index = getIndex(hash);
            const record = self.records[index];

            if (record.isEmpty() or record.isExpired() or !record.matches(hash, key)) {
                return error.ERROR;
            }

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

        pub fn del(self: *const Self, hash: Hash.Type(), key: []u8) !void {
            const index = getIndex(hash);
            const record = self.records[index];

            if (record.isEmpty() or record.matches(hash, key)) {
                record.free(self.allocator);
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

    const Cache = Struct(Config.default());

    const cache = try Cache.init(allocator);
    defer cache.deinit();

    const key = try Testing.randomString(allocator, 5);
    defer allocator.free(key);
    const value = try Testing.randomString(allocator, 16);
    defer allocator.free(value);
    const hash = xxhash(0, key);
    const ttl: u32 = 1;

    const output_buffer = try allocator.alloc(u8, 16);
    defer allocator.free(output_buffer);

    try expect(cache.get(hash, key, output_buffer) == error.ERROR);
    try expect(try cache.put(hash, key, value, ttl) == {});
    try expect(std.mem.eql(u8, value, try cache.get(hash, key, output_buffer)));
    try expect(try cache.del(hash, key) == {});
    try expect(cache.get(hash, key, output_buffer) == error.ERROR);
}
