const Size = struct {
    min_size: usize,
    max_size: usize,
};

pub const Enum = union(enum) {
    static: Size,
    dynamic: Size,
};
