const Self = @This();

port: usize,
threads: usize,

pub fn default() Self {
    return .{
        .port = 3000,
        .threads = 4,
    };
}
