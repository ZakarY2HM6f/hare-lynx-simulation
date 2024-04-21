const c = @import("c.zig");
const sdl = @import("sdl.zig");

pub const Context = struct {
    ptr: *c.nk_context,

    pub inline fn sdlInit(window: sdl.Window, renderer: sdl.Renderer) !@This() {
        const ptr = c.nk_sdl_init(window.ptr, renderer.ptr) orelse {
            return error.NuklearInitializationError;
        };
        return .{ .ptr = ptr };
    }

    pub inline fn beginInput(self: @This()) void { c.nk_input_begin(self.ptr); }
    pub inline fn endInput(self: @This()) void { c.nk_input_end(self.ptr); }

    pub inline fn beginGUI(
        self: @This(), 
        title: [:0]const u8, 
        bounds: c.struct_nk_rect, 
        flags: c.nk_flags,
    ) bool { 
        return c.nk_begin(self.ptr, title.ptr, bounds, flags) != 0;
    }

    pub inline fn endGUI(self: @This()) void { c.nk_end(self.ptr); }

    pub inline fn windowIsAnyHovered(self: @This()) bool {
        return c.nk_window_is_any_hovered(self.ptr) != 0;
    }

    pub inline fn layoutRowDynamic(
        self: @This(), 
        height: f32, 
        cols: i32,
    ) void {
        c.nk_layout_row_dynamic(self.ptr, height, cols);
    }

    pub inline fn layoutRowStatic(
        self: @This(), 
        height: f32, 
        item_width: i32, 
        cols: i32,
    ) void {
        c.nk_layout_row_static(self.ptr, height, item_width, cols);
    }

    pub inline fn layoutRowBegin(
        self: @This(), 
        fmt: c.nk_layout_format, 
        row_height: f32, 
        cols: i32,
    ) void {
        c.nk_layout_row_begin(self.ptr, fmt, row_height, cols);
    }

    pub inline fn layoutRowPush(self: @This(), v: f32) void {
        c.nk_layout_row_push(self.ptr, v);
    }

    pub inline fn layoutRowEnd(self: @This()) void {
        c.nk_layout_row_end(self.ptr);
    }

    pub inline fn label(self: @This(), str: []const u8, flags: c.nk_flags) void { 
        c.nk_text(self.ptr, str.ptr, @intCast(str.len), flags); 
    }

    pub inline fn value(self: @This(), comptime T: type, str: [:0]const u8, v: T) void { 
        switch (T) {
            bool => c.nk_value_bool(self.ptr, str, v),
            i32 => c.nk_value_int(self.ptr, str, v),
            u32 => c.nk_value_uint(self.ptr, str, v),
            f32 => c.nk_value_float(self.ptr, str, v),
            else => @compileError("unsupported type"),
        }
    }

    pub inline fn buttonLabel(self: @This(), str: []const u8) bool { 
        return c.nk_button_text(self.ptr, str.ptr, @intCast(str.len)) != 0; 
    }

    pub inline fn property(
        self: @This(), 
        comptime T: type, 
        name: [:0]const u8, 
        min: T, 
        val: *T, 
        max: T, 
        step: T, 
        inc_per_pixel: f32,
    ) void {
        switch (T) {
            i32 => c.nk_property_int(self.ptr, name.ptr, min, val, max, step, inc_per_pixel),
            f32 => c.nk_property_float(self.ptr, name.ptr, min, val, max, step, inc_per_pixel),
            f64 => c.nk_property_double(self.ptr, name.ptr, min, val, max, step, inc_per_pixel),
            else => @compileError("unsupported type"),
        }
    }

    pub inline fn propertyEx(
        self: @This(), 
        comptime T: type, 
        name: [:0]const u8, 
        min: T, 
        val: T, 
        max: T, 
        step: T, 
        inc_per_pixel: f32,
    ) T {
        return switch (T) {
            i32 => c.nk_propertyi(self.ptr, name.ptr, min, val, max, step, inc_per_pixel),
            f32 => c.nk_propertyf(self.ptr, name.ptr, min, val, max, step, inc_per_pixel),
            f64 => c.nk_propertyd(self.ptr, name.ptr, min, val, max, step, inc_per_pixel),
            else => @compileError("unsupported type"),
        };
    }

    pub inline fn chartBegin(self: @This(), t: c.nk_chart_type, count: i32, min: f32, max: f32) bool {
        return c.nk_chart_begin(self.ptr, t, count, min, max) != 0;
    }

    pub inline fn chartBeginEx(
        self: @This(), 
        t: c.nk_chart_type, 
        count: i32, 
        min: f32, 
        max: f32,
        base: c.nk_color, 
        active: c.nk_color,
    ) bool {
        return c.nk_chart_begin_colored(self.ptr, t, base, active, count, min, max) != 0;
    }

    pub inline fn chartEnd(self: @This()) void { return c.nk_chart_end(self.ptr); }

    pub inline fn chartAddSlot(self: @This(), t: c.nk_chart_type, count: i32, min: f32, max: f32) void {
        c.nk_chart_add_slot(self.ptr, t, count, min, max);
    }

    pub inline fn chartAddSlotEx(
        self: @This(), 
        t: c.nk_chart_type, 
        count: i32, 
        min: f32, 
        max: f32, 
        base: c.nk_color, 
        active: c.nk_color,
    ) void {
        c.nk_chart_add_slot_colored(self.ptr, t, base, active, count, min, max);
    }

    pub inline fn chartPush(self: @This(), val: f32) c.nk_flags {
        return c.nk_chart_push(self.ptr, val);
    }

    pub inline fn chartPushSlot(self: @This(), val: f32, slot: i32) c.nk_flags {
        return c.nk_chart_push_slot(self.ptr, val, slot);
    }

    pub inline fn spacer(self: @This()) void {
        c.nk_spacer(self.ptr);
    }
};

pub inline fn sdlHandleEvent(event: *const c.SDL_Event) bool { 
    return c.nk_sdl_handle_event(event) != 0;
}

pub inline fn sdlHandleGrab() void { c.nk_sdl_handle_grab(); }

pub inline fn sdlRender(aa: c.nk_anti_aliasing) void { c.nk_sdl_render(aa); }
pub inline fn shutdown() void { c.nk_sdl_shutdown(); }
