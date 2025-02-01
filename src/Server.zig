const std = @import("std");
const HashMap = @import("HashMap.zig");
const RPC = @import("RPC.zig");
const Config = @import("Config.zig");
const net = std.net;
const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
config: Config,
hash_map: HashMap,
server: net.Server,
input_buffer: []u8,
output_buffer: []u8,

pub fn init(allocator: Allocator, config: Config) !Self {
    const input_buffer = try allocator.alloc(u8, 1 + 8 + 4 + 4 + 4 + config.key_max_length + config.value_max_length);
    const output_buffer = try allocator.alloc(u8, 1 + config.value_max_length);

    const hash_map = try HashMap.init(allocator, config);
    const localhost = try net.Address.parseIp("127.0.0.1", config.port);

    var server = try localhost.listen(.{});

    std.debug.print("[DEBUG] - Server listening on port {}\n", .{server.listen_address.getPort()});

    return Self{
        .allocator = allocator,
        .config = config,
        .hash_map = hash_map,
        .server = server,
        .input_buffer = input_buffer,
        .output_buffer = output_buffer,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.input_buffer);
    self.allocator.free(self.output_buffer);
    self.hash_map.free();
    self.server.deinit();
}

pub fn accept(self: *Self) !void {
    const conn = try self.server.accept();
    defer conn.stream.close();

    std.debug.print("[DEBUG] - Client connected\n", .{});

    while (true) {
        const msg_size = try conn.stream.read(self.input_buffer[0..]);

        if (msg_size == 0) {
            std.debug.print("[DEBUG] - Client disconnected\n", .{});
            break;
        }

        std.debug.print("[DEBUG] - Message recived {any}\n", .{self.input_buffer[0..msg_size]});

        const response = RPC.call(self.hash_map, self.input_buffer[0..msg_size], self.output_buffer[0..]);

        std.debug.print("response: {any}\n", .{response});

        _ = try conn.stream.writeAll(response);
    }
}
