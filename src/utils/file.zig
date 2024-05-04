const std = @import("std");
const allocator = std.heap.c_allocator;

const utils = @import("strings.zig");

pub fn openFile(filename: []const u8) !std.fs.File {
    const cwd = std.fs.cwd();
    return cwd.openFile(filename, .{ .mode = .read_write }) catch |err| blk: {
        if (err != error.FileNotFound) return err;
        break :blk try cwd.createFile(filename, .{});
    };
}

pub fn saveToJson(filename: []const u8, data: anytype) !void {
    const file = try openFile(filename);
    defer file.close();

    try file.seekTo(0);
    try std.json.stringify(
        data,
        .{ .whitespace = .indent_tab },
        file.writer(),
    );
}

pub fn loadFromJson(filename: []const u8, to: anytype) !void {
    const s = @typeInfo(@TypeOf(to)).Pointer.child;

    const file = try openFile(filename);
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 4096);
    const parsed = try std.json.parseFromSlice(s, allocator, content, .{});
    defer parsed.deinit();
    to.* = parsed.value;
}
