const std = @import("std");
const builtin = @import("builtin");
const allocator = std.heap.c_allocator;

const c = @import("bindings/c.zig");
const nk = @import("bindings/nuklear.zig");
const sdl = @import("bindings/sdl.zig");

const WorldParams = @import("state/WorldParams.zig");
const RenderParams = @import("state/RenderParams.zig");
const World = @import("state/World.zig");
const Analytics = @import("state/Analytics.zig");

const utils = struct {
    usingnamespace @import("utils/gui.zig");
    usingnamespace @import("utils/strings.zig");
    usingnamespace (if (builtin.os.tag == .emscripten) @import("utils/emfile.zig") else @import("utils/file.zig"));
};

const default_wp_filename = "temp/world_params.json";
const default_rp_filename = "temp/render_params.json";
const default_ana_filename = "temp/analytics.csv";

rng: std.Random.DefaultPrng,

world_params: WorldParams = .{},
render_params: RenderParams = .{},

cycle_per_second: i32 = 2,
last_cycle: ?std.time.Instant = null,
running: bool = false,

world: World,

analytics: std.ArrayList(Analytics),

wp_buf: [128]u8 = utils.padRight(default_wp_filename, 128),
wp_len: i32 = @intCast(default_wp_filename.len),
rp_buf: [128]u8 = utils.padRight(default_rp_filename, 128),
rp_len: i32 = @intCast(default_rp_filename.len),
ana_buf: [128]u8 = utils.padRight(default_ana_filename, 128),
ana_len: i32 = @intCast(default_ana_filename.len),

selected: ?struct {
    grass_x: i32,
    grass_y: i32, 
    inner: struct {
        food_level: i32,
        hare_count: i32,
        lynx_count: i32,
    },
} = null,

pub fn init() @This() {
    return .{ 
        .rng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch { seed = 0; };
            break :blk seed;
        }),
        .world = World.init(),
        .analytics = std.ArrayList(Analytics).init(allocator),
    };
}

pub fn deinit(self: *@This()) void {
    self.world.deinit();
    self.analytics.deinit();
}

pub fn paramsGui(self: *@This(), context: nk.Context) !void {
    if (context.beginGUI(
            "[PARAMS]", 
            c.nk_rect(10, 10, 256, 285),
            c.NK_WINDOW_BORDER | c.NK_WINDOW_MOVABLE | c.NK_WINDOW_SCALABLE | c.NK_WINDOW_MINIMIZABLE | c.NK_WINDOW_TITLE,
        )) {
        context.layoutRowDynamic(0, 1);

        context.label("WORLD PARAMS:", c.NK_TEXT_ALIGN_BOTTOM | c.NK_TEXT_ALIGN_LEFT);
        utils.fieldProperties(context, &self.world_params);

        if (context.buttonLabel("restore defaults")) {
            self.world_params = .{};
            std.debug.print("parameters restored to default\n", .{});
        }

        context.layoutRowDynamic(0, 2);
        if (builtin.os.tag == .emscripten) {
            if (context.buttonLabel("save")) {
                if (utils.saveToJson("world_params.json", self.world_params)) {
                    std.debug.print("saved world parameters to json\n", .{});
                } else |err| {
                    std.debug.print("save to json failed: {!}\n", .{ err });
                }
            }
            if (context.buttonLabel("load")) {
                if (utils.loadFromJson(&self.world_params)) {
                    std.debug.print("loaded world parameters from json\n", .{});
                } else |err| {
                    std.debug.print("load from json failed: {!}\n", .{ err });
                }
            }
        } else {
            const wp_filename = context.editString(&self.wp_buf, &self.wp_len, c.NK_EDIT_FIELD, null).str;

            if (context.buttonLabel("save")) {
                if (utils.saveToJson(wp_filename, self.world_params)) {
                    std.debug.print("saved world parameters to json\n", .{});
                } else |err| {
                    std.debug.print("save to json failed: {!}\n", .{ err });
                }
            }
            if (context.buttonLabel("load")) {
                if (utils.loadFromJson(wp_filename, &self.world_params)) {
                    std.debug.print("loaded world parameters from json\n", .{});
                } else |err| {
                    std.debug.print("load from json failed: {!}\n", .{ err });
                }
            }
        }

        context.layoutRowDynamic(0, 1);
        context.spacer();

        context.label("RENDER PARAMS:", c.NK_TEXT_ALIGN_BOTTOM | c.NK_TEXT_ALIGN_LEFT);
        utils.fieldProperties(context, &self.render_params);

        if (context.buttonLabel("restore defaults")) {
            self.render_params = .{};
            std.debug.print("parameters restored to default\n", .{});
        }

        context.layoutRowDynamic(0, 2);
        if (builtin.os.tag == .emscripten) {
            if (context.buttonLabel("save")) {
                if (utils.saveToJson("render_params.json", self.render_params)) {
                    std.debug.print("saved render parameters to json\n", .{});
                } else |err| {
                    std.debug.print("save to json failed: {!}\n", .{ err });
                }
            }
            if (context.buttonLabel("load")) {
                if (utils.loadFromJson(&self.render_params)) {
                    std.debug.print("loaded render parameters from json\n", .{});
                } else |err| {
                    std.debug.print("load from json failed: {!}\n", .{ err });
                }
            }
        } else {
            const rp_filename = context.editString(&self.rp_buf, &self.rp_len, c.NK_EDIT_FIELD, null).str;

            if (context.buttonLabel("save")) {
                if (utils.saveToJson(rp_filename, self.render_params)) {
                    std.debug.print("saved render parameters to json\n", .{});
                } else |err| {
                    std.debug.print("save to json failed: {!}\n", .{ err });
                }
            }
            if (context.buttonLabel("load")) {
                if (utils.loadFromJson(rp_filename, &self.render_params)) {
                    std.debug.print("loaded render parameters from json\n", .{});
                } else |err| {
                    std.debug.print("load from json failed: {!}\n", .{ err });
                }
            }
        }
    }
    context.endGUI();
}

