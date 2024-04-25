const std = @import("std");

const c = @import("../bindings/c.zig");
const nk = @import("../bindings/nuklear.zig");

const utils = @import("strings.zig");

pub fn fieldProperties(context: nk.Context, ptr: anytype) void {
    const p = @typeInfo(@TypeOf(ptr)).Pointer;
    const s = @typeInfo(p.child).Struct;

    inline for (s.fields) |field| {
        switch (field.@"type") {
            i32, f32, f64 => {
                context.property(
                    field.@"type", 
                    "#" ++ comptime utils.snakeCaseToCamelCase(field.name), 
                    0, 
                    &@field(ptr, field.name), 
                    10000, 
                    1,
                    1,
                );
            },
            else => {
                context.label(
                    comptime utils.snakeCaseToCamelCase(field.name) ++ ":", 
                    c.NK_TEXT_ALIGN_BOTTOM | c.NK_TEXT_ALIGN_LEFT,
                );
                fieldProperties(context, &@field(ptr, field.name));
            },
        }
    }
}

pub fn fieldValues(context: nk.Context, ptr: anytype) void {
    const p = @typeInfo(@TypeOf(ptr)).Pointer;
    const s = @typeInfo(p.child).Struct;

    inline for (s.fields) |field| {
        switch (field.@"type") {
            bool, i32, u32, f32 => {
                context.value(
                    field.@"type", 
                    comptime utils.snakeCaseToCamelCase(field.name),
                    @field(ptr, field.name),
                );
            },
            else => {
                context.label(
                    comptime utils.snakeCaseToCamelCase(field.name) ++ ":", 
                    c.NK_TEXT_ALIGN_BOTTOM | c.NK_TEXT_ALIGN_LEFT,
                );
                fieldValues(context, &@field(ptr, field.name));
            },
        }
    }
}

