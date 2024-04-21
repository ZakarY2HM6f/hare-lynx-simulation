const c = @import("../bindings/c.zig");

world_rect: c.SDL_FRect = .{
    .x = 276,
    .y = 43,
    .w = 513,
    .h = 513,
},

color: struct {
    grass: i32 = 180,
    hare: i32 = 600,
    lynx: i32 = 600,
} = .{},

chart: struct {
    height: f32 = 150,
    width: i32 = 80,
    grass_max: f32 = 5,
    hare_max: f32 = 500,
    lynx_max: f32 = 50,
} = .{},
