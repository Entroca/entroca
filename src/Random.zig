const std = @import("std");
const Config = @import("Config.zig");

const Allocator = std.mem.Allocator;
const random = std.crypto.random;

pub fn create(config: Config) type {
    return struct {
        const Self = @This();

        allocator: Allocator,

        temperature_array: []config.TemperatureType(),
        temperature_index: usize,

        probability_array: []f64,
        probability_index: usize,

        pub fn init(allocator: Allocator) !Self {
            const temperature_array = try allocator.alloc(config.TemperatureType(), config.count);

            for (0..config.count) |index| {
                temperature_array[index] = random.intRangeAtMost(config.TemperatureType(), 0, std.math.maxInt(config.TemperatureType()));
            }

            const probability_array = try allocator.alloc(f64, config.count);

            for (0..config.count) |index| {
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

        pub fn temperature(self: *Self) config.TemperatureType() {
            const result = self.temperature_array[self.temperature_index];

            self.temperature_index = (self.temperature_index + 1) % config.count;

            return result;
        }

        pub fn probability(self: *Self) f64 {
            const result = self.probability_array[self.probability_index];

            self.probability_index = (self.probability_index + 1) % config.count;

            return result;
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.temperature_array);
            self.allocator.free(self.probability_array);
        }
    };
}
