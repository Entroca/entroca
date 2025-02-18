const Hash = @import("Record/Hash.zig");
const Data = @import("Record/Data.zig").Enum;
const Temp = @import("Record/Temp.zig");
const Ttl = @import("Record/Ttl.zig").Enum;
const Padding = @import("Record/Padding.zig");

const Self = @This();

hash: Hash,
key: Data,
value: Data,
temp: Temp,
ttl: Ttl,
padding: Padding,

pub fn default() Self {
    return .{
        .hash = .{
            .type = u64,
        },
        .key = .{
            .static = .{
                .min_size = 1,
                .max_size = 8,
            },
        },
        .value = .{
            .dynamic = .{
                .min_size = 8,
                .max_size = 1024,
            },
        },
        .temp = .{
            .type = u8,
            .rate = 0.05,
        },
        .ttl = .{
            .absolute = .{},
        },
        .padding = .{
            .internal = false,
            .external = false,
        },
    };
}
