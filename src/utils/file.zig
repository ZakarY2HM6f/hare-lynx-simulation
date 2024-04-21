const std = @import("std");
const allocator = std.heap.c_allocator;

const utils = @import("strings.zig");

pub fn saveToJson(filename: []const u8, data: anytype, options: std.json.StringifyOptions) !void {
    const dir = try std.fs.selfExeDirPathAlloc(allocator);
    const path = try std.fs.path.join(allocator, &.{ dir, filename });
    const file = std.fs.openFileAbsolute(path, .{ .mode = .write_only }) catch |err| blk: {
        if (err == error.FileNotFound) {
            break :blk try std.fs.createFileAbsolute(path, .{});
        } else {
            return err;
        }
    };
    defer file.close();

    try std.json.stringify(data, options, file.writer());
}

pub fn loadFromJson(comptime T: type, filename: []const u8, to: *T, options: std.json.ParseOptions) !void {
    const dir = try std.fs.selfExeDirPathAlloc(allocator);
    const path = try std.fs.path.join(allocator, &.{ dir, filename });
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 4096);
    const parsed = try std.json.parseFromSlice(T, allocator, content, options);
    defer parsed.deinit();
    to.* = parsed.value;
}

pub fn saveToCsv(comptime T: type, filename: []const u8, data: []const T) !void {
    const dir = try std.fs.selfExeDirPathAlloc(allocator);
    const path = try std.fs.path.join(allocator, &.{ dir, filename });
    const file = std.fs.openFileAbsolute(path, .{ .mode = .write_only }) catch |err| blk: {
        if (err == error.FileNotFound) {
            break :blk try std.fs.createFileAbsolute(path, .{});
        } else {
            return err;
        }
    };
    defer file.close();
    const writer = file.writer();

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
