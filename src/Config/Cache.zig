const Self = @This();

count: usize,

pub fn default() Self {
    return .{
        .count = 1024,
    };
}
