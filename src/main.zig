const Config = @import("Config.zig");
const createServer = @import("Server.zig");

pub fn main(config: Config) !void {
    const Server = createServer(config);
    const server = Server.init();
    defer server.deinit();

    server.start();
}
