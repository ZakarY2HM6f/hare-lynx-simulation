const std = @import("std");

pub fn snakeCaseToCamelCase(comptime snake: []const u8) [:0]const u8 {
    comptime var camel: [:0]const u8 = "";
    comptime var first = false;
    comptime var underscore = false;
    inline for (snake) |ch| {
        if (!first) {
            camel = camel ++ [_]u8{ comptime std.ascii.toUpper(ch) };
            first = true;
        } else if (underscore) {
            camel = camel ++ [_]u8{ comptime std.ascii.toUpper(ch) };
            underscore = false;
        } else if (ch == '_') {
            camel = camel ++ " ";
            underscore = true;
        } else {
            camel = camel ++ [_]u8{ ch };
        }
    }

    return camel;
}

pub fn padRight(comptime smol: anytype, comptime len: usize) [len]u8 {
    return smol.* ++ [_]u8{0} ** (len - smol.len);
}
