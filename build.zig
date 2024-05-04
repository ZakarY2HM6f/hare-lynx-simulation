const std = @import("std");

const BuildConfig = struct {
    darwin: ?struct {
        sdl_include_path: []const u8,
        sdl_library_path: []const u8,
    } = null,
    windows: ?struct {
        sdl_include_path: []const u8,
        sdl_library_path: []const u8,
    } = null,
    emscripten: ?struct {
        emsdk_path: []const u8,
    } = null,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const config = config: {
        const config_path = b.pathFromRoot(b.option(
            []const u8,
            "config",
            "path to json config path",
        ) orelse "build_config.json");
        const config_file = try std.fs.openFileAbsolute(config_path, .{});
        const config_str = try config_file.readToEndAlloc(b.allocator, 4096);
        const parsed = try std.json.parseFromSlice(BuildConfig, b.allocator, config_str, .{ .ignore_unknown_fields = true });
        break :config parsed.value;
    };

    const obj =
        if (target.result.os.tag == .emscripten) b.addStaticLibrary(.{
        .name = "hare-lynx",
        .root_source_file = b.path("src/emmain.zig"),
        .target = target,
        .optimize = optimize,
    }) else b.addExecutable(.{
        .name = "hare-lynx",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    obj.addIncludePath(b.path("include/"));
    obj.addCSourceFile(.{ .file = b.path("src/bindings/nuklear.c") });

    obj.linkLibC();

    if (target.result.os.tag == .emscripten) {
        const emsdk = emsdk: {
            if (config.emscripten) |cfg| {
                break :emsdk cfg.emsdk_path;
            } else {
                break :emsdk std.process.getEnvVarOwned(b.allocator, "EMSDK") catch |err| {
                    if (err == error.EnvironmentVariableNotFound) {
                        std.log.err("No config is provided and EMSDK is not found", .{});
                    }
                    return error.EMSDKNotFound;
                };
            }
        };
        const em_sysroot = b.pathJoin(&.{ emsdk, "upstream/emscripten/cache/sysroot/" });
        const em_include = b.pathJoin(&.{ em_sysroot, "include" });

        b.sysroot = em_sysroot;
        obj.addIncludePath(.{ .cwd_relative = em_include });

        const emcc = b.addSystemCommand(&.{b.pathJoin(&.{ emsdk, "upstream/emscripten/emcc" })});
        emcc.addArtifactArg(obj);
        const js = emcc.addPrefixedOutputFileArg("-o", "index.js");
        emcc.addArgs(&.{
            "-sUSE_SDL=2",
            "-sUSE_OFFSET_CONVERTER",
            "-sMALLOC=emmalloc",
            "-sALLOW_MEMORY_GROWTH=1",
            "-sEXPORTED_FUNCTIONS=_main,_uploadCallback,_malloc,_free",
            "-sEXPORTED_RUNTIME_METHODS=ccall",
        });

        const www = b.addInstallDirectory(.{
            .source_dir = .{ .generated_dirname = .{ .generated = js.generated, .up = 0 } },
            .install_dir = .{ .custom = "www" },
            .install_subdir = "",
        });
        const html = b.addInstallFile(b.path("src/index.html"), "www/index.html");
        html.step.dependOn(&www.step);
        b.getInstallStep().dependOn(&html.step);

        const serve_cmd = b.addSystemCommand(&.{ "python", "-m", "http.server" });
        serve_cmd.addPrefixedDirectoryArg("-d", b.path("zig-out/www/"));
        serve_cmd.step.dependOn(b.getInstallStep());
        const serve_step = b.step("serve", "Serve app at localhost");
        serve_step.dependOn(&serve_cmd.step);
    } else {
        var sdl_include_path: []const u8 = undefined;
        var sdl_library_path: []const u8 = undefined;

        if (target.result.os.tag == .macos) {
            if (config.darwin) |cfg| {
                sdl_include_path = cfg.sdl_include_path;
                sdl_library_path = cfg.sdl_library_path;
            } else {
                sdl_include_path = "/usr/local/include/SDL2";
                sdl_include_path = "/usr/local/lib/";
            }

            obj.linkFramework("Cocoa");
        } else if (target.result.os.tag == .windows) {
            if (config.windows) |cfg| {
                sdl_include_path = cfg.sdl_include_path;
                sdl_library_path = cfg.sdl_library_path;
            } else {
                // There is no sensible fallbacks, so none is included
                std.log.err("No config is provided, SDL2 cannot be linked.", .{});
                return error.SDL2NotFound;
            }

            const install_dll = b.addInstallBinFile(.{ .cwd_relative = b.pathJoin(&.{ sdl_library_path, "SDL2.dll" }) }, "SDL2.dll");
            obj.step.dependOn(&install_dll.step);
        }

        obj.addIncludePath(.{ .cwd_relative = sdl_include_path });
        obj.addLibraryPath(.{ .cwd_relative = sdl_library_path });

        obj.linkSystemLibrary("SDL2");

        b.installArtifact(obj);

        const run_cmd = b.addRunArtifact(obj);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the simulator");
        run_step.dependOn(&run_cmd.step);
    }
}
