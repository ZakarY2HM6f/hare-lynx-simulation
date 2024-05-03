const std = @import("std");
const allocator = std.heap.c_allocator;

const em = @import("../bindings/em.zig");

pub fn saveToJson(filename: []const u8, data: anytype) !void {
    const content = try std.json.stringifyAlloc(allocator, data, .{});
    try save(filename, "application/json", content);
}

pub fn save(filename: []const u8, mime_type: []const u8, data: []const u8) !void {
    var buf = [1]u8{0} ** 128;
    const js = try std.fmt.bufPrint(
        &buf, 
        "download('{s}', '{s}', {d}, {d})", 
        .{ filename, mime_type, @intFromPtr(data.ptr), data.len },
    );
    em.emscripten_run_script(js.ptr);
}

pub fn loadFromJson(to: anytype) !void {
    const s = @typeInfo(@TypeOf(to)).Pointer.child;
    var buf = [1]u8{0} ** 128;
    const js = try std.fmt.bufPrint(
        &buf, 
        "upload('application/json', {d}, {d})", 
        .{ @intFromPtr(&genUploadCallback(s)), @intFromPtr(to) },
    );
    em.emscripten_run_script(js.ptr);
}

const UploadCallback = fn(*anyopaque, [*c]const u8, usize) void;

fn genUploadCallback(comptime T: type) UploadCallback {
    const U = struct {
        fn _uploadCallback(to: *anyopaque, buf: [*c]const u8, len: usize) void {
            const parsed = std.json.parseFromSlice(T, allocator, buf[0..len], .{}) catch return;
            defer parsed.deinit();
            @as(*T, @ptrCast(@alignCast(to))).* = parsed.value;
        }
    };
    return U._uploadCallback;
}

export fn uploadCallback(
    callback: usize, 
    to: usize, 
    buf: usize, 
    len: usize,
) callconv(.C) void {
    @as(*const UploadCallback, @ptrFromInt(callback))(@ptrFromInt(to), @ptrFromInt(buf), len);
}
