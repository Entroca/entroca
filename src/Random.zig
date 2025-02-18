const std = @import("std");
const Config = @import("Config.zig");

const Allocator = std.mem.Allocator;
const random = std.crypto.random;

pub fn Struct(comptime config: Config) type {
    return struct {
        const Self = @This();

        allocator: Allocator,

        temperature_array: []config.record.temp.type,
        temperature_index: usize,

        probability_array: []f64,
        probability_index: usize,

        pub fn init(allocator: Allocator) !Self {
            const temperature_array = try allocator.alloc(config.record.temp.type, config.cache.count);

            for (0..config.cache.count) |index| {
                temperature_array[index] = random.intRangeAtMost(config.record.temp.type, 0, std.math.maxInt(config.record.temp.type));
            }

            const probability_array = try allocator.alloc(f64, config.cache.count);

            for (0..config.cache.count) |index| {
                probability_array[index] = random.float(f64);
            }

            return Self{
                .allocator = allocator,
                .temperature_array = temperature_array,
                .temperature_index = 0,
                .probability_array = probability_array,
                .probability_index = 0,
            };
        }

        pub fn temperature(self: *Self) config.record.temp.type {
            const result = self.temperature_array[self.temperature_index];

            self.temperature_index = (self.temperature_index + 1) % config.cache.count;

            return result;
        }

        pub fn probability(self: *Self) f64 {
            const result = self.probability_array[self.probability_index];

            self.probability_index = (self.probability_index + 1) % config.cache.count;

            return result;
        }

        pub fn deinit(self: *const Self) void {
            self.allocator.free(self.temperature_array);
            self.allocator.free(self.probability_array);
        }
    };
}
