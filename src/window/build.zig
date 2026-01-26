const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"3.3",
        .profile = .core,
    });

    const window = b.addModule("window", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
        .link_libc = true,
    });
    window.addImport("gl", gl_bindings);
    window.linkSystemLibrary("glfw", .{});
    window.linkSystemLibrary("GL", .{});
}
