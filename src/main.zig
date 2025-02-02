const std = @import("std");
const net = std.net;
const Server = @import("Server.zig");
const Config = @import("Config.zig");

pub fn main() !void {
    // Initialize memory allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();

    // Determine optimal thread count based on CPU cores
    const cpu_cores = try std.Thread.getCpuCount();
    std.debug.print("[MAIN] Starting {} server instances (one per CPU thread)\n", .{cpu_cores});

    // Pre-allocate array for server threads
    var server_threads: []std.Thread = try allocator.alloc(std.Thread, cpu_cores);
    defer allocator.free(server_threads);

    // Launch server instances on consecutive ports
    for (0..cpu_cores) |core_index| {
        const server_config = Config{
            .port = 3000 + @as(u16, @intCast(core_index)),
            .record_count = 65536, // 64k records capacity
            .key_max_length = 1 << 20, // 1MB max key size
            .value_max_length = 1 << 26, // 64MB max value size
        };

        server_threads[core_index] = try std.Thread.spawn(.{}, start_server_instance, .{server_config});
    }

    // Keep main thread alive until all servers complete
    for (server_threads) |thread| {
        thread.join();
    }
}

/// Server instance lifecycle manager
fn start_server_instance(config: Config) !void {
    // Create isolated allocator for each server instance
    var server_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = server_allocator.allocator();

    // Initialize server with configuration
    var server = try Server.init(allocator, config);
    defer server.deinit();

    // Continuous connection handling loop
    while (true) {
        _ = try server.accept();
    }
}
