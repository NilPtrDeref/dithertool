const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"3.3",
        .profile = .core,
    });

    const glfw = b.addTranslateC(.{
        .root_source_file = b.path("src/glfw.h"),
        .target = target,
        .optimize = optimize,
    });

    const ui = b.addModule("ui", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
        .link_libc = true,
        .imports = &.{
            .{
                .name = "glfw",
                .module = glfw.createModule(),
            }
        }
    });
    ui.addImport("gl", gl_bindings);
    ui.linkSystemLibrary("glfw", .{});
}
