const std = @import("std");

const c = @import("bindings/c.zig");
const sdl = @import("bindings/sdl.zig");
const nk = @import("bindings/nuklear.zig");

const State = @import("State.zig");

const title = "[HARE x LYNX]";
const width = 800;
const height = 600;

threadlocal var window: sdl.Window = undefined;
threadlocal var renderer: sdl.Renderer = undefined;
threadlocal var context: nk.Context = undefined;

pub fn main() !void {
    //
    // BEGIN initialization
    //
    try sdl.init(c.SDL_INIT_EVERYTHING);
    defer sdl.quit();

    window = try sdl.Window.create(
        title,
        c.SDL_WINDOWPOS_CENTERED, 
        c.SDL_WINDOWPOS_CENTERED,
        width, 
        height,
        c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_ALLOW_HIGHDPI,
    );
    defer window.destroy();

    renderer = try sdl.Renderer.create(
        window, 
        -1, 
        c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC,
    );
    defer renderer.destroy();

    // high-DPI scaling
    const font_scale = blk: {
        var render_w: i32 = undefined;
        var render_h: i32 = undefined;
        var window_w: i32 = undefined;
        var window_h: i32 = undefined;
        _ = c.SDL_GetRendererOutputSize(renderer.ptr, &render_w, &render_h);
        _ = c.SDL_GetWindowSize(window.ptr, &window_w, &window_h);
        const scale_x = @as(f32, @floatFromInt(render_w)) / @as(f32, @floatFromInt(window_w));
        const scale_y = @as(f32, @floatFromInt(render_h)) / @as(f32, @floatFromInt(window_h));
            _ = c.SDL_RenderSetScale(renderer.ptr, scale_x, scale_y);

        break :blk scale_y;
    };

    context = try nk.Context.sdlInit(window, renderer);
    defer nk.shutdown();

    {
        var atlas: *c.nk_font_atlas = undefined;
        c.nk_sdl_font_stash_begin(@ptrCast(&atlas));

        const config = c.nk_font_config(0);
        const font = c.nk_font_atlas_add_default(atlas, 13 * font_scale, &config);

        c.nk_sdl_font_stash_end();

        font.*.handle.height /= font_scale;
        c.nk_style_set_font(context.ptr, &font.*.handle);
    }
    //
    // END initialization
    //

    var state = State.init();
    var mouse_in_gui = true;

    loop: while (true) {
        context.beginInput();
        while(sdl.pollEvent()) |event|{
            if (event.@"type" == c.SDL_QUIT) break :loop;
            _ = nk.sdlHandleEvent(&event);

            if (!mouse_in_gui) {
                state.handleEvent(&event);
            }
        }
        nk.sdlHandleGrab();
        context.endInput();

        try state.paramsGui(context);
        try state.controlsGui(context);

        mouse_in_gui = context.windowIsAnyHovered();

        try state.runCycle();

        try renderer.setDrawColor(0, 0, 0, 1);
        try renderer.clear();

        nk.sdlRender(c.NK_ANTI_ALIASING_ON);
        try state.draw(renderer);

        renderer.present();
    }

    state.deinit();
}
