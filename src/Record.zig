const std = @import("std");
const Self = @This();

data: ?[]u8,
hash: ?u64,
key_length: u32,
value_length: u32,
ttl: u32,
temperature: u8,
