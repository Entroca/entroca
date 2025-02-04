const std = @import("std");
const Record = @import("Record.zig");
const Config = @import("Config.zig");
const RandomProbability = @import("Random/Probability.zig");
const RandomTemperature = @import("Random/Temperature.zig");

const Allocator = std.mem.Allocator;
const AllocatorError = Allocator.Error;
const ErrorAssertKeyValueLength = Record.ErrorAssertKeyValueLength;
const ErrorAssertKeyLength = Record.ErrorAssertKeyLength;

const Self = @This();

allocator: Allocator,
records: []Record,
config: Config,
random_probability: RandomProbability,
random_temperature: RandomTemperature,

pub const PutError = ErrorAssertKeyValueLength || AllocatorError;
pub const GetError = error{ RecordEmpty, TtlExpired, RecordNotFound } || ErrorAssertKeyLength;
pub const DelError = ErrorAssertKeyLength;
pub const Error = PutError || GetError || DelError;

pub fn init(allocator: Allocator, config: Config) AllocatorError!Self {
    const random_probability = try RandomProbability.init(
        allocator,
        config.record_count,
    );

    const random_temperature = try RandomTemperature.init(
        allocator,
        config.record_count,
    );

    const records = try allocator.alloc(Record, config.record_count);

    for (0..config.record_count) |i| {
        records[i] = Record.default();
    }

    return Self{
        .allocator = allocator,
        .records = records,
        .config = config,
        .random_probability = random_probability,
        .random_temperature = random_temperature,
    };
}

pub fn put(self: Self, hash: u64, key: []u8, value: []u8, ttl: ?u32) PutError!void {
    try Record.assert_key_length(key, self.config);
    try Record.assert_value_length(value, self.config);

    const index = Record.hash_to_index(self.config, hash);
    const current_record = &self.records[index];

    if (current_record.cmp_hash(null) or
        current_record.cmp_hash_key(hash, key) or
        current_record.exp_ttl() or
        current_record.is_unlucky(
        block: {
            var random_temperature = self.random_temperature;
            break :block random_temperature.next();
        },
    )) {
        current_record.deinit(self.allocator);

        self.records[index] = try Record.create(
            self.allocator,
            hash,
            key,
            value,
            ttl,
        );
    }
}

pub fn get(self: Self, hash: u64, key: []u8) GetError![]u8 {
    try Record.assert_key_length(key, self.config);

    const index = Record.hash_to_index(self.config, hash);
    const current_record = &self.records[index];

    if (current_record.cmp_hash(null)) {
        return error.RecordEmpty;
    }

    if (current_record.exp_ttl()) {
        current_record.deinit(self.allocator);
        self.records[index] = Record.default();

        return error.TtlExpired;
    }

    if (current_record.cmp_hash_key(hash, key)) {
        if (Record.should_inc_temp(
            self.config,
            block: {
                var random_probability = self.random_probability;
                break :block random_probability.next();
            },
        )) {
            current_record.temp_inc();

            const victim_index = Record.get_victim_index(
                self.config,
                index,
            );

            const victim_record = &self.records[victim_index];

            victim_record.temp_dec();
        }

        return current_record.get_value();
    }

    return error.RecordNotFound;
}

pub fn del(self: Self, hash: u64, key: []u8) DelError!void {
    try Record.assert_key_length(key, self.config);

    const index = Record.hash_to_index(self.config, hash);
    const current_record = &self.records[index];

    if (current_record.cmp_hash(null) == false and current_record.cmp_hash_key(hash, key)) {
        current_record.deinit(self.allocator);
        self.records[index] = Record.default();
    }
}

pub fn deinit(self: Self) void {
    for (0..self.config.record_count) |i| {
        self.records[i].deinit(self.allocator);
    }

    self.allocator.free(self.records);
    self.random_probability.deinit();
    self.random_temperature.deinit();
}
