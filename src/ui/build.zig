const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"3.3",
        .profile = .core,
    });

    const ui = b.addModule("ui", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
        .link_libc = true,
    });
    ui.addImport("gl", gl_bindings);
    ui.linkSystemLibrary("glfw", .{});
}
