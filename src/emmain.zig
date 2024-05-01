const std = @import("std");

const c = @import("bindings/c.zig");
const em = @import("bindings/em.zig");
const sdl = @import("bindings/sdl.zig");
const nk = @import("bindings/nuklear.zig");

const State = @import("State.zig");

const title = "[HARE x LYNX]";
const width = 800;
const height = 600;

var window: sdl.Window = undefined;
var renderer: sdl.Renderer = undefined;
var context: nk.Context = undefined;
var state: State = undefined;

export fn main(argc: c_int, argv: **c_char) callconv(.C) c_int {
    _ = argc;
    _ = argv;

    //
    // BEGIN initialization
    //
    sdl.init(c.SDL_INIT_VIDEO) catch |e| throw(e);

    window = sdl.Window.create(
        title,
        c.SDL_WINDOWPOS_CENTERED, 
        c.SDL_WINDOWPOS_CENTERED,
        width, 
        height,
        c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_ALLOW_HIGHDPI,
    ) catch |e| throw(e);

    renderer = sdl.Renderer.create(
        window, 
        -1, 
        c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC,
    ) catch |e| throw(e);

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

    context = nk.Context.sdlInit(window, renderer) catch |e| throw(e);

    {
        var atlas: *c.nk_font_atlas = undefined;
        c.nk_sdl_font_stash_begin(@ptrCast(&atlas));

        const config = c.nk_font_config(0);
        const font = c.nk_font_atlas_add_default(atlas, 13 * font_scale, &config);

        c.nk_sdl_font_stash_end();

        font.*.handle.height /= font_scale;
        c.nk_style_set_font(context.ptr, &font.*.handle);
    }

    state = State.init();
    //
    // END initialization
    //

    em.emscripten_set_main_loop(loop, 0, 0);
    return 0;
}

var mouse_in_gui = true;

fn loop() callconv(.C) void {
    context.beginInput();
    while(sdl.pollEvent()) |event|{
        if (event.@"type" == c.SDL_QUIT) {
            state.deinit();
            nk.shutdown();
            renderer.destroy();
            window.destroy();
            sdl.quit();
            em.emscripten_cancel_main_loop();
        }

        _ = nk.sdlHandleEvent(&event);

        if (!mouse_in_gui) {
            state.handleEvent(&event);
        }
    }
    nk.sdlHandleGrab();
    context.endInput();

    state.paramsGui(context) catch |e| throw(e);
    state.controlsGui(context) catch |e| throw(e);

    mouse_in_gui = context.windowIsAnyHovered();

    state.runCycle() catch |e| throw(e);

    renderer.setDrawColor(0, 0, 0, 1) catch |e| throw(e);
    renderer.clear() catch |e| throw(e);

    nk.sdlRender(c.NK_ANTI_ALIASING_ON);
    state.draw(renderer) catch |e| throw(e);

    renderer.present();
}

fn throw(err: anytype) noreturn {
    var buf = [1]u8{0} ** 1024;
    const msg = std.fmt.bufPrint(&buf, "{any}", .{ err }) catch unreachable;
    em.emscripten_console_error(msg.ptr);
    unreachable;
}
