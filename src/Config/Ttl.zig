const std = @import("std");
const Utils = @import("../Utils.zig");

const Resolution = enum {
    millisecond,
    second,
    minute,
    hour,
    day,
};

const Absolute = struct {
    resolution: Resolution,
    max_input_count: usize,
    max_total_count: usize,
};

// NOTE: maybe add reference as default value
const Relative = struct {
    resolution: Resolution,
    max_input_count: usize,
    max_total_count: usize,
};

const None = struct {};

pub const Enum = union(enum) {
    none: None,
    absolute: Absolute,
    relative: Relative,
};
