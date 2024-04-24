const std = @import("std");

const Params = @import("WorldParams.zig");
const Analytics = @import("Analytics.zig");

const Grass = @import("Grass.zig");
const Animal = @import("Animal.zig");

const utils = @import("../utils/math.zig");

cycle: i32 = -1,
analytics: Analytics = undefined,

params: Params = undefined,

arena: std.heap.ArenaAllocator,

grass: []Grass = undefined,
animals: []Animal = undefined,

pub fn init() @This() {
    return .{
        .arena = std.heap.ArenaAllocator.init(std.heap.c_allocator),
    };
}

pub fn deinit(self: *@This()) void {
    self.arena.deinit();
}

pub fn setup(self: *@This(), p: Params) !void {
    _ = self.arena.reset(.retain_capacity);
    const allocator = self.arena.allocator();

    const tile_count = p.world_dimension * p.world_dimension;
    self.grass = try allocator.alloc(Grass, @intCast(tile_count));
    for (self.grass) |*g| {
        g.* = try Grass.init(&p, allocator);
    }
    
    const max_animal_count: usize = @intCast(p.max_populationn_density * tile_count);
    self.animals = try allocator.alloc(Animal, max_animal_count);
    for (self.animals, 0..max_animal_count) |*a, i| {
        if (i < p.hare.initial_population) {
            a.* = Animal.initHare(&p);
        } else if (i < p.hare.initial_population + p.lynx.initial_population) {
            a.* = Animal.initLynx(&p);
        } else {
            a.* = Animal.initDead();
        }
    }

    self.params = p;
    self.cycle = 0;
}

pub fn clear(self: *@This()) void {
    _ = self.arena.reset(.retain_capacity);
    self.cycle = -1;
}

pub fn ready(self: *const @This()) bool {
    return self.cycle >= 0;
}

pub fn step(self: *@This(), random: std.Random) !void {
    self.photosynthesis();

    try self.randomizePosition(random);
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
    var lynx_population: i32 = 0;
    var hare_food_level: i32 = 0;
    var lynx_food_level: i32 = 0;

    for (self.animals) |a| {
        if (a.alive) {
            switch (a.kind) { 
                .hare => hare_population += 1,
                .lynx => lynx_population += 1,
            }
            switch (a.kind) { 
                .hare => hare_food_level += a.food_level, 
                .lynx => lynx_food_level += a.food_level,
            }
        }
    }
    self.analytics.hare_population = hare_population;
    self.analytics.lynx_population = lynx_population;
    self.analytics.hare_food_level = if (hare_population > 0) utils.divFloat(f32, hare_food_level, hare_population) else 0;
    self.analytics.lynx_food_level = if (lynx_population > 0) utils.divFloat(f32, lynx_food_level, lynx_population) else 0;

    self.analytics.cycle = self.cycle;
}

fn randomizePosition(self: *@This(), random: std.Random) !void {
    const p = &self.params;

    for (self.grass) |*g| {
        g.animal_count = 0;
    }

    for (self.animals) |*a| {
        var i = random.uintAtMost(usize, self.grass.len - 1);
        while (self.grass[i].animal_count >= p.max_populationn_density) {
            i = @mod(i + 1, self.grass.len);
        }
        const g = &self.grass[i];
        g.animals[g.animal_count] = a;
        g.animal_count += 1;
    }
}

