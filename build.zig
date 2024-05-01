const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const obj = 
        if (target.result.os.tag == .emscripten) b.addStaticLibrary(.{
            .name = "hare-lynx",
            .root_source_file = b.path("src/emmain.zig"),
            .target = target,
            .optimize = optimize,
        })
        else b.addExecutable(.{
            .name = "hare-lynx",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

    obj.addIncludePath(b.path("include/"));
    obj.addCSourceFile(.{ .file = b.path("src/bindings/nuklear.c") });

    obj.linkLibC();

    if (target.result.os.tag == .emscripten) {
        const emsdk = try std.process.getEnvVarOwned(b.allocator, "EMSDK");
        const em_sysroot = b.pathJoin(&.{ emsdk, "upstream/emscripten/cache/sysroot/" });
        const em_include = b.pathJoin(&.{ em_sysroot, "include" });

        b.sysroot = em_sysroot;
        obj.addIncludePath(.{ .cwd_relative = em_include });

        const emcc = b.addSystemCommand(&.{ b.pathJoin(&.{ emsdk, "upstream/emscripten/emcc" }) });
        emcc.addArtifactArg(obj);
        const html = emcc.addPrefixedOutputFileArg("-o", "index.js");
        emcc.addArgs(&.{
            "-sUSE_SDL=2",
            "-sUSE_OFFSET_CONVERTER",
            "-sMALLOC=emmalloc",
		    "-sALLOW_MEMORY_GROWTH=1",
            "-sEXPORTED_FUNCTIONS=_main,_uploadCallback,_malloc,_free",
            "-sEXPORTED_RUNTIME_METHODS=ccall",
        });

        b.installDirectory(.{
            .source_dir = .{ .generated_dirname = .{ .generated = html.generated, .up = 0 } },
            .install_dir = .{ .custom = "www" },
            .install_subdir = "",
        });
        b.installFile("src/index.html", "www/index.html");

        const serve_cmd = b.addSystemCommand(&.{ "python", "-m", "http.server" });
        serve_cmd.addPrefixedDirectoryArg("-d", b.path("zig-out/www/"));
        serve_cmd.step.dependOn(b.getInstallStep());
        const serve_step = b.step("serve", "Serve app at localhost");
        serve_step.dependOn(&serve_cmd.step);
    } else {
        if (target.result.isDarwin()) {
            obj.addIncludePath(.{ .cwd_relative = "/usr/local/include/" });
            obj.addLibraryPath(.{ .cwd_relative = "/usr/local/lib/" });

            obj.linkFramework("Cocoa");
        }
        
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
