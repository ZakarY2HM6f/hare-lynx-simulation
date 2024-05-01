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

pub fn writeStructAsCsv(comptime T: type, data: T, writer: anytype) !void {
    return _writeStructAsCsv(T, data, writer, "");
}

inline fn _writeStructAsCsv(comptime T: type, data: T, writer: anytype, comptime prefix: []const u8) !void {
    const s = @typeInfo(T).Struct;

    inline for (s.fields) |field| {
        switch (@typeInfo(field.@"type")) {
            .Struct => {
                try _writeStructAsCsv(
                    field.@"type", 
                    @field(data, field.name), 
                    writer, 
                    prefix ++ " " ++ comptime snakeCaseToCamelCase(field.name),
                );
            },
            else => {
                try writer.writeAll(prefix ++ " " ++ comptime snakeCaseToCamelCase(field.name));
                try writer.writeByte(',');
                try std.json.stringify(@field(data, field.name), .{}, writer);
                try writer.writeAll(",\n");
            },
        }
    }
}

pub fn writeSliceAsCsv(comptime T: type, data: []const T, writer: anytype) !void {
    const fields = @typeInfo(T).Struct.fields;

    comptime var header_row: []const u8 = "";
    inline for (fields) |field| {
        header_row = header_row ++ comptime snakeCaseToCamelCase(field.name) ++ ",";
    }
    header_row = header_row ++ "\n";
    try writer.writeAll(header_row);

    for (data) |*datum| {
        inline for (fields) |field| {
            try std.json.stringify(@field(datum, field.name), .{}, writer);
            try writer.writeByte(',');
        }
        try writer.writeByte('\n');
    }
}
