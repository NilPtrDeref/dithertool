const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glad = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    glad.addIncludePath(b.path("glad/include"));
    glad.addCSourceFile(.{
        .file = b.path("glad/src/gl.c"),
    });

    const window = b.addModule("window", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
        .link_libc = true,
    });
    window.addImport("glad", glad);
    window.addIncludePath(b.path("glad/include"));
    window.linkSystemLibrary("glfw", .{});
    // window.linkSystemLibrary("GL", .{});
}