pub fn controlsGui(self: *@This(), context: nk.Context) !void {
    if (context.beginGUI(
        "[CONTROLS]", 
        c.nk_rect(10, 305, 256, 285),
        c.NK_WINDOW_BORDER | c.NK_WINDOW_MOVABLE | c.NK_WINDOW_SCALABLE | c.NK_WINDOW_MINIMIZABLE | c.NK_WINDOW_TITLE,
    )) {
        context.layoutRowDynamic(0, 1);
        context.property(
            i32, 
            "Cycle per Second", 
            0, 
            &self.cycle_per_second, 
            10000, 
            1,
            1,
        );

        context.layoutRowDynamic(0, 3);
        if (self.running) {
            if (context.buttonLabel("stop")) {
                self.running = false;
            }
        } else {
            if (context.buttonLabel("start")) {
                if (!self.world.ready()) {
                    try self.world.setup(self.world_params);
                }
                self.running = true;
            }
        }
        if (context.buttonLabel("step")) {
            self.running = false;
            if (!self.world.ready()) {
                try self.world.setup(self.world_params);
            }
            try self.world.step(self.rng.random());
            try self.analytics.append(self.world.analytics);
        }
        if (context.buttonLabel("reset")) {
            self.running = false;
            self.world.clear();
            self.selected = null;
            self.analytics.clearRetainingCapacity();
        }

        if (self.world.ready()) {
            const d = &self.render_params;

            context.layoutRowDynamic(15, 1);

            if (self.selected) |selected| {
                var buf = [1]u8{0} ** 128;
                const grass_str = try std.fmt.bufPrint(
                    &buf, 
                    "Grass: ({}, {})", 
                    .{ selected.grass_x, selected.grass_y },
                );
                context.label(grass_str, c.NK_TEXT_LEFT);

                utils.fieldValues(context, &selected.inner);
            }

            context.spacer();

            if (self.analytics.getLastOrNull()) |la| {
                context.layoutRowDynamic(15, 1);
                context.value(i32, "Cycle", la.cycle);
                context.value(f32, "Grass Level", la.grass_food_level);

                context.label("Hare:", c.NK_TEXT_ALIGN_BOTTOM | c.NK_TEXT_ALIGN_LEFT);
                context.value(i32, "Population", la.hare_population);
                context.value(f32, "Food Level", la.hare_food_level);
                context.layoutRowDynamic(15, 2);
                context.value(i32, "Births", la.hare_births);
                context.value(i32, "Deaths", la.hare_deaths);

                context.layoutRowDynamic(15, 1);
                context.label("Lynx:", c.NK_TEXT_ALIGN_BOTTOM | c.NK_TEXT_ALIGN_LEFT);
                context.value(i32, "Population", la.lynx_population);
                context.value(f32, "Food Level", la.lynx_food_level);
                context.layoutRowDynamic(15, 2);
                context.value(i32, "Births", la.lynx_births);
                context.value(i32, "Deaths", la.lynx_deaths);

                context.layoutRowDynamic(d.chart.height, 1);
                if (context.chartBeginEx(
                    c.NK_CHART_LINES, 
                    d.chart.width, 
                    0, 
                    d.chart.grass_max,
                    .{ .r = 0, .g = 255, .b = 0, .a = 255 },
                    .{ .r = 0, .g = 255, .b = 0, .a = 255 },
                )) {
                    context.chartAddSlotEx(
                        c.NK_CHART_LINES, 
                        d.chart.width,
                        0, 
                        d.chart.hare_max,
                        .{ .r = 0, .g = 0, .b = 255, .a = 255 },
                        .{ .r = 0, .g = 0, .b = 255, .a = 255 },
                    );
                    context.chartAddSlotEx(
                        c.NK_CHART_LINES, 
                        d.chart.width,
                        0, 
                        d.chart.lynx_max,
                        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
                        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
                    );

                    const start_index = if (self.analytics.items.len < d.chart.width) 0
                                        else (self.analytics.items.len - @as(usize, @intCast(d.chart.width)));
                    for (self.analytics.items[start_index..]) |ana| {
                        _ = context.chartPushSlot(ana.grass_food_level, 0);
                        _ = context.chartPushSlot(@floatFromInt(ana.hare_population), 1);
                        _ = context.chartPushSlot(@floatFromInt(ana.lynx_population), 2);
                    }
                }
                context.chartEnd();

                context.layoutRowDynamic(0, 1);
                if (builtin.os.tag == .emscripten) {
                    if (context.buttonLabel("Export CSV")) {
                        var buf = std.ArrayList(u8).init(allocator);
                        defer buf.deinit();

                        try utils.writeStructAsCsv(WorldParams, self.world.params, buf.writer());
                        try utils.writeSliceAsCsv(Analytics, self.analytics.items, buf.writer());

                        try utils.save("analytics.csv", "text/csv", buf.items);
                    }
                } else {
                    const ana_filename = context.editString(&self.ana_buf, &self.ana_len, c.NK_EDIT_FIELD, null).str;
                    if (context.buttonLabel("Export CSV")) {
                        const file = try utils.openFile(ana_filename);
                        defer file.close();

                        try utils.writeStructAsCsv(WorldParams, self.world.params, file.writer());
                        try utils.writeSliceAsCsv(Analytics, self.analytics.items, file.writer());
                    }
                }
            }
        }
    }
    context.endGUI();
}

