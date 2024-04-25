const std = @import("std");
const allocator = std.heap.c_allocator;

const utils = @import("strings.zig");

pub fn openFile(filename: []const u8) !std.fs.File {
    const dir = try std.fs.selfExeDirPathAlloc(allocator);
    const path = try std.fs.path.join(allocator, &.{ dir, filename });
    return std.fs.openFileAbsolute(path, .{ .mode = .read_write }) catch |err| blk: {
        if (err != error.FileNotFound) return err;
        break :blk try std.fs.createFileAbsolute(path, .{});
    };
}

pub fn saveToJson(filename: []const u8, data: anytype, options: std.json.StringifyOptions) !void {
    const file = try openFile(filename);
    defer file.close();

    try file.seekTo(0);
    try std.json.stringify(data, options, file.writer());
}

pub fn loadFromJson(filename: []const u8, to: anytype, options: std.json.ParseOptions) !void {
    const s = @typeInfo(@TypeOf(to)).Pointer.child;

    const file = try openFile(filename);
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 4096);
    const parsed = try std.json.parseFromSlice(s, allocator, content, options);
    defer parsed.deinit();
    to.* = parsed.value;
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
                    prefix ++ " " ++ comptime utils.snakeCaseToCamelCase(field.name),
                );
            },
            else => {
                try writer.writeAll(prefix ++ " " ++ comptime utils.snakeCaseToCamelCase(field.name));
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
        header_row = header_row ++ comptime utils.snakeCaseToCamelCase(field.name) ++ ",";
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
