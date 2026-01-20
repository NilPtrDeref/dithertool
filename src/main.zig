const std = @import("std");
const Io = std.Io;
const image = @import("image");

pub fn main(_: std.process.Init) !void {
    image.png.parse();
}
