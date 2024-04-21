const std = @import("std");
const allocator = std.heap.c_allocator;

const Params = @import("WorldParams.zig");
const Analytics = @import("Analytics.zig");

const Grass = @import("Grass.zig");
const Hare = @import("Hare.zig");
const Lynx = @import("Lynx.zig");

const utils = @import("../utils/math.zig");

cycle: i32 = -1,
analytics: Analytics = undefined,

random: std.Random = undefined,
params: Params = undefined,

grass: []Grass = undefined,
hares: std.ArrayList(Hare) = undefined,
lynxes: std.ArrayList(Lynx) = undefined,

pub fn init(self: *@This(), random: std.Random, params: Params) !void {
    std.debug.assert(!self.ready());

    self.random = random;
    self.params = params;

    self.grass = try allocator.alloc(
        Grass, 
        @intCast(self.params.world_dimension * self.params.world_dimension),
    );
    errdefer allocator.free(self.grass);
    for (self.grass) |*g| {
        g.* = Grass.init(&self.params);
    }

    self.hares = try std.ArrayList(Hare).initCapacity(
        allocator, 
        @intCast(self.params.hare.initial_population * 2),
    );
    errdefer self.hares.deinit();
    try self.hares.appendNTimes(
        Hare.init(&self.params), 
        @intCast(self.params.hare.initial_population),
    );

    self.lynxes = try std.ArrayList(Lynx).initCapacity(
        allocator, 
        @intCast(self.params.lynx.initial_population * 2),
    );
    errdefer self.lynxes.deinit();
    try self.lynxes.appendNTimes(
        Lynx.init(&self.params), 
        @intCast(self.params.lynx.initial_population),
    );

    self.cycle = 0;
}

pub fn deinit(self: *@This()) void {
    std.debug.assert(self.ready());

    allocator.free(self.grass);
    self.hares.deinit();
    self.lynxes.deinit();

    self.cycle = -1;
}

pub fn ready(self: *const @This()) bool {
    return self.cycle >= 0;
}

pub fn step(self: *@This()) !void {
    self.photosynthesis();

    try self.randomizePosition();
    try self.horngry();
    self.predation();

    self.grim_reaper();

    self.cycle += 1;
    self.updateAnalytics();
}

fn updateAnalytics(self: *@This()) void {
    var grass_food_level: i32 = 0;
    for (self.grass) |g| {
        grass_food_level += g.food_level;
    }
    self.analytics.grass_food_level = utils.divFloat(f32, grass_food_level, self.grass.len);

    var hare_population: i32 = 0;
    var hare_food_level: i32 = 0;
    for (self.hares.items) |h| {
        if (h.alive) {
            hare_population += 1;
            hare_food_level += h.food_level;
        }
    }
    self.analytics.hare_population = hare_population;
    self.analytics.hare_food_level = utils.divFloat(f32, hare_food_level, hare_population);

    var lynx_population: i32 = 0;
    var lynx_food_level: i32 = 0;
    for (self.lynxes.items) |l| {
        if (l.alive) {
            lynx_population += 1;
            lynx_food_level += l.food_level;
        }
    }
    self.analytics.lynx_population = lynx_population;
    self.analytics.lynx_food_level = utils.divFloat(f32, lynx_food_level, lynx_population);

    self.analytics.cycle = self.cycle;
}

fn randomizePosition(self: *@This()) !void {
    const p = &self.params;

    for (self.grass) |*g| {
        g.hare_ids.clearRetainingCapacity();
        g.lynx_ids.clearRetainingCapacity();
    }

    const max_grass_index: usize = @intCast(p.world_dimension * p.world_dimension - 1);
    for (self.hares.items, 0..) |hare, ai| {
        if (!hare.alive) continue;

        const ti = self.random.uintAtMost(usize, max_grass_index);
        try self.grass[ti].hare_ids.append(ai);
    }
    for (self.lynxes.items, 0..) |lynx, ai| {
        if (!lynx.alive) continue;

        const ti = self.random.uintAtMost(usize, max_grass_index);
        try self.grass[ti].lynx_ids.append(ai);
    }
}

