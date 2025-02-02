const std = @import("std");
const HashMap = @import("HashMap.zig");
const RPC = @import("RPC.zig");
const Config = @import("Config.zig");
const net = std.net;
const Allocator = std.mem.Allocator;

const Self = @This();

// Server components
allocator: Allocator, // Memory manager for resource allocation
config: Config, // Server configuration parameters
hash_map: HashMap, // Key-value storage backend
server: net.Server, // Network listener instance
input_buffer: []u8, // Buffer for incoming client requests
output_buffer: []u8, // Buffer for server responses

/// Initialize server instance with configuration
/// - Allocates communication buffers based on config limits
/// - Sets up hash map storage
/// - Binds to configured network port
pub fn init(allocator: Allocator, config: Config) !Self {
    // Calculate buffer sizes based on protocol requirements:
    // Input: [1 byte command] + [8 byte hash] + [4 byte TTL] +
    //        [4 byte key len] + [4 byte value len] + max key + max value
    const INPUT_BUFFER_SIZE = 1 + 8 + 4 + 4 + 4 + config.key_max_length + config.value_max_length;
    const OUTPUT_BUFFER_SIZE = 1 + config.value_max_length; // [1 byte status] + max value

    const input_buffer = try allocator.alloc(u8, INPUT_BUFFER_SIZE);
    const output_buffer = try allocator.alloc(u8, OUTPUT_BUFFER_SIZE);

    // Initialize data storage
    const hash_map = try HashMap.init(allocator, config);

    // Configure network listener
    const server_address = try net.Address.parseIp("127.0.0.1", config.port);
    var server = try server_address.listen(.{});

    std.debug.print("[SERVER] Listening on port {}\n", .{server.listen_address.getPort()});

    return Self{
        .allocator = allocator,
        .config = config,
        .hash_map = hash_map,
        .server = server,
        .input_buffer = input_buffer,
        .output_buffer = output_buffer,
    };
}

/// Clean up server resources
/// - Free allocated buffers
/// - Release hash map storage
/// - Shut down network listener
pub fn deinit(self: *Self) void {
    self.allocator.free(self.input_buffer);
    self.allocator.free(self.output_buffer);
    self.hash_map.deinit();
    self.server.deinit();
}

/// Handle incoming client connections
/// - Processes requests in a loop until client disconnects
/// - Uses RPC module to execute commands
pub fn accept(self: *Self) !void {
    const client_connection = try self.server.accept();
    defer client_connection.stream.close();
    std.debug.print("[SERVER] New client connection\n", .{});

    while (true) {
        // Read client request
        const bytes_read = try client_connection.stream.read(self.input_buffer[0..]);

        // Handle client disconnect
        if (bytes_read == 0) {
            std.debug.print("[SERVER] Client closed connection\n", .{});
            break;
        }

        std.debug.print("[SERVER] Received {} byte message: {any}\n", .{ bytes_read, self.input_buffer[0..bytes_read] });

        // Process request through RPC handler
        const response = RPC.call(self.hash_map, self.input_buffer[0..bytes_read], self.output_buffer[0..]);

        std.debug.print("[SERVER] Sending {} byte response: {any}\n", .{ response.len, response });

        // Send response back to client
        _ = try client_connection.stream.writeAll(response);
    }
}
