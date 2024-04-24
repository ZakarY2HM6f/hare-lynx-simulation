const std = @import("std");

const Params = @import("WorldParams.zig");

pub const Kind = enum { hare, lynx };

alive: bool,
kind: Kind,

lifespan: i32 = 0,
food_level: i32,

pub fn initDead() @This() {
    return .{
        .alive = false,
        .kind = undefined,
        .food_level = 0,
    };
}

pub fn initHare(p: *const Params) @This() {
    return .{
        .alive = true,
        .kind = .hare,
        .food_level = p.hare.initial_food_level,
    };
}

pub fn initLynx(p: *const Params) @This() {
    return .{
        .alive = true,
        .kind = .lynx,
        .food_level = p.lynx.initial_food_level,
    };
}
