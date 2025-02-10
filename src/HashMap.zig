const std = @import("std");
const Config = @import("Config.zig");
const Utils = @import("Utils.zig");
const createRecord = @import("Record.zig").create;
const createRandom = @import("Random.zig").create;

const Allocator = std.mem.Allocator;

pub fn create(config: Config) type {
    const Record = createRecord(config);
    const Random = createRandom(config);

    return struct {
        const Self = @This();

        allocator: Allocator,
        records: []Record,
        random: Random,

        pub fn init(allocator: Allocator) !Self {
            const records = try allocator.alloc(Record, config.count);

            for (0..config.count) |index| {
                records[index] = Record.default();
            }

            const random = try Random.init(allocator);

            return .{
                .allocator = allocator,
                .records = records,
                .random = random,
            };
        }

        pub fn deinit(self: Self) void {
            if (comptime config.key == .dynamic or config.value == .dynamic) {
                for (0..config.count) |index| {
                    self.records[index].free(self.allocator);
                }
            }

            self.allocator.free(self.records);
            self.random.deinit();
        }

        pub fn put(self: Self, hash: config.HashType(), key: []u8, value: []u8) !void {
            const index = config.getIndex(hash);
            const record = self.records[index];

            if (record.isEmpty() or record.compareHashAndKey(hash, key) or record.isUnlucky(block: {
                var random = self.random;
                break :block random.temperature();
            })) {
                record.free(self.allocator);
                self.records[index] = try Record.create(self.allocator, hash, key, value);
            }
        }

        pub fn get(self: Self, hash: config.HashType(), key: []u8) ![]u8 {
            const index = config.getIndex(hash);
            var record = self.records[index];

            if (record.isEmpty()) {
                return error.Empty;
            }

            if (record.compareHashAndKey(hash, key)) {
                if (record.isLucky(block: {
                    var random = self.random;
                    break :block random.probability();
                })) {
                    record.increaseTemperature();

                    var sibling = self.records[Record.getSiblingIndex(index)];

                    sibling.decreaseTemperature();
                }

                return record.getValue();
            }

            return error.NoMatch;
        }

        pub fn del(self: Self, hash: config.HashType(), key: []u8) !void {
            const index = config.getIndex(hash);
            const record = self.records[index];

            if (record.compareHashAndKey(hash, key)) {
                record.free(self.allocator);
                self.records[index] = Record.default();
            }
        }
    };
}

test "HashMap" {
    const xxhash = std.hash.XxHash64.hash;
    const allocator = std.testing.allocator;

    const config = Config{
        .count = 1024,
        .boltzmann = 32.0,
        .hash = .{
            .type = u64,
        },
        .key = .{
            .dynamic = .{
                .min_size = 1,
                .max_size = 8,
            },
        },
        .value = .{
            .dynamic = .{
                .min_size = 1,
                .max_size = 65536,
            },
        },
        .temperature = .{
            .type = u8,
            .rate = 0.05,
        },
    };
    const HashMap = create(config);
    const Record = createRecord(config);

    std.debug.print("Record size: {}\n", .{@sizeOf(Record)});

    const hash_map = try HashMap.init(allocator);
    defer hash_map.deinit();

    const key = @as([]u8, @constCast("hello")[0..]);
    const value = @as([]u8, @constCast("world")[0..]);
    const hash = xxhash(0, key);

    std.debug.print("put: {any}\n", .{hash_map.put(hash, key, value)});
    std.debug.print("get: {any}\n", .{hash_map.get(hash, key)});
    std.debug.print("del: {any}\n", .{hash_map.del(hash, key)});
    std.debug.print("get: {any}\n", .{hash_map.get(hash, key)});
}
