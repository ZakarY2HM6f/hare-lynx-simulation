pub usingnamespace @cImport({
    @cInclude("SDL.h");

    @cDefine("NK_INCLUDE_FIXED_TYPES", {});
    @cDefine("NK_INCLUDE_STANDARD_IO", {});
    @cDefine("NK_INCLUDE_STANDARD_VARARGS", {});
    @cDefine("NK_INCLUDE_DEFAULT_ALLOCATOR", {});
    @cDefine("NK_INCLUDE_VERTEX_BUFFER_OUTPUT", {});
    @cDefine("NK_INCLUDE_FONT_BAKING", {});
    @cDefine("NK_INCLUDE_DEFAULT_FONT", {});
    @cDefine("NK_INCLUDE_VERTEX_BUFFER_OUTPUT", {});

    @cInclude("nuklear.h");
    @cInclude("nuklear_sdl_renderer.h");
});
