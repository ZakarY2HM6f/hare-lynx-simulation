const std = @import("std");

const Params = @import("WorldParams.zig");

alive: bool = true,

lifespan: i32 = 0,
food_level: i32,

pub fn init(p: *const Params) @This() {
    return .{
        .food_level = p.hare.food_storage,
    };
}
