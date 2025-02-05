const std = @import("std");
const Record = @import("Record.zig");
const Config = @import("Config.zig");
const Random = @import("Random.zig");
const Protocol = @import("Protocol.zig");

const Allocator = std.mem.Allocator;
const AllocatorError = Allocator.Error;
const ErrorAssertKeyValueLength = Record.ErrorAssertKeyValueLength;
const ErrorAssertKeyLength = Record.ErrorAssertKeyLength;

const Self = @This();

allocator: Allocator,
records: []Record,
config: Config,
random_probability: Random.Probability,
random_temperature: Random.Temperature,

pub const PutError = ErrorAssertKeyValueLength || AllocatorError;
pub const GetError = error{ RecordEmpty, TtlExpired, RecordNotFound } || ErrorAssertKeyLength;
pub const DelError = ErrorAssertKeyLength;
pub const Error = PutError || GetError || DelError;

pub fn init(allocator: Allocator, config: Config) AllocatorError!Self {
    const random_probability = try Random.Probability.init(
        allocator,
        config.record_count,
    );

    const random_temperature = try Random.Temperature.init(
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

pub fn put(self: Self, data: Protocol.Put) PutError!void {
    try Record.assert_key_length(data.key, self.config);
    try Record.assert_value_length(data.value, self.config);

    const index = Record.hash_to_index(self.config, data.hash);
    const current_record = &self.records[index];

    if (current_record.cmp_hash(null) or
        current_record.cmp_hash_key(data.hash, data.key) or
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
            data,
        );
    }
}

pub fn get(self: Self, data: Protocol.Get) GetError![]u8 {
    try Record.assert_key_length(data.key, self.config);

    const index = Record.hash_to_index(self.config, data.hash);
    const current_record = &self.records[index];

    if (current_record.cmp_hash(null)) {
        return error.RecordEmpty;
    }

    if (current_record.exp_ttl()) {
        current_record.deinit(self.allocator);
        self.records[index] = Record.default();

        return error.TtlExpired;
    }

    if (current_record.cmp_hash_key(data.hash, data.key)) {
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

pub fn del(self: Self, data: Protocol.Get) DelError!void {
    try Record.assert_key_length(data.key, self.config);

    const index = Record.hash_to_index(self.config, data.hash);
    const current_record = &self.records[index];
    const hash_not_null = current_record.cmp_hash(null) == false;
    const hash_key_equals = current_record.cmp_hash_key(data.hash, data.key);

    if (hash_not_null and hash_key_equals) {
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
