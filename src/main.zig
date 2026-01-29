const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Image = @import("image");
const ui = @import("ui");
const Window = ui.Window;
const Texture = ui.Texture;

const background: ui.Color = .{ .r = 0x3F, .g = 0x3F, .b = 0x3F, .a = 0xFF };

const State = struct {
    w: *Window = undefined,
    texture: Texture = undefined,
    data: []const u8 = "TEST",

    fn start(state: *State, gpa: Allocator, io: Io) !void {
        var image = try Image.load(gpa, io, "tm.png");
        defer image.deinit(gpa);

        state.w = try Window.init(gpa, 800, 640, "Dithertool", .{
            .error_callback = ErrorCallback,
            .userdata = state,
        });
        defer state.w.deinit();
        state.w.SetDropCallback(DropCallback);

        // Text texure data
        // const tdata: []const u8 = &.{
        //     0,   255, 0,   255,
        //     255, 0,   0,   255,
        //     0,   0,   255, 255,
        //     255, 255, 255, 255,
        // };
        // var texture = Texture.init(2, 2, tdata);
        state.texture = Texture.init(@intCast(image.width), @intCast(image.height), image.data);
        defer state.texture.deinit();

        while (!state.w.ShouldClose()) {
            state.w.Clear(background);
            state.w.DrawTexture(state.texture);
            state.w.SwapBuffers();
        }
    }

    fn UpdateTexture(state: *State) void {
        std.log.info("Got here: {s}!", .{state.data});
    }

    fn ErrorCallback(error_code: c_int, description: [*c]const u8) callconv(.c) void {
        std.log.err("Error ({d}): {s}\n", .{ error_code, std.mem.span(description) });
    }

    fn DropCallback(window: *Window, path_count: c_int, paths: [*c][*c]const u8) void {
        const state: *State = @ptrCast(@alignCast(window.userdata.?));
        state.UpdateTexture();
        for (0..@intCast(path_count)) |i| {
            std.log.info("{s}", .{paths[i]});
        }
    }
};

pub fn main(init: std.process.Init) !void {
    var state: State = .{};
    try state.start(init.gpa, init.io);
}