fn horngry(self: *@This()) !void {
    const p = &self.params;

    var new_hare_count: i32 = 0;
    var new_lynx_count: i32 = 0;

    for (self.grass) |tile| {
        var breedable_id: ?usize = null;
        for (tile.hare_ids.items) |ia| {
            const ha = &self.hares.items[ia];
            ha.food_level -= p.hare.survival_cost;

            if (ha.food_level >= p.hare.reproduction_cost) {
                if (breedable_id) |ib| {
                    const hb = &self.hares.items[ib];
                    ha.food_level -= p.hare.reproduction_cost;
                    hb.food_level -= p.hare.reproduction_cost;
                    new_hare_count += 1;
                    breedable_id = null;
                } else {
                    breedable_id = ia;
                }
            }
        }

        breedable_id = null;
        for (tile.lynx_ids.items) |ia| {
            const la = &self.lynxes.items[ia];
            la.food_level -= p.lynx.survival_cost;

            if (la.food_level >= p.lynx.reproduction_cost) {
                if (breedable_id) |ib| {
                    const lb = &self.lynxes.items[ib];
                    la.food_level -= p.lynx.reproduction_cost;
                    lb.food_level -= p.lynx.reproduction_cost;
                    new_lynx_count += 1;
                    breedable_id = null;
                } else {
                    breedable_id = ia;
                }
            }
        }
    }

    self.analytics.hare_births = new_hare_count;
    self.analytics.lynx_births = new_lynx_count;

    for (self.hares.items) |*h| {
        if (new_hare_count > 0 and !h.alive) {
            h.* = Hare.init(p);
            new_hare_count -= 1;
        }
    }
    if (new_hare_count > 0) {
        try self.hares.appendNTimes(
            .{ .food_level = std.math.clamp(@divFloor(p.hare.reproduction_cost * 16, 9), 0, p.hare.food_storage) }, 
            @intCast(new_hare_count),
        );
    }

    for (self.lynxes.items) |*l| {
        if (new_lynx_count > 0 and !l.alive) {
            l.* = Lynx.init(p);
            new_lynx_count -= 1;
        }
    }
    if (new_lynx_count > 0) {
        try self.lynxes.appendNTimes(
            .{ .food_level = std.math.clamp(@divFloor(p.lynx.reproduction_cost * 16, 9), 0, p.lynx.food_storage) }, 
            @intCast(new_lynx_count),
        );
    }
}

fn photosynthesis(self: *@This()) void {
    const p = &self.params;

    for (self.grass) |*tile| {
        tile.food_level = std.math.clamp(
            tile.food_level + p.grass.growth_rate, 
            0, 
            p.grass.food_storage,
        );
    }
}

fn predation(self: *@This()) void {
    const p = &self.params;

    self.analytics.hare_deaths = 0;

    for (self.grass) |*tile| {
        if (tile.hare_ids.items.len > 0) {
            const food_available = @divFloor(
                tile.food_level, 
                @as(i32, @intCast(tile.hare_ids.items.len)),
            );

            for (tile.hare_ids.items) |i| {
                const hare = &self.hares.items[i];

                if (hare.food_level >= p.hare.food_storage) continue;

                const food_needed = p.hare.food_storage - hare.food_level;
                const food_eaten = blk: {
                    if (food_needed < food_available * p.hare.grass_food_value) {
                        break :blk @divFloor(food_needed, p.hare.grass_food_value);
                    } else {
                        break :blk food_available;
                    }
                };

                hare.food_level += food_eaten * p.hare.grass_food_value;
                tile.food_level -= food_eaten;
            }
        }

        if (tile.lynx_ids.items.len > 0) {
            const food_available: i32 = @intCast(@divFloor(
                tile.hare_ids.items.len, 
                tile.lynx_ids.items.len,
            ));

            var eaten: usize = 0;
            for (tile.lynx_ids.items) |i| {
                const lynx = &self.lynxes.items[i];

                if (lynx.food_level >= p.lynx.food_storage) continue;

                const food_needed = p.lynx.food_storage - lynx.food_level;
                const food_eaten = blk: {
                    if (food_needed < food_available * p.lynx.hare_food_value) {
                        break :blk @divFloor(food_needed, p.lynx.hare_food_value);
                    } else {
                        break :blk food_available;
                    }
                };

                for (0..@intCast(food_eaten)) |_| {
                    self.hares.items[tile.hare_ids.items[eaten]].alive = false;
                    eaten += 1;
                }
                lynx.food_level += food_eaten * p.lynx.hare_food_value;
                self.analytics.hare_deaths += food_eaten;
            }
        }
    }
}

fn grim_reaper(self: *@This()) void {
    const p = &self.params;

    self.analytics.lynx_deaths = 0;

    for (self.hares.items) |*hare| {
        if (!hare.alive) continue;
        hare.lifespan += 1;
        if (hare.lifespan > p.hare.max_lifespan or hare.food_level <= 0) {
            hare.alive = false;
            self.analytics.hare_deaths += 1;
        }
    }

    for (self.lynxes.items) |*lynx| {
        if (!lynx.alive) continue;
        lynx.lifespan += 1;
        if (lynx.lifespan > p.lynx.max_lifespan or lynx.food_level <= 0) {
            lynx.alive = false;
            self.analytics.lynx_deaths += 1;
        }
    }
}
