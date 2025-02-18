const Self = @This();

hugepages: bool,

pub fn default() Self {
    return .{
        .hugepages = true,
    };
}
