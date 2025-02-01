pub const Error = enum(u8) {
    KeyTooLong = 0,
    ValueTooLong = 1,
    OutOfMemory = 2,
    RecordEmpty = 3,
    TtlExpired = 4,
    RecordNotFound = 5,
    NotEnoughBytes = 6,
    NoReturn = 7,
    CommandNotFound = 8,
};

pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: u8,
    };
}

pub fn is_ok(result: anytype) bool {
    return result == .ok;
}

pub fn is_err(result: anytype) bool {
    return result == .err;
}
