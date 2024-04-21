const std = @import("std");
const allocator = std.heap.c_allocator;

const Params = @import("WorldParams.zig");

food_level: i32, 

hare_ids: std.ArrayList(usize),
lynx_ids: std.ArrayList(usize),

pub fn init(p: *const Params) @This() {
    return .{
        .food_level = p.grass.food_storage,
        .hare_ids = std.ArrayList(usize).initCapacity(allocator, 4) catch unreachable,
        .lynx_ids = std.ArrayList(usize).initCapacity(allocator, 4) catch unreachable,
    };
}
