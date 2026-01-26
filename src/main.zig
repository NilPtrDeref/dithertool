const std = @import("std");
const Io = std.Io;
const Image = @import("image");
const Window = @import("window");

pub fn main(init: std.process.Init) !void {
    var file = try Io.Dir.cwd().openFile(init.io, "tm.png", .{});
    defer file.close(init.io);

    var buf: [1024]u8 = undefined;
    var reader = file.reader(init.io, &buf);

    var png = try Image.png.parse(init.io, init.gpa, &reader.interface);
    defer png.deinit();
    std.log.debug("Image is {d} x {d}", .{ png.width, png.height });

    var w = try Window.init(init.gpa, 800, 640, "Dithertool");
    defer w.deinit();
    while (!w.ShouldClose()) {
        w.Clear();
        w.SwapBuffers();
    }
}
