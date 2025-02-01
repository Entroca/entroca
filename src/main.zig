const std = @import("std");
const net = std.net;
const Server = @import("Server.zig");
const Config = @import("Config.zig");

const THREADS = 4;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var threads = std.ArrayList(std.Thread).init(allocator);

    for (0..THREADS) |i| {
        const thread = try std.Thread.spawn(.{}, handler, .{Config{
            .port = 3000 + @as(u16, @intCast(i)),
            .record_count = 65536,
            .key_max_length = 1048576,
            .value_max_length = 67108864,
        }});

        try threads.append(thread);
    }

    for (threads.items) |thread| {
        thread.join();
    }
}

fn handler(config: Config) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try Server.init(allocator, config);

    defer server.deinit();

    while (true) {
        _ = try server.accept();
    }
}
