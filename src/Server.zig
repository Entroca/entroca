const std = @import("std");
const Config = @import("Config.zig");
const createCache = @import("Cache.zig").Struct;
const createData = @import("Record/DataValue.zig").Struct;
const createHash = @import("Record/Hash.zig").Struct;
const createTtl = @import("Record/Ttl.zig").Struct;

const Allocator = std.mem.Allocator;

pub fn Struct(comptime config: Config) type {
    const Cache = createCache(config);
    const Hash = createHash(config.record);
    const Key = createData(config.record, config.record.key);
    const Value = createData(config.record, config.record.value);
    const Ttl = createTtl(config.record);

    return struct {
        const Self = @This();

        allocator: Allocator,
        input_buffer: []u8,
        output_buffer: []u8,
        conn_buffer: []u8,
        cache: Cache,

        pub fn init(allocator: Allocator) !Self {
            const cache = try Cache.init(allocator);

            const input_buffer = try allocator.alloc(u8, 1 + Hash.byteSize() + Ttl.byteSize() + 4 + Key.byteSize() + 4 + Value.byteSize());
            const output_buffer = try allocator.alloc(u8, 1 + Value.byteSize());
            const conn_buffer = try allocator.alloc(u8, 2);

            conn_buffer[0] = comptime if (config.record.key == .dynamic) 1 else 0;
            conn_buffer[1] = comptime if (config.record.value == .dynamic) 1 else 0;

            return Self{
                .allocator = allocator,
                .input_buffer = input_buffer,
                .output_buffer = output_buffer,
                .conn_buffer = conn_buffer,
                .cache = cache,
            };
        }

        pub fn deinit(self: *const Self) void {
            self.allocator.free(self.input_buffer);
            self.allocator.free(self.output_buffer);
            self.cache.deinit();
        }

        pub fn start(self: *const Self) !void {
            const server_address = try std.net.Address.parseIp("127.0.0.1", config.server.port);
            var server = try server_address.listen(.{});

            const client_connection = try server.accept();
            defer client_connection.stream.close();

            _ = try client_connection.stream.writeAll(self.conn_buffer);

            while (true) {
                if (client_connection.stream.read(self.input_buffer) catch break == 0) break;
                _ = try self.call(client_connection);
            }
        }

        inline fn call(self: *const Self, client_connection: std.net.Server.Connection) !void {
            switch (self.input_buffer[0]) {
                0 => self.handlePut() catch {},
                1 => self.handleGet(client_connection) catch {
                    try self.writeError(client_connection);
                },
                2 => self.handleDel() catch {},
                else => {},
            }
        }

        inline fn handlePut(self: *const Self) !void {
            var index: usize = 1;

            const hash = Hash.decode(self.input_buffer, &index);
            const ttl = Ttl.decode(self.input_buffer, &index);
            const key = Key.decode(self.input_buffer, &index);
            const value = Value.decode(self.input_buffer, &index);

            try self.cache.put(hash, key, value, ttl);
        }

        inline fn handleGet(self: *const Self, client_connection: std.net.Server.Connection) !void {
            var index: usize = 1;

            const hash = Hash.decode(self.input_buffer, &index);
            const key = Key.decode(self.input_buffer, &index);
            const result = try self.cache.get(hash, key, self.output_buffer);

            try self.writeValue(client_connection, result.len);
        }

        inline fn handleDel(self: *const Self) !void {
            var index: usize = 1;

            const hash = Hash.decode(self.input_buffer, &index);
            const key = Key.decode(self.input_buffer, &index);

            try self.cache.del(hash, key);
        }

        inline fn writeError(self: *const Self, client_connection: std.net.Server.Connection) !void {
            self.output_buffer[0] = 0;
            _ = try client_connection.stream.writeAll(self.output_buffer[0..1]);
        }

        inline fn writeValue(self: *const Self, client_connection: std.net.Server.Connection, length: usize) !void {
            self.output_buffer[0] = 1;
            _ = try client_connection.stream.writeAll(self.output_buffer[0..length]);
        }
    };
}
