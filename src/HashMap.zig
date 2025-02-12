const std = @import("std");
const Config = @import("Config.zig");
const Utils = @import("Utils.zig");
const createRecord = @import("Record.zig").create;
const createRandom = @import("Random.zig").create;

const Allocator = std.mem.Allocator;

pub fn create(comptime config: Config) type {
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
            if (comptime config.features.assert_key_length) {
                try config.key.assertSize(key, error.KeyTooShort, error.KeyTooLong);
            }

            if (comptime config.features.assert_value_length) {
                try config.value.assertSize(value, error.ValueTooShort, error.ValueTooLong);
            }

            const index = config.getIndex(hash);
            const record = self.records[index];

            if (record.isEmpty() or record.compareHashAndKey(hash, key) or record.isUnlucky(self)) {
                record.free(self.allocator);
                self.records[index] = try Record.create(self.allocator, hash, key, value);

                return;
            }

            return error.SlotUnavailable;
        }

        pub fn get(self: Self, hash: config.HashType(), key: []u8, buffer: []u8) ![]u8 {
            if (comptime config.features.assert_key_length) {
                try config.key.assertSize(key, error.KeyTooShort, error.KeyTooLong);
            }

            const index = config.getIndex(hash);
            var record = self.records[index];

            if (!record.isEmpty() and record.compareHashAndKey(hash, key)) {
                if (record.isLucky(self)) {
                    record.increaseTemperature();

                    var sibling = self.records[Record.getSiblingIndex(index)];

                    sibling.decreaseTemperature();
                }

                const value = record.getValue();

                @memcpy(buffer[0..value.len], value);

                return buffer[0..value.len];
            }

            return error.NotFound;
        }

        pub fn del(self: Self, hash: config.HashType(), key: []u8) !void {
            if (comptime config.features.assert_key_length) {
                try config.key.assertSize(key, error.KeyTooShort, error.KeyTooLong);
            }

            const index = config.getIndex(hash);
            const record = self.records[index];

            if (!record.isEmpty() and record.compareHashAndKey(hash, key)) {
                record.free(self.allocator);
                self.records[index] = Record.default();

                return;
            }

            return error.NotFound;
        }

        pub fn clr(self: Self) void {
            if (comptime config.key == .dynamic or config.value == .dynamic) {
                for (0..config.count) |index| {
                    self.records[index].free(self.allocator);
                }
            }

            for (0..config.count) |index| {
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
        .strategy = .{
            .boltzmann = .{
                .constant = 32.0,
            },
        },
        .padding = .{
            .internal = true,
            .external = true,
        },
        .features = .{
            .assert_key_length = false,
            .assert_value_length = false,
            .no_total_length = false,
        },
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
                .max_size = 8,
            },
        },
        .temperature = .{
            .type = u8,
            .rate = 0.05,
        },
    };

    const HashMap = create(config);
    const Record = createRecord(config);

    std.debug.print("----- Record -----\n", .{});
    std.debug.print("Record.empty: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .empty).type)});
    std.debug.print("Record.hash: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .hash).type)});
    std.debug.print("Record.key: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .key).type)});
    std.debug.print("Record.key_length: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .key_length).type)});
    std.debug.print("Record.value: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .value).type)});
    std.debug.print("Record.value_length: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .value_length).type)});
    std.debug.print("Record.total_length: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .total_length).type)});
    std.debug.print("Record.data: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .data).type)});
    std.debug.print("Record.temperature: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .temperature).type)});
    std.debug.print("Record.padding: {}b\n", .{@bitSizeOf(std.meta.fieldInfo(Record, .padding).type)});
    std.debug.print("------------------\n", .{});
    std.debug.print("Record: {}b\n", .{@bitSizeOf(Record)});
    std.debug.print("------------------\n", .{});

    const hash_map = try HashMap.init(allocator);
    defer hash_map.deinit();

    const key = @as([]u8, @constCast("helllolo")[0..]);
    const value = @as([]u8, @constCast("worrldld")[0..]);
    const hash = xxhash(0, key);
    const get_buffer = try allocator.alloc(u8, 8);
    defer allocator.free(get_buffer);

    std.debug.print("put: {any}\n", .{hash_map.put(hash, key, value)});
    std.debug.print("get: {any}\n", .{hash_map.get(hash, key, get_buffer)});
    std.debug.print("del: {any}\n", .{hash_map.del(hash, key)});
    std.debug.print("get: {any}\n", .{hash_map.get(hash, key, get_buffer)});
    std.debug.print("put: {any}\n", .{hash_map.put(hash, key, value)});
    std.debug.print("get: {any}\n", .{hash_map.get(hash, key, get_buffer)});
    std.debug.print("clr: {any}\n", .{hash_map.clr()});
    std.debug.print("get: {any}\n", .{hash_map.get(hash, key, get_buffer)});
}