fn horngry(self: *@This()) !void {
    const p = &self.params;

    var new_hare_count: i32 = 0;
    var new_lynx_count: i32 = 0;

    for (self.grass) |g| {
        var breedable_hare: ?*Animal = null;
        var breedable_lynx: ?*Animal = null;

        for (g.animals) |a| {
            if (!a.alive) continue;

            const survival_cost = switch (a.kind) {
                .hare => p.hare.survival_cost,
                .lynx => p.lynx.survival_cost,
            };
            const reproduction_cost = switch (a.kind) {
                .hare => p.hare.reproduction_cost,
                .lynx => p.lynx.reproduction_cost,
            };
            const breedable = switch (a.kind) {
                .hare => &breedable_hare,
                .lynx => &breedable_lynx,
            };
            const new_count = switch (a.kind) {
                .hare => &new_hare_count,
                .lynx => &new_lynx_count,
            };

            a.food_level -= survival_cost;
            while (a.food_level >= reproduction_cost) {
                if (breedable.*) |b| {
                    a.food_level -= reproduction_cost;
                    b.food_level -= reproduction_cost;
                    new_count.* += 1;
                    breedable.* = if (b.food_level >= reproduction_cost) b else null;
                } else {
                    breedable.* = a;
                    break;
                }
            }
        }
    }

    self.analytics.hare_births = 0;
    self.analytics.lynx_births = 0;

    for (self.animals) |*a| {
        if (a.alive) continue;

        if (new_hare_count > 0) {
            a.* = Animal.initHare(p);
            new_hare_count -= 1;
            self.analytics.hare_births += 1;
        } else if (new_lynx_count > 0) {
            a.* = Animal.initLynx(p);
            new_lynx_count -= 1;
            self.analytics.lynx_births += 1;
        }
    }
}

fn photosynthesis(self: *@This()) void {
    const p = &self.params;

    for (self.grass) |*g| {
        g.food_level = std.math.clamp(
            g.food_level + p.grass.growth_rate, 
            0, 
            p.grass.food_storage,
        );
    }
}

fn predation(self: *@This()) void {
    const p = &self.params;

    self.analytics.hare_deaths = 0;

    for (self.grass) |*g| {
        var hare_count: i32 = 0;
        var lynx_count: i32 = 0;
        for (g.animals) |a| {
            if (!a.alive) continue;
            switch (a.kind) {
                .hare => hare_count += 1,
                .lynx => lynx_count += 1,
            }
        }

        const hare_food_available = if (hare_count > 0) @divFloor(g.food_level, hare_count) else 0;
        const lynx_food_available = if (lynx_count > 0) @divFloor(hare_count, lynx_count) else 0;

        for (g.animals) |a| {
            if (!a.alive) continue;

            const food_storage = switch (a.kind) {
                .hare => p.hare.food_storage,
                .lynx => p.lynx.food_storage,
            };

            if (a.food_level >= food_storage) continue;

            const food_available = switch (a.kind) {
                .hare => hare_food_available,
                .lynx => lynx_food_available,
            };
            const food_value = switch (a.kind) {
                .hare => p.hare.grass_food_value,
                .lynx => p.lynx.hare_food_value,
            };

            const food_needed = food_storage - a.food_level;
            var eaten: i32 = undefined;
            if (food_available * food_value > food_needed) {
                eaten = @divFloor(food_needed, food_value);
            } else {
                eaten = food_available;
            }

            a.food_level += eaten * food_value;
            switch (a.kind) {
                .hare => g.food_level -= eaten,
                .lynx => { 
                    self.analytics.hare_deaths += eaten;

                    var i: usize = 0;
                    while (eaten > 0) {
                        const b = g.animals[i];
                        if (b.alive and b.kind == .hare) {
                            b.alive = false;
                            eaten -= 1;
                        }
                        i += 1;
                    }
                },
            }
        }
    }
}

fn grim_reaper(self: *@This()) void {
    const p = &self.params;

    self.analytics.lynx_deaths = 0;

    for (self.animals) |*a| {
        if (!a.alive) continue;

        const max_lifespan = switch (a.kind) {
            .hare => p.hare.max_lifespan,
            .lynx => p.lynx.max_lifespan,
        };

        a.lifespan += 1;

        if (a.food_level <= 0 or a.lifespan > max_lifespan) {
            a.alive = false;
            switch (a.kind) {
                .hare => self.analytics.hare_deaths += 1,
                .lynx => self.analytics.lynx_deaths += 1,
            }
        }
    }
}
