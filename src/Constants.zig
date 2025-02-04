const std = @import("std");
const Utils = @import("Utils.zig");

pub const TEMP_DEFAULT = std.math.maxInt(u8) / 2;
pub const UNLUCKY_CURVE = Utils.create_boltzmann_curve(u8, 32.0);
