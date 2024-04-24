const std = @import("std");

const Params = @import("WorldParams.zig");
const Animal = @import("Animal.zig");

food_level: i32, 
animals: []*Animal,

animal_count: usize = 0,

pub fn init(p: *const Params, allocator: std.mem.Allocator) !@This() {
    return .{
        .food_level = p.grass.food_storage,
        .animals = try allocator.alloc(*Animal, @intCast(p.max_populationn_density)),
    };
}