pub fn runCycle(self: *@This()) !void {
    if (!self.running) return;

    const now = try std.time.Instant.now();
    var run = false;
    if (self.last_cycle) |last_cycle| {
        if (now.since(last_cycle) >= @divFloor(1000000000, self.cycle_per_second)) {
            run = true;
        }
    } else {
        run = true;
    }

    if (run) {
        self.last_cycle = now;
        try self.world.step(self.rng.random());
        try self.analytics.append(self.world.analytics);
    }
}

pub fn draw(self: *const @This(), renderer: sdl.Renderer) !void {
    if (!self.world.ready()) return;

    const p = &self.world.params;
    const d = &self.render_params;
    
    var tile_rect = c.SDL_FRect{ 
        .x = undefined,
        .y = undefined,
        .w = d.world_rect.w / @as(f32, @floatFromInt(p.world_dimension)), 
        .h = d.world_rect.h / @as(f32, @floatFromInt(p.world_dimension)),
    };
    for (self.world.grass, 0..) |tile, i| {
        const ii: i32 = @intCast(i);
        const tx = @mod(ii, p.world_dimension);
        const ty = @divFloor(ii, p.world_dimension);
        tile_rect.x = d.world_rect.x + 
            @as(f32, @floatFromInt(tx)) / 
            @as(f32, @floatFromInt(p.world_dimension)) * 
            d.world_rect.w;
        tile_rect.y = d.world_rect.y + 
            @as(f32, @floatFromInt(ty)) / 
            @as(f32, @floatFromInt(p.world_dimension)) * 
            d.world_rect.h;

        var hare_count: i32 = 0;
        var lynx_count: i32 = 0;
        for (tile.animals) |a| {
            if (!a.alive) continue;
            switch (a.kind) {
                .hare => hare_count += 1,
                .lynx => lynx_count += 1,
            }
        }

        const total = hare_count + lynx_count + 1; 
        const r = @divFloor(lynx_count * d.color.lynx, total);
        const g = @divFloor(tile.food_level * d.color.grass, p.grass.food_storage);
        const b = @divFloor(hare_count * d.color.hare, total);

        try renderer.setDrawColor(
            @intCast(std.math.clamp(- g - b + r, 0, 255)),
            @intCast(std.math.clamp(- r - b + g, 0, 255)),
            @intCast(std.math.clamp(- r - g + b, 0, 255)),
            255,
        );
        try renderer.fillRect(&tile_rect);
    }
}

pub fn handleEvent(self: *@This(), event: *const c.SDL_Event) void {
    if (!self.world.ready()) return;

    const p = &self.world.params;
    const d = &self.render_params;

    switch(event.@"type") {
        c.SDL_MOUSEBUTTONUP => {
            const mp = c.SDL_FPoint{
                .x = @floatFromInt(event.button.x),
                .y = @floatFromInt(event.button.y),
            };
            if (c.SDL_PointInFRect(&mp, &d.world_rect) != 0) {
                const tx: usize = @intFromFloat((mp.x - d.world_rect.x) / d.world_rect.w * @as(f32, @floatFromInt(p.world_dimension)));
                const ty: usize = @intFromFloat((mp.y - d.world_rect.y) / d.world_rect.h * @as(f32, @floatFromInt(p.world_dimension)));
                const ti = ty * @as(usize, @intCast(p.world_dimension)) + tx;

                const g = &self.world.grass[ti];

                var hare_count: i32 = 0;
                var lynx_count: i32 = 0;
                for (g.animals) |a| {
                    if (!a.alive) continue;
                    switch (a.kind) {
                        .hare => hare_count += 1,
                        .lynx => lynx_count += 1,
                    }
                }

                self.selected = .{
                    .grass_x = @intCast(tx),
                    .grass_y = @intCast(ty),
                    .inner = .{
                        .food_level = g.food_level,
                        .hare_count = hare_count,
                        .lynx_count = lynx_count,
                    },
                };
            } else {
                self.selected = null;
            }
        },
        else => {},
    }
}
