const std = @import("std");
const Record = @import("Record.zig");
const Utils = @import("Utils.zig");
const Config = @import("Config.zig");
const Result = @import("Result.zig").Result;
const RandomIndex = @import("Random/Index.zig");
const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
records: []Record,
config: Config,
random_index: RandomIndex,

pub fn init(allocator: Allocator, config: Config) !Self {
    const records = try allocator.alloc(Record, config.record_count);
    const random_index = try RandomIndex.init(allocator, config.record_count);

    for (0..config.record_count) |i| {
        records[i] = Record.default();
    }

    return Self{ .allocator = allocator, .records = records, .config = config, .random_index = random_index };
}

pub fn put(self: Self, hash: u64, key: []u8, value: []u8, ttl: ?u32) !void {
    try Utils.assert_key_length(key, self.config);
    try Utils.assert_value_length(value, self.config);

    const index = Utils.hash_to_index(self.config, hash);
    const current_record = self.records[index];

    const should_overwrite = current_record.cmp_hash(null) or
        (current_record.cmp_hash(hash) and
        current_record.cmp_key(key)) or
        current_record.exp_ttl() or
        current_record.is_unlucky();

    if (should_overwrite) {
        current_record.deinit(self.allocator);

        self.records[index] = try Record.create(self.allocator, hash, key, value, ttl);
    }
}

pub fn get(self: *Self, hash: u64, key: []u8) ![]u8 {
    try Utils.assert_key_length(key, self.config);

    const index = Utils.hash_to_index(self.config, hash);
    const current_record = self.records[index];

    if (current_record.cmp_hash(null)) {
        return error.RecordEmpty;
    }

    if (current_record.exp_ttl()) {
        current_record.deinit(self.allocator);
        self.records[index] = Record.default();

        return error.TtlExpired;
    }

    if (current_record.cmp_hash(hash) and current_record.cmp_key(key)) {
        if (Utils.should_inc_temp(self.config)) {
            self.records[index].temp_inc();

            const victim_index = self.random_index.next();

            self.records[victim_index].temp_dec();
        }

        return current_record.get_value();
    }

    return error.RecordNotFound;
}

pub fn del(self: Self, hash: u64, key: []u8) !void {
    try Utils.assert_key_length(key, self.config);

    const index = Utils.hash_to_index(self.config, hash);
    const current_record = self.records[index];

    if (current_record.cmp_hash(null) == false and
        current_record.cmp_hash(hash) and current_record.cmp_key(key))
    {
        current_record.deinit(self.allocator);
        self.records[index] = Record.default();
    }
}

pub fn deinit(self: Self) void {
    for (0..self.config.record_count) |i| {
        self.records[i].deinit(self.allocator);
    }

    self.allocator.free(self.records);
    self.random_index.deinit();
}
