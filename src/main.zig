const std = @import("std");
const Io = std.Io;
const image = @import("image");
const glfw = @cImport(@cInclude("GLFW/glfw3.h"));
const gl = @cImport(@cInclude("GL/gl.h"));

pub fn main(init: std.process.Init) !void {
    // TODO: Parse args to get filepath

    var file = try Io.Dir.cwd().openFile(init.io, "tm.png", .{});
    defer file.close(init.io);

    var buf: [1024]u8 = undefined;
    var reader = file.reader(init.io, &buf);

    var png = try image.png.parse(init.io, init.gpa, &reader.interface);
    defer png.deinit();

    std.log.debug("Image is {d} x {d}", .{ png.width, png.height });
}
