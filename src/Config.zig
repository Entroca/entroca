const Server = @import("Config/Server.zig");
const Cache = @import("Config/Cache.zig");
const Record = @import("Config/Record.zig");
const Allocator = @import("Config/Cache.zig");

const Self = @This();

server: Server,
cache: Cache,
record: Record,
allocator: Allocator,

pub fn default() Self {
    return .{
        .server = Server.default(),
        .cache = Cache.default(),
        .record = Record.default(),
        .allocator = Allocator.default(),
    };
}
