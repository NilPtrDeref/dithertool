const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const window = b.addModule("window", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
    });
    window.linkSystemLibrary("glfw", .{});
    window.linkSystemLibrary("GL", .{});
}
