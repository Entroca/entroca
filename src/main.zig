const std = @import("std");
const Config = @import("Config.zig");
const createServer = @import("Server.zig").Struct;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const Server = createServer(Config.default());
    const server = try Server.init(allocator);
    defer server.deinit();

    try server.start();
}
