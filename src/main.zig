const std = @import("std");
const Io = std.Io;
const image = @import("image");

pub fn main(init: std.process.Init) !void {
    // TODO: Parse args to get filepath

    var file = try Io.Dir.cwd().openFile(init.io, "tm.png", .{});
    var buf: [1024]u8 = undefined;
    var reader = file.reader(init.io, &buf);

    var png = try image.png.parse(init.io, init.gpa, &reader.interface);
    defer png.deinit();

    std.debug.print("Image is {d} x {d}\n", .{ png.width, png.height });
}
