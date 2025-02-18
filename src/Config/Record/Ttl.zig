const Absolute = struct {};

const None = struct {};

pub const Enum = union(enum) {
    absolute: Absolute,
    none: None,
};
