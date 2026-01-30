const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Image = @import("image");
const ui = @import("ui");
const Window = ui.Window;
const Texture = ui.Texture;
const Event = ui.Event;

const background: ui.Color = .{ .r = 0xFF, .g = 0x3F, .b = 0x3F, .a = 0xFF };

const State = struct {
    gpa: Allocator,
    io: Io,
    w: *Window = undefined,

    // TODO: Put some lock on texture for upating?
    texture: ?Texture = undefined,

    fn start(state: *State) !void {
        state.w = try Window.init(state.gpa, 800, 640, "Dithertool", .{
            .error_callback = ErrorCallback,
        });
        defer state.w.deinit();
        state.w.SetEventCapabilities(.{ .Key = true, .Drop = true });

        // Text texure data
        // const tdata: []const u8 = &.{
        //     0,   255, 0,   255,
        //     255, 0,   0,   255,
        //     0,   0,   255, 255,
        //     255, 255, 255, 255,
        // };
        // var texture = Texture.init(2, 2, tdata);
        try state.UpdateTexture("tm.png");
        defer state.texture.?.deinit();

        while (!state.w.ShouldClose()) {
            state.w.Clear(background);

            while (state.w.events.popFront()) |e| {
                defer e.deinit();
                switch (e) {
                    .Drop => |drop| {
                        try state.UpdateTexture(drop.paths.items[0]);
                    },
                    .Key => |key| {
                        std.log.info("{any}", .{key.key});
                    },
                    else => {},
                }
            }

            if (state.texture) |texture| {
                state.w.DrawTexture(texture);
            }

            state.w.SwapBuffers();
        }
    }

    fn UpdateTexture(state: *State, path: []const u8) !void {
        var image = try Image.load(state.gpa, state.io, path);
        defer image.deinit(state.gpa);

        const texture = Texture.init(@intCast(image.width), @intCast(image.height), image.data);
        var old: ?Texture = state.texture;
        state.texture = texture;

        if (old) |*ot| {
            ot.deinit();
        }

        std.log.info("Got here: {s}!", .{path});
    }

    fn ErrorCallback(error_code: c_int, description: [*c]const u8) callconv(.c) void {
        std.log.err("Error ({d}): {s}\n", .{ error_code, std.mem.span(description) });
    }
};

pub fn main(init: std.process.Init) !void {
    var state: State = .{ .gpa = init.gpa, .io = init.io };
    try state.start();
}
