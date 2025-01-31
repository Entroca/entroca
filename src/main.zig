const std = @import("std");
const net = std.net;
const Server = @import("Server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try Server.init(allocator);
    defer server.deinit();

    while (true) {
        _ = try server.accept();
    }
}
