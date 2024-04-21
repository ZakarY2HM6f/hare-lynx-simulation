const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hare-lynx",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .path = "include/" });
    exe.addCSourceFile(.{ .file = .{ .path = "src/bindings/nuklear.c" } });

    if (target.result.isDarwin()) {
        exe.addIncludePath(.{ .path = "/usr/local/include/" });
        exe.addLibraryPath(.{ .path ="/usr/local/lib/" });

        exe.linkFramework("Cocoa");
    }

    exe.linkSystemLibrary("SDL2");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
