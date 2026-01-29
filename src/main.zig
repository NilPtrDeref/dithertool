const std = @import("std");
const Io = std.Io;
const Image = @import("image");
const ui = @import("ui");
const Window = ui.Window;
const Texture = ui.Texture;

const background: Window.Color = .{ .r = 0x3F, .g = 0x3F, .b = 0x3F, .a = 0xFF };

pub fn main(init: std.process.Init) !void {
    var image = try Image.load(init.gpa, init.io, "tm.png");
    defer image.deinit(init.gpa);

    var w = try Window.init(init.gpa, 800, 640, "Dithertool");
    defer w.deinit();

    // Text texure data
    // const tdata: []const u8 = &.{
    //     0,   255, 0,   255,
    //     255, 0,   0,   255,
    //     0,   0,   255, 255,
    //     255, 255, 255, 255,
    // };
    // var texture = Texture.init(2, 2, tdata);
    var texture = Texture.init(@intCast(image.width), @intCast(image.height), image.data);
    defer texture.deinit();

    while (!w.ShouldClose()) {
        w.Clear(background);
        w.DrawTexture(texture);
        w.SwapBuffers();
    }
}
