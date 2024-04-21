const c = @import("c.zig");

pub const Window = struct {
    ptr: *c.SDL_Window,

    pub inline fn create(title: [:0]const u8, x: i32, y: i32, w: i32, h: i32, flags: u32) !@This() {
        const ptr = c.SDL_CreateWindow(title.ptr, x, y, w, h, flags) orelse {
            return error.SDLCreateWindowError;
        };
        return .{ .ptr = ptr };
    }

    pub inline fn destroy(self: @This()) void {
        c.SDL_DestroyWindow(self.ptr);
    }
};

pub const Renderer = struct {
    ptr: *c.SDL_Renderer,

    pub inline fn create(window: Window, index: i32, flags: u32) !@This() {
        const ptr = c.SDL_CreateRenderer(window.ptr, index, flags) orelse {
            return error.SDLCreateRendererError;
        };
        return .{ .ptr = ptr };
    }

    pub inline fn destroy(self: @This()) void {
        c.SDL_DestroyRenderer(self.ptr);
    }

    pub inline fn setDrawColor(self: @This(), r: u8, g: u8, b: u8, a: u8) !void {
        if (c.SDL_SetRenderDrawColor(self.ptr, r, g, b, a) != 0) {
            return error.SDLSetRenderDrawColorError;
        }
    }

    pub inline fn clear(self: @This()) !void {
        if (c.SDL_RenderClear(self.ptr) != 0) {
            return error.SDLRenderClearError;
        }
    }

    pub inline fn drawRect(self: @This(), rect: anytype) !void {
        const result = switch (@typeInfo(@TypeOf(rect))) {
            .Pointer => |ptr| switch(ptr.child) {
                c.SDL_Rect => c.SDL_RenderDrawRect(self.ptr, rect),
                c.SDL_FRect => c.SDL_RenderDrawRectF(self.ptr, rect),
                else => @compileError("unsupported type"),
            },
            else => @compileError("unsupported type"),
        };
        if (result != 0) {
            return error.SDLRenderDrawRectError;
        }
    }

    pub inline fn fillRect(self: @This(), rect: anytype) !void {
        const result = switch (@typeInfo(@TypeOf(rect))) {
            .Pointer => |ptr| switch(ptr.child) {
                c.SDL_Rect => c.SDL_RenderFillRect(self.ptr, rect),
                c.SDL_FRect => c.SDL_RenderFillRectF(self.ptr, rect),
                else => @compileError("unsupported type"),
            },
            else => @compileError("unsupported type"),
        };
        if (result != 0) {
            return error.SDLRenderDrawRectError;
        }
    }

    pub inline fn present(self: @This()) void { c.SDL_RenderPresent(self.ptr); }
};

pub inline fn init(flags: u32) !void {
    if (c.SDL_Init(flags) != 0) {
        return error.SDLInitError;
    }
}

pub inline fn quit() void { c.SDL_Quit(); }

pub inline fn pollEvent() ?c.SDL_Event { 
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(&event) != 0) {
        return event;
    } else {
        return null;
    }
}

