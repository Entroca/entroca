const std = @import("std");
const Record = @import("Record.zig");
const Utils = @import("Utils.zig");

pub const AllocatorError = std.mem.Allocator.Error;
pub const ReadError = Utils.ReadError;
pub const ErrorAssertKeyValueLength = Record.ErrorAssertKeyValueLength;
pub const ErrorAssertKeyLength = Record.ErrorAssertKeyLength;

pub const PutError = ErrorAssertKeyValueLength || AllocatorError || ReadError;
pub const GetError = error{ RecordEmpty, TtlExpired, RecordNotFound } || ErrorAssertKeyLength || ReadError;
pub const DelError = ErrorAssertKeyLength || ReadError;
