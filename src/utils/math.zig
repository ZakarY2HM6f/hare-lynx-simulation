pub inline fn divFloat(comptime T: type, a: anytype, b: anytype) T {
    return @as(T, @floatFromInt(a)) / @as(T, @floatFromInt(b));
}
