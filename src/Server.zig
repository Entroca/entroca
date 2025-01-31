const std = @import("std");
const HashMap = @import("HashMap.zig");
const RPC = @import("RPC.zig");
const net = std.net;
const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
hash_map: HashMap,
server: net.Server,
buffer: []u8,

pub fn init(allocator: Allocator) !Self {
    const buffer = try allocator.alloc(u8, 134217728);
    const hash_map = try HashMap.init(allocator, 1024);
    const localhost = try net.Address.parseIp("127.0.0.1", 3000);

    var server = try localhost.listen(.{});

    std.debug.print("[DEBUG] - Server listening on port {}\n", .{server.listen_address.getPort()});
    return Self{
        .allocator = allocator,
        .hash_map = hash_map,
        .server = server,
        .buffer = buffer,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.buffer);
    self.hash_map.free();
    self.server.deinit();
}

pub fn accept(self: *Self) !void {
    const conn = try self.server.accept();
    defer conn.stream.close();

    const msg_size = try conn.stream.read(self.buffer[0..]);

    std.debug.print("[DEBUG] - Message recived {any}\n", .{self.buffer[0..msg_size]});

    const res = RPC.call(self.hash_map, self.buffer[0..msg_size]);

    std.debug.print("res: {any}\n", .{res});

    _ = try conn.stream.writeAll("Hello from server");
}
